{ config, pkgs, ... }:
let
  # AWS Manager Script
  awsManagerScript = pkgs.writeShellScriptBin "aws-manager" ''
    #!/bin/bash
    set -euo pipefail
    
    # AWS Manager Functions
    aws_config="$HOME/.aws/config"
    aws_cache_dir="$HOME/.aws/sso/cache"
    
    # Input validation functions
    validate_profile_name() {
        local profile="$1"
        if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Invalid profile name. Only alphanumeric characters, hyphens, and underscores allowed" >&2
            return 1
        fi
    }
    
    validate_session_name() {
        local session="$1"
        if [[ ! "$session" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Invalid session name. Only alphanumeric characters, hyphens, and underscores allowed" >&2
            return 1
        fi
    }
    
    sanitize_input() {
        local input="$1"
        # Remove any potentially dangerous characters
        echo "$input" | tr -d ';|&$`"'"'"'\\'
    }
    
    # List SSO sessions
    list_sso_sessions() {
        if [[ ! -f "$aws_config" ]]; then
            return 0
        fi
        
        grep '^\[sso-session ' "$aws_config" | sed 's/^\[sso-session //' | sed 's/\]$//' | sort
    }
    
    # Get SSO session details
    get_sso_session_details() {
        local session_name="$1"
        local start_url
        local region
        
        start_url=$(grep -A 10 "^\[sso-session $session_name\]" "$aws_config" | grep 'sso_start_url' | cut -d'=' -f2 | tr -d ' ')
        region=$(grep -A 10 "^\[sso-session $session_name\]" "$aws_config" | grep 'sso_region' | cut -d'=' -f2 | tr -d ' ')
        
        echo "$start_url $region"
    }
    
    # Create backup of a file
    create_backup() {
        local file="$1"
        cp "$file" "$file.backup.$(date +%s)"
    }
    
    # Prompt for SSO login when token is expired
    prompt_sso_login() {
        local session_name="$1"
        
        # Check if we're in an interactive terminal
        if [[ ! -t 0 ]]; then
            echo "  ✗ Non-interactive terminal. Cannot prompt for login." >&2
            return 1
        fi
        
        echo "  ⚠ Session '$session_name' has expired token."
        read -p "  Login now? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "  → Logging into SSO session: $session_name"
            if aws sso login --sso-session "$session_name"; then
                echo "  ✓ Login successful"
                return 0
            else
                echo "  ✗ Login failed"
                return 1
            fi
        else
            echo "  → Skipping session (user declined login)"
            return 1
        fi
    }
    
    # Check if SSO token is valid
    has_valid_token() {
        local start_url="$1"
        local region="$2"
        local token=$(get_access_token "$start_url" "$region")
        [[ -n "$token" ]]
    }
    
    # List AWS profiles
    list_aws_profiles() {
        if [[ ! -f "$aws_config" ]]; then
            return 0
        fi
        
        grep '^\[profile ' "$aws_config" | sed 's/^\[profile //' | sed 's/\]$//' | sort
    }
    
    # Test profile
    test_profile() {
        local profile_name="$1"
        if aws sts get-caller-identity --profile "$profile_name" >/dev/null 2>&1; then
            echo "✓ $profile_name"
        else
            echo "✗ $profile_name"
        fi
    }
    
    # Clean name for profile generation
    clean_name() {
        echo "$1" | sed 's/[^a-zA-Z0-9_-]//g' | tr '[:upper:]' '[:lower:]'
    }
    
    # Get access token for SSO session
    get_access_token() {
        local start_url="$1"
        local region="$2"
        local aws_cache_dir="$HOME/.aws/sso/cache"
        
        if [[ -d "$aws_cache_dir" ]]; then
            for cache_file in "$aws_cache_dir"/*.json; do
                if [[ -f "$cache_file" ]]; then
                    local token
                    token=$(jq -r --arg url "$start_url" --arg reg "$region" '
                        select(.accessToken and .expiresAt and .startUrl==$url and .region==$reg) |
                        select((.expiresAt | fromdateiso8601) > now) |
                        .accessToken
                    ' "$cache_file" 2>/dev/null)
                    
                    if [[ -n "$token" && "$token" != "null" ]]; then
                        echo "$token"
                        return 0
                    fi
                fi
            done
        fi
        
        return 1
    }
    
    # Generate profile name
    generate_profile_name() {
        local session_name="$1"
        local account_name="$2"
        local role_name="$3"
        
        local session_clean=$(clean_name "$session_name")
        local account_clean=$(clean_name "$account_name")
        local role_clean=$(clean_name "$role_name")
        
        echo "''${session_clean}_''${account_clean}_''${role_clean}"
    }
    
    # Get existing profiles for a specific SSO session
    get_existing_profiles_for_session() {
        local session_name="$1"
        local aws_config="$HOME/.aws/config"
        
        if [[ ! -f "$aws_config" ]]; then
            return 0
        fi
        
        # Find profiles that use this SSO session
        awk -v session="$session_name" '
        BEGIN { in_profile = 0; profile_name = "" }
        /^\[profile / {
            in_profile = 1
            profile_name = $0
            next
        }
        /^\[/ {
            in_profile = 0
            profile_name = ""
            next
        }
        in_profile && /sso_session.*=.*/ {
            if ($0 ~ "sso_session.*=.*" session) {
                print profile_name | "sed \"s/^\\[profile //; s/\\]$//\""
            }
        }
        ' "$aws_config"
    }
    
    # Create a profile
    create_profile() {
        local profile_name="$1"
        local account_id="$2"
        local role_name="$3"
        local session_name="$4"
        local region="$5"
        local aws_config="$HOME/.aws/config"
        
        # Add profile to config
        cat >> "$aws_config" << EOF

[profile $profile_name]
sso_session = $session_name
sso_account_id = $account_id
sso_role_name = $role_name
region = $region
output = json
EOF
    }
    
    # Remove a profile
    remove_profile_direct() {
        local profile_name="$1"
        local aws_config="$HOME/.aws/config"
        local temp_config
        temp_config=$(mktemp)
        
        # Remove profile block
        awk -v profile="$profile_name" '
        BEGIN { in_profile = 0 }
        /^\[profile / {
            if ($0 == "[profile " profile "]") {
                in_profile = 1
                next
            }
        }
        /^\[/ {
            in_profile = 0
        }
        !in_profile {
            print
        }
        ' "$aws_config" > "$temp_config"
        
        mv "$temp_config" "$aws_config"
    }
    
    # Sync profiles for a specific SSO session
    sync_session_profiles() {
        local session_name="$1"
        local details
        details=$(get_sso_session_details "$session_name")
        
        if [[ -z "$details" || "$details" == "|" ]]; then
            echo "  ✗ No session details found"
            return 1
        fi
        
        local start_url region
        start_url="''${details%|*}"
        region="''${details#*|}"
        
        # Get access token
        local token
        token=$(get_access_token "$start_url" "$region")
        if [[ -z "$token" ]]; then
            echo "  ✗ No valid access token"
            return 1
        fi
        
        echo "  Discovering accounts and roles from SSO..."
        
        # Get all accounts from SSO
        local accounts_json
        accounts_json=$(aws sso list-accounts --region "$region" --access-token "$token" --output json 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            echo "  ✗ Failed to list accounts"
            return 1
        fi
        
        # Create temporary files for comparison
        local temp_dir
        temp_dir=$(mktemp -d -t aws_sync_XXXXXX)
        trap "rm -rf '$temp_dir'" EXIT
        local available_file="$temp_dir/available_profiles"
        local existing_file="$temp_dir/existing_profiles"
        
        # Get existing profiles for this session
        get_existing_profiles_for_session "$session_name" > "$existing_file"
        
        # Discover all available profiles from SSO
        echo "$accounts_json" | jq -r '.accountList[] | [.accountId, .accountName] | @tsv' > "$temp_dir/accounts.txt"
        
        while IFS=$'\t' read -r account_id account_name; do
            echo "    Processing account: $account_name ($account_id)"
            
            # Get roles for this account
            local roles_json
            roles_json=$(aws sso list-account-roles --region "$region" --access-token "$token" --account-id "$account_id" --output json 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                echo "$roles_json" | jq -r '.roleList[].roleName' > "$temp_dir/roles_''${account_id}.txt"
                
                while read -r role_name; do
                    local profile_name
                    profile_name=$(generate_profile_name "$session_name" "$account_name" "$role_name")
                    echo "$profile_name" >> "$available_file"
                done < "$temp_dir/roles_''${account_id}.txt"
            fi
        done < "$temp_dir/accounts.txt"
        
        # Find profiles to remove (exist locally but not in SSO)
        local to_remove_file="$temp_dir/to_remove.txt"
        comm -23 <(sort "$existing_file") <(sort "$available_file") > "$to_remove_file"
        
        # Find profiles to add (exist in SSO but not locally)
        local to_add_file="$temp_dir/to_add.txt"
        comm -13 <(sort "$existing_file") <(sort "$available_file") > "$to_add_file"
        
        # Remove profiles that no longer exist in SSO
        if [[ -s "$to_remove_file" ]]; then
            echo "  Removing profiles no longer in SSO:"
            while read -r profile_name; do
                echo "    - $profile_name"
                remove_profile_direct "$profile_name"
            done < "$to_remove_file"
        fi
        
        # Add new profiles from SSO
        if [[ -s "$to_add_file" ]]; then
            echo "  Adding new profiles from SSO:"
            while read -r profile_name; do
                echo "    + $profile_name"
                # Extract account and role info from profile name
                local account_name role_name
                account_name=$(echo "$profile_name" | sed "s/^''${session_name}_//" | sed 's/_[^_]*$//')
                role_name=$(echo "$profile_name" | sed "s/.*_//")
                
                # Find account ID
                local account_id
                account_id=$(echo "$accounts_json" | jq -r --arg name "$account_name" '.accountList[] | select(.accountName == $name) | .accountId')
                
                if [[ -n "$account_id" ]]; then
                    create_profile "$profile_name" "$account_id" "$role_name" "$session_name" "$region"
                fi
            done < "$to_add_file"
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
        
        echo "  Sync complete for session: $session_name"
    }
    
    # Main sync profiles function
    sync_profiles() {
        echo "Syncing profiles..."
        echo ""
        
        local sessions
        sessions=$(list_sso_sessions)
        
        if [[ -z "$sessions" ]]; then
            echo "No SSO sessions found"
            return 0
        fi
        
        # Create backup
        create_backup "$HOME/.aws/config"
        
        # Process each session
        while IFS= read -r session; do
            if has_valid_token "$session"; then
                echo "✓ $session (syncing profiles)"
                sync_session_profiles "$session"
            else
                echo "✗ $session (no valid token)"
                if prompt_sso_login "$session"; then
                    echo "✓ $session (syncing profiles)"
                    sync_session_profiles "$session"
                else
                    echo "✗ $session (skipping - no valid token)"
                fi
            fi
        done < <(echo "$sessions")
        
        echo "Profile sync complete"
        echo ""
        
        # Trigger ECR validation after AWS sync
        echo "Validating ECR registries..."
        if command -v validate_ecr_registries_after_aws_sync >/dev/null 2>&1; then
            validate_ecr_registries_after_aws_sync
        else
            echo "ECR manager not available for validation"
        fi
    }
    
    # Add SSO session
    add_sso_session() {
        if [[ ! -t 0 ]]; then
            echo "Error: This function requires an interactive terminal."
            echo "Please run: aws-manager"
            return 1
        fi
        
        echo "Adding new SSO session..."
        aws configure sso-session
    }
    
    # Update SSO session
    update_sso_session() {
        if [[ ! -t 0 ]]; then
            echo "Error: This function requires an interactive terminal."
            echo "Please run: aws-manager"
            return 1
        fi
        
        echo "Available SSO sessions:"
        list_sso_sessions | nl -v1
        echo ""
        read -p "Enter session number to update: " session_num
        
        local session
        session=$(list_sso_sessions | sed -n "''${session_num}p")
        
        if [[ -z "$session" ]]; then
            echo "Invalid session number"
            return 1
        fi
        
        echo "Updating SSO session: $session"
        echo ""
        echo "This will reconfigure the SSO session. You'll need to:"
        echo "1. Enter the same session name: $session"
        echo "2. Provide updated SSO details"
        echo ""
        read -p "Continue? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Remove the old session first
            remove_sso_session_direct "$session"
            echo ""
            echo "Now configure the updated SSO session..."
            aws configure sso-session
        else
            echo "Update cancelled"
        fi
    }
    
    # Remove SSO session
    remove_sso_session_direct() {
        local session_name="$1"
        local temp_config
        temp_config=$(mktemp)
        
        # Create backup
        create_backup "$aws_config"
        
        # Remove SSO session and associated profiles
        awk -v session="$session_name" '
        BEGIN { in_session = 0; in_profile = 0; skip_profile = 0; profile_name = "" }
        /^\[sso-session / {
            if ($0 == "[sso-session " session "]") {
                in_session = 1
                skip_profile = 0
                next
            }
        }
        /^\[profile / {
            in_profile = 1
            in_session = 0
            skip_profile = 0
            profile_name = $0
            next
        }
        /^\[/ {
            in_session = 0
            in_profile = 0
            skip_profile = 0
            profile_name = ""
        }
        in_session {
            next
        }
        in_profile && /sso_session.*=.*'$session_name'/ {
            skip_profile = 1
            next
        }
        skip_profile {
            next
        }
        { print }
        ' "$aws_config" > "$temp_config"
        
        mv "$temp_config" "$aws_config"
        echo "Removed SSO session: $session_name"
    }
    
    # Main AWS Manager Menu
    aws_manager() {
        while true; do
            echo ""
            echo "AWS Profile Manager"
            echo "=================="
            echo "1) List SSO sessions"
            echo "2) Add SSO session"
            echo "3) Update SSO session"
            echo "4) Remove SSO session"
            echo "5) List profiles"
            echo "6) Test profiles"
            echo "7) Sync profiles"
            echo "8) Exit"
            echo ""
            read -p "Select option (1-8): " choice
            
            case $choice in
                1)
                    echo "SSO Sessions:"
                    list_sso_sessions | while read -r session; do
                        if [[ -n "$session" ]]; then
                            local details
                            details=$(get_sso_session_details "$session")
                            local start_url region
                            read -r start_url region <<< "$details"
                            
                            if has_valid_token "$start_url" "$region"; then
                                echo "✓ $session (valid)"
                            else
                                echo "✗ $session (expired)"
                            fi
                        fi
                    done
                    ;;
                2)
                    add_sso_session
                    echo ""
                    echo "Syncing profiles after adding SSO session..."
                    sync_profiles
                    ;;
                3)
                    update_sso_session
                    echo ""
                    echo "Syncing profiles after updating SSO session..."
                    sync_profiles
                    ;;
                4)
                    echo "Available SSO sessions:"
                    list_sso_sessions | nl -v1
                    echo ""
                    read -p "Enter session number to remove: " session_num
                    local session
                    session=$(list_sso_sessions | sed -n "''${session_num}p")
                    if [[ -n "$session" ]]; then
                        read -p "Remove session '$session'? (y/N): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            remove_sso_session_direct "$session"
                            echo ""
                            echo "Syncing profiles after removing SSO session..."
                            sync_profiles
                        fi
                    fi
                    ;;
                5)
                    echo "AWS Profiles:"
                    list_aws_profiles | while read -r profile; do
                        if [[ -n "$profile" ]]; then
                            echo "  $profile"
                        fi
                    done
                    ;;
                6)
                    echo "Testing profiles..."
                    list_aws_profiles | while read -r profile; do
                        if [[ -n "$profile" ]]; then
                            test_profile "$profile"
                        fi
                    done
                    ;;
                7)
                    sync_profiles
                    ;;
                8)
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
    }
    
    # Execute the manager
    aws_manager "$@"
  '';

in
{
  home.packages = [
    awsManagerScript
  ];

  # Shell aliases for easy access
  programs.zsh.shellAliases = {
    aws-mgr = "aws-manager";
  };
}
