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
    
    # Prompt for SSO login when token is expired (non-interactive - returns error)
    prompt_sso_login() {
        local session_name="$1"
        
        echo "  ⚠ Session '$session_name' has expired token."
        echo "  ✗ Non-interactive mode. Use 'aws sso login --sso-session $session_name' to login manually."
        return 1
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
            local details
            details=$(get_sso_session_details "$session")
            local start_url region
            read -r start_url region <<< "$details"
            
            if has_valid_token "$start_url" "$region"; then
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
        if command -v ecr-manager >/dev/null 2>&1; then
            ecr-manager validate-after-sync
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
    
    
    # Convert AWS config INI to JSON format using Python
    convert_ini_to_json() {
        local config_file="$1"
        local json_file="$2"
        
        if [[ ! -f "$config_file" ]]; then
            echo '{"default": {}, "sso_sessions": {}, "profiles": {}}' > "$json_file"
            return 0
        fi
        
        python3 -c "
import configparser
import json
import sys

config = configparser.ConfigParser()
config.read('$config_file')

result = {
    'default': {},
    'sso_sessions': {},
    'profiles': {}
}

# Parse default section
if 'default' in config:
    result['default'] = dict(config['default'])

# Parse SSO sessions
for section in config.sections():
    if section.startswith('sso-session '):
        session_name = section[12:]  # Remove 'sso-session ' prefix
        result['sso_sessions'][session_name] = dict(config[section])
    elif section.startswith('profile '):
        profile_name = section[8:]  # Remove 'profile ' prefix
        result['profiles'][profile_name] = dict(config[section])

print(json.dumps(result, indent=2))
" > "$json_file"
    }
    
    # Convert JSON back to AWS config INI format using Python
    convert_json_to_ini() {
        local json_file="$1"
        local config_file="$2"
        
        python3 -c "
import json
import sys

with open('$json_file', 'r') as f:
    data = json.load(f)

with open('$config_file', 'w') as f:
    # Write default section
    if data.get('default'):
        f.write('[default]\n')
        for key, value in data['default'].items():
            f.write(f'{key} = {value}\n')
        f.write('\n')
    
    # Write SSO sessions
    for session_name, session_data in data.get('sso_sessions', {}).items():
        f.write(f'[sso-session {session_name}]\n')
        for key, value in session_data.items():
            f.write(f'{key} = {value}\n')
        f.write('\n')
    
    # Write profiles
    for profile_name, profile_data in data.get('profiles', {}).items():
        f.write(f'[profile {profile_name}]\n')
        for key, value in profile_data.items():
            f.write(f'{key} = {value}\n')
        f.write('\n')
"
    }
    
    # Remove profiles associated with an SSO session (but keep the SSO session)
    remove_associated_profiles() {
        local session_name="$1"
        local temp_dir
        temp_dir=$(mktemp -d)
        local json_file="$temp_dir/config.json"
        
        # Create backup
        create_backup "$aws_config"
        
        # Convert INI to JSON
        convert_ini_to_json "$aws_config" "$json_file"
        
        # Remove profiles that reference this SSO session
        jq --arg session "$session_name" '
        .profiles = (.profiles | to_entries | map(select(.value.sso_session != $session)) | from_entries)
        ' "$json_file" > "$json_file.tmp"
        
        # Convert back to INI
        convert_json_to_ini "$json_file.tmp" "$aws_config"
        
        # Cleanup
        rm -rf "$temp_dir"
        echo "✓ Removed profiles associated with SSO session: $session_name"
    }
    
    # Remove SSO session and all associated profiles
    remove_sso_session_direct() {
        local session_name="$1"
        local temp_dir
        temp_dir=$(mktemp -d)
        local json_file="$temp_dir/config.json"
        
        # Create backup
        create_backup "$aws_config"
        
        # Convert INI to JSON
        convert_ini_to_json "$aws_config" "$json_file"
        
        # Remove SSO session and associated profiles
        jq --arg session "$session_name" '
        # Remove the SSO session
        del(.sso_sessions[$session]) |
        # Remove profiles that reference this SSO session
        .profiles = (.profiles | to_entries | map(select(.value.sso_session != $session)) | from_entries)
        ' "$json_file" > "$json_file.tmp"
        
        # Convert back to INI
        convert_json_to_ini "$json_file.tmp" "$aws_config"
        
        # Cleanup
        rm -rf "$temp_dir"
        echo "✓ Removed SSO session: $session_name"
    }
    
    # Show help
    show_help() {
        echo "AWS Profile Manager"
        echo ""
        echo "Usage: aws-mgr <command> [options]"
        echo ""
        echo "Commands:"
        echo "  ls sso                    List SSO sessions"
        echo "  add sso                   Add new SSO session"
        echo "  update sso <session>      Update SSO session"
        echo "  rm sso <session>          Remove SSO session"
        echo "  ls profiles              List AWS profiles"
        echo "  test profiles             Test AWS profiles"
        echo "  sync                     Sync profiles from SSO"
        echo "  status                   Show current status"
        echo "  help                     Show this help"
        echo ""
        echo "Examples:"
        echo "  aws-mgr ls sso"
        echo "  aws-mgr add sso"
        echo "  aws-mgr update sso my-company-sso"
        echo "  aws-mgr rm sso my-company-sso"
        echo "  aws-mgr ls profiles"
        echo "  aws-mgr test profiles"
        echo "  aws-mgr sync"
        echo "  aws-mgr status"
    }
    
    # Show status
    show_status() {
        echo "AWS Profile Manager Status"
        echo "========================="
        echo ""
        
        echo "SSO Sessions:"
        local sessions
        sessions=$(list_sso_sessions)
        if [[ -n "$sessions" ]]; then
            echo "$sessions" | while read -r session; do
                if [[ -n "$session" ]]; then
                    local details
                    details=$(get_sso_session_details "$session")
                    local start_url region
                    read -r start_url region <<< "$details"
                    
                    if has_valid_token "$start_url" "$region"; then
                        echo "  ✓ $session (valid)"
                    else
                        echo "  ✗ $session (expired)"
                    fi
                fi
            done
        else
            echo "  No SSO sessions found"
        fi
        
        echo ""
        echo "AWS Profiles:"
        local profiles
        profiles=$(list_aws_profiles)
        if [[ -n "$profiles" ]]; then
            echo "$profiles" | while read -r profile; do
                if [[ -n "$profile" ]]; then
                    echo "  $profile"
                fi
            done
        else
            echo "  No AWS profiles found"
        fi
    }
    
    # Main AWS Manager CLI
    aws_manager() {
        local command="''${1:-help}"
        
        case "$command" in
            "ls")
                local object="''${2:-}"
                case "$object" in
                    "sso")
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
                    "profiles")
                        echo "AWS Profiles:"
                        list_aws_profiles | while read -r profile; do
                            if [[ -n "$profile" ]]; then
                                echo "  $profile"
                            fi
                        done
                        ;;
                    *)
                        echo "Usage: aws-mgr ls <sso|profiles>"
                        ;;
                esac
                ;;
            "add")
                local object="''${2:-}"
                case "$object" in
                    "sso")
                        add_sso_session
                        echo ""
                        echo "Syncing profiles after adding SSO session..."
                        sync_profiles
                        ;;
                    *)
                        echo "Usage: aws-mgr add <sso>"
                        ;;
                esac
                ;;
            "update")
                local object="''${2:-}"
                case "$object" in
                    "sso")
                        local session="''${3:-}"
                        if [[ -n "$session" ]]; then
                            echo "Updating SSO session: $session"
                            echo ""
                            echo "This will reconfigure the SSO session with the same name: $session"
                            echo "You can update: start URL, region, registration scopes"
                            echo ""
                            
                            # Remove associated profiles but keep the SSO session
                            remove_associated_profiles "$session"
                            echo ""
                            echo "Launching AWS CLI wizard..."
                            echo "Session name will be automatically supplied: $session"
                            echo "You can then update: start URL, region, registration scopes"
                            echo ""
                            
                            # Use expect to automatically provide the session name
                            expect -c "
                                set timeout 30
                                spawn aws configure sso-session
                                expect \"SSO session name:\"
                                send \"$session\r\"
                                interact
                            " || {
                                echo "Note: expect failed, launching manual wizard..."
                                echo "IMPORTANT: Enter the same session name: $session"
                                aws configure sso-session
                            }
                            echo ""
                            echo "Syncing profiles after updating SSO session..."
                            sync_profiles
                        else
                            echo "Usage: aws-mgr update sso <session-name>"
                        fi
                        ;;
                    *)
                        echo "Usage: aws-mgr update <sso> <session-name>"
                        ;;
                esac
                ;;
            "rm")
                local object="''${2:-}"
                case "$object" in
                    "sso")
                        local session="''${3:-}"
                        if [[ -n "$session" ]]; then
                            remove_sso_session_direct "$session"
                            echo ""
                            echo "Syncing profiles after removing SSO session..."
                            sync_profiles
                        else
                            echo "Usage: aws-mgr rm sso <session-name>"
                        fi
                        ;;
                    *)
                        echo "Usage: aws-mgr rm <sso> <session-name>"
                        ;;
                esac
                ;;
            "test")
                local object="''${2:-}"
                case "$object" in
                    "profiles")
                        echo "Testing profiles..."
                        list_aws_profiles | while read -r profile; do
                            if [[ -n "$profile" ]]; then
                                test_profile "$profile"
                            fi
                        done
                        ;;
                    *)
                        echo "Usage: aws-mgr test <profiles>"
                        ;;
                esac
                ;;
            "sync")
                sync_profiles
                ;;
            "status")
                show_status
                ;;
            "help"|*)
                show_help
                ;;
        esac
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
