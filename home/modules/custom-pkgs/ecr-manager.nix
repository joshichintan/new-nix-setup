{ config, pkgs, ... }:
let
  # ECR Manager Script
  ecrManagerScript = pkgs.writeShellScriptBin "ecr-manager" ''
    #!/bin/bash
    set -euo pipefail
    
    # ECR Manager Functions
    docker_config="$HOME/.docker/config.json"
    
    # Input validation functions
    validate_registry_url() {
        local url="$1"
        if [[ ! "$url" =~ ^[0-9]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ ]]; then
            echo "Invalid ECR registry URL format. Expected: <account>.dkr.ecr.<region>.amazonaws.com" >&2
            return 1
        fi
    }
    
    validate_profile_name() {
        local profile="$1"
        if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Invalid profile name. Only alphanumeric characters, hyphens, and underscores allowed" >&2
            return 1
        fi
    }
    
    sanitize_input() {
        local input="$1"
        # Remove any potentially dangerous characters
        echo "$input" | tr -d ';|&$`"'"'"'\\'
    }
    
    # List ECR registries
    list_ecr_registries() {
        if [[ ! -f "$docker_config" ]]; then
            return 0
        fi
        
        jq -r '.registryConfigs // {} | keys[]' "$docker_config" 2>/dev/null || true
    }
    
    # Get ECR registry profile
    get_ecr_registry_profile() {
        local registry="$1"
        jq -r --arg reg "$registry" '.registryConfigs[$reg].profile // empty' "$docker_config" 2>/dev/null || true
    }
    
    # List available AWS profiles
    list_aws_profiles() {
        if [[ ! -f "$HOME/.aws/config" ]]; then
            return 0
        fi
        
        grep '^\[profile ' "$HOME/.aws/config" | sed 's/^\[profile //' | sed 's/\]$//' | sort
    }
    
    # Get AWS profile by name or number
    get_aws_profile() {
        local profile_input="$1"
        local profiles
        profiles=$(list_aws_profiles)
        
        if [[ -z "$profiles" ]]; then
            echo "No AWS profiles found. Run 'aws configure' to create profiles." >&2
            return 1
        fi
        
        # If input is a number, get profile by index
        if [[ "$profile_input" =~ ^[0-9]+$ ]]; then
            local selected_profile
            selected_profile=$(echo "$profiles" | sed -n "''${profile_input}p")
            if [[ -n "$selected_profile" ]]; then
                echo "$selected_profile"
                return 0
            else
                echo "Invalid profile number" >&2
                return 1
            fi
        fi
        
        # If input is a profile name, validate it exists
        if echo "$profiles" | grep -q "^''${profile_input}$"; then
            echo "$profile_input"
            return 0
        else
            echo "Profile '$profile_input' not found" >&2
            return 1
        fi
    }
    
    # Validate ECR registry (3-step validation)
    validate_ecr_registry() {
        local registry="$1"
        local profile="''${2:-}"
        
        if [[ -z "$registry" ]]; then
            echo "✗ Registry URL is required"
            return 1
        fi
        
        if [[ -z "$profile" ]]; then
            profile=$(get_ecr_registry_profile "$registry")
        fi
        
        if [[ -z "$profile" ]]; then
            echo "✗ No AWS profile configured for registry: $registry"
            return 1
        fi
        
        echo "Validating registry: $registry with profile: $profile"
        echo ""
        
        # Step 1: Check if AWS profile exists
        echo "1. Checking AWS profile..."
        if ! aws configure list-profiles | grep -q "^$profile$"; then
            echo "   ✗ AWS profile '$profile' does not exist"
            return 1
        fi
        echo "   ✓ AWS profile exists"
        
        # Step 2: Check if profile can authenticate
        echo "2. Validating AWS authentication..."
        if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
            echo "   ✗ AWS profile '$profile' authentication failed"
            echo "   Please run: aws sso login --profile $profile"
            return 1
        fi
        echo "   ✓ AWS authentication successful"
        
        # Step 3: Check if ECR access is available
        echo "3. Checking ECR permissions..."
        local region
        region=$(echo "$registry" | cut -d'.' -f4)
        if [[ -z "$region" ]]; then
            echo "   ✗ Could not extract region from registry URL: $registry"
            return 1
        fi
        
        if ! aws ecr describe-repositories --profile "$profile" --region "$region" >/dev/null 2>&1; then
            echo "   ✗ ECR access denied for profile '$profile' in region '$region'"
            return 1
        fi
        echo "   ✓ ECR permissions verified"
        echo ""
        echo "✓ Registry validation completed successfully"
        return 0
    }
    
    # Add ECR registry
    add_ecr_registry() {
        local registry="$1"
        local profile="$2"
        
        # Create config if it doesn't exist
        if [[ ! -f "$docker_config" ]]; then
            echo '{"auths":{},"credHelpers":{},"registryConfigs":{}}' > "$docker_config"
        fi
        
        # Update config
        local temp_config
        temp_config=$(mktemp)
        
        jq --arg reg "$registry" --arg prof "$profile" '
            .credHelpers[$reg] = "smart-ecr-helper" |
            .registryConfigs[$reg] = {"profile": $prof}
        ' "$docker_config" > "$temp_config"
        
        mv "$temp_config" "$docker_config"
        echo "Added ECR registry: $registry -> $profile"
    }
    
    # Add ECR registry with null profile (for new registries)
    add_ecr_registry_with_null_profile() {
        local registry="$1"
        
        # Create config if it doesn't exist
        if [[ ! -f "$docker_config" ]]; then
            echo '{"auths":{},"credHelpers":{},"registryConfigs":{}}' > "$docker_config"
        fi
        
        # Update config with null profile
        local temp_config
        temp_config=$(mktemp)
        
        jq --arg reg "$registry" '
            .credHelpers[$reg] = "smart-ecr-helper" |
            .registryConfigs[$reg] = {"profile": null}
        ' "$docker_config" > "$temp_config"
        
        mv "$temp_config" "$docker_config"
        echo "Added ECR registry: $registry (profile to be assigned)"
    }
    
    # Update ECR registry profile
    update_ecr_registry_profile() {
        local registry="$1"
        local profile="$2"
        
        if [[ ! -f "$docker_config" ]]; then
            echo "Docker config not found"
            return 1
        fi
        
        local temp_config
        temp_config=$(mktemp)
        
        jq --arg reg "$registry" --arg prof "$profile" '
            .registryConfigs[$reg].profile = $prof
        ' "$docker_config" > "$temp_config"
        
        mv "$temp_config" "$docker_config"
        echo "Updated ECR registry: $registry -> $profile"
    }
    
    # Remove ECR registry
    remove_ecr_registry() {
        local registry="$1"
        local temp_config
        temp_config=$(mktemp)
        
        jq --arg reg "$registry" '
            del(.credHelpers[$reg]) |
            del(.registryConfigs[$reg])
        ' "$docker_config" > "$temp_config"
        
        mv "$temp_config" "$docker_config"
        echo "Removed ECR registry: $registry"
    }
    
    
    
    
    
    # ECR validation after AWS sync (called from aws-manager)
    validate_ecr_registries_after_aws_sync() {
        echo "Validating ECR registries after AWS sync..."
        echo ""
        
        local registries
        registries=$(list_ecr_registries)
        
        if [[ -z "$registries" ]]; then
            echo "No ECR registries found"
            return 0
        fi
        
        local processed=0
        local valid=0
        local invalid=0
        
        while IFS= read -r registry; do
            if [[ -n "$registry" ]]; then
                echo "Processing registry: $registry"
                process_ecr_registry_after_aws_sync "$registry"
                local result=$?
                ((processed++))
                
                if [[ $result -eq 0 ]]; then
                    ((valid++))
                else
                    ((invalid++))
                fi
                echo ""
            fi
        done < <(echo "$registries")
        
        echo "ECR Validation Summary:"
        echo "  Processed: $processed"
        echo "  Valid: $valid"
        echo "  Invalid: $invalid"
    }
    
    # Process individual ECR registry after AWS sync
    process_ecr_registry_after_aws_sync() {
        local registry="$1"
        local profile
        profile=$(get_ecr_registry_profile "$registry")
        
        # Check if profile is null or empty (new registry)
        if [[ "$profile" == "null" || -z "$profile" ]]; then
            echo "  + New registry - assigning profile"
            assign_profile_to_registry "$registry"
            return $?
        fi
        
        # Check if profile exists in AWS config
        if ! aws configure list-profiles | grep -q "^$profile$"; then
            echo "  ✗ Profile '$profile' not found in AWS config"
            handle_missing_profile "$registry" "$profile"
            return $?
        fi
        
        # Validate existing profile
        if validate_ecr_registry "$registry" "$profile"; then
            echo "  ✓ Registry valid with profile: $profile"
            return 0
        else
            echo "  ✗ Profile '$profile' invalid for registry"
            handle_invalid_profile "$registry" "$profile"
            return $?
        fi
    }
    
    # Assign profile to registry (non-interactive)
    assign_profile_to_registry() {
        local registry="$1"
        local profile="$2"
        
        if [[ -z "$profile" ]]; then
            echo "Profile parameter is required" >&2
            return 1
        fi
        
        # Validate profile exists
        if ! echo "$(list_aws_profiles)" | grep -q "^''${profile}$"; then
            echo "Profile '$profile' not found" >&2
            return 1
        fi
        
        update_ecr_registry_profile "$registry" "$profile"
        if validate_ecr_registry "$registry" "$profile"; then
            echo "  ✓ Profile assigned and validated: $profile"
            return 0
        else
            echo "  ✗ Profile assignment failed validation"
            return 1
        fi
    }
    
    # Handle missing profile (non-interactive - removes registry)
    handle_missing_profile() {
        local registry="$1"
        local old_profile="$2"
        
        echo "  Profile '$old_profile' is missing. Removing registry: $registry"
        remove_ecr_registry "$registry"
        echo "  ✓ Registry removed"
        return 0
    }
    
    # Handle invalid profile (non-interactive - removes registry)
    handle_invalid_profile() {
        local registry="$1"
        local old_profile="$2"
        
        echo "  Profile '$old_profile' is invalid. Removing registry: $registry"
        remove_ecr_registry "$registry"
        echo "  ✓ Registry removed"
        return 0
    }
    
    # Show help
    show_help() {
        echo "ECR Registry Manager"
        echo ""
        echo "Usage: ecr-mgr <command> [options]"
        echo ""
        echo "Commands:"
        echo "  ls                        List ECR registries"
        echo "  add <url> <profile>        Add new ECR registry with AWS profile"
        echo "  update <url> <profile>     Update ECR registry profile"
        echo "  rm <url>                   Remove ECR registry"
        echo "  validate <url>             Validate ECR registry (auth + permissions)"
        echo "  help                      Show this help"
        echo ""
        echo "Examples:"
        echo "  ecr-mgr ls"
        echo "  ecr-mgr add 123456789012.dkr.ecr.us-east-1.amazonaws.com my-aws-profile"
        echo "  ecr-mgr update 123456789012.dkr.ecr.us-east-1.amazonaws.com my-aws-profile"
        echo "  ecr-mgr rm 123456789012.dkr.ecr.us-east-1.amazonaws.com"
        echo "  ecr-mgr validate 123456789012.dkr.ecr.us-east-1.amazonaws.com"
    }
    
    
    # Main ECR Manager CLI
    ecr_manager() {
        local command="''${1:-help}"
        
        case "$command" in
            "ls")
                echo "ECR Registries:"
                list_ecr_registries | while read -r registry; do
                    if [[ -n "$registry" ]]; then
                        local profile
                        profile=$(get_ecr_registry_profile "$registry")
                        echo "  $registry -> $profile"
                    fi
                done
                ;;
            "add")
                local registry="''${2:-}"
                local profile="''${3:-}"
                if [[ -n "$registry" && -n "$profile" ]]; then
                    # Sanitize and validate input
                    registry=$(sanitize_input "$registry")
                    if ! validate_registry_url "$registry"; then
                        return 1
                    fi
                    
                    # Validate profile exists
                    if ! echo "$(list_aws_profiles)" | grep -q "^''${profile}$"; then
                        echo "Profile '$profile' not found" >&2
                        echo "Available profiles:" >&2
                        list_aws_profiles | sed 's/^/  /' >&2
                        return 1
                    fi
                    
                    # Add registry with specified profile
                    add_ecr_registry "$registry" "$profile"
                    echo "Registry added with profile: $profile"
                    
                    echo ""
                    echo "Validating registry after adding..."
                    validate_ecr_registry "$registry" "$profile"
                else
                    echo "Usage: ecr-mgr add <registry-url> <aws-profile>"
                    echo "Example: ecr-mgr add 123456789012.dkr.ecr.us-east-1.amazonaws.com my-profile"
                    echo ""
                    echo "Available AWS profiles:"
                    list_aws_profiles | sed 's/^/  /'
                fi
                ;;
            "update")
                local registry="''${2:-}"
                local profile="''${3:-}"
                if [[ -n "$registry" && -n "$profile" ]]; then
                    local current_profile
                    current_profile=$(get_ecr_registry_profile "$registry")
                    
                    echo "Updating registry: $registry"
                    echo "Current profile: $current_profile"
                    echo "New profile: $profile"
                    echo ""
                    
                    # Update the registry profile
                    update_ecr_registry_profile "$registry" "$profile"
                    echo "Updated ECR registry: $registry -> $profile"
                    
                    # Validate the updated registry
                    echo ""
                    echo "Validating updated registry..."
                    validate_ecr_registry "$registry" "$profile"
                else
                    echo "Usage: ecr-mgr update <registry-url> <aws-profile>"
                    echo "Example: ecr-mgr update 123456789012.dkr.ecr.us-east-1.amazonaws.com my-profile"
                fi
                ;;
            "rm")
                local registry="''${2:-}"
                if [[ -n "$registry" ]]; then
                    remove_ecr_registry "$registry"
                else
                    echo "Usage: ecr-mgr rm <registry-url>"
                    echo "Example: ecr-mgr rm 123456789012.dkr.ecr.us-east-1.amazonaws.com"
                fi
                ;;
            "validate")
                local registry="''${2:-}"
                if [[ -n "$registry" ]]; then
                    validate_ecr_registry "$registry"
                else
                    echo "Usage: ecr-mgr validate <registry-url>"
                    echo "Example: ecr-mgr validate 123456789012.dkr.ecr.us-east-1.amazonaws.com"
                fi
                ;;
            "validate-after-sync")
                validate_ecr_registries_after_aws_sync
                ;;
            "help"|*)
                show_help
                ;;
        esac
    }
    
    # Execute the manager
    ecr_manager "$@"
  '';

in
{
  home.packages = [
    ecrManagerScript
  ];

  # Shell aliases for easy access
  programs.zsh.shellAliases = {
    ecr-mgr = "ecr-manager";
  };
}
