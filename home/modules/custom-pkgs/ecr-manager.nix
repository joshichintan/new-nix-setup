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
    
    # Select AWS profile interactively
    select_aws_profile() {
        local current_profile="$1"
        local profiles
        profiles=$(list_aws_profiles)
        
        if [[ -z "$profiles" ]]; then
            echo "No AWS profiles found. Please configure AWS profiles first."
            return 1
        fi
        
        echo "Available AWS profiles:"
        echo "$profiles" | nl -v1
        echo ""
        
        if [[ -n "$current_profile" ]]; then
            read -p "Select AWS profile [$current_profile]: " profile_num
        else
            read -p "Select AWS profile: " profile_num
        fi
        
        if [[ -z "$profile_num" && -n "$current_profile" ]]; then
            echo "$current_profile"
            return 0
        fi
        
        if [[ "$profile_num" =~ ^[0-9]+$ ]]; then
            local selected_profile
            selected_profile=$(echo "$profiles" | sed -n "''${profile_num}p")
            if [[ -n "$selected_profile" ]]; then
                echo "$selected_profile"
                return 0
            fi
        fi
        
        echo "Invalid selection" >&2
        return 1
    }
    
    # Validate ECR registry
    validate_ecr_registry() {
        local registry="$1"
        local profile="$2"
        
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
        
        # Check if AWS profile exists
        if ! aws configure list-profiles | grep -q "^$profile$"; then
            echo "✗ AWS profile '$profile' does not exist"
            return 1
        fi
        
        # Check if profile can authenticate
        if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
            echo "✗ AWS profile '$profile' authentication failed"
            echo "  Please run: aws sso login --profile $profile"
            return 1
        fi
        
        # Check if ECR access is available
        local region
        region=$(echo "$registry" | cut -d'.' -f4)
        if [[ -z "$region" ]]; then
            echo "✗ Could not extract region from registry URL: $registry"
            return 1
        fi
        
        if ! aws ecr describe-repositories --profile "$profile" --region "$region" >/dev/null 2>&1; then
            echo "✗ ECR access denied for profile '$profile' in region '$region'"
            return 1
        fi
        
        echo "✓ Registry validation successful"
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
    
    # Add ECR registry interactively
    add_ecr_registry_interactive() {
        echo "Add ECR Registry"
        echo "================"
        echo ""
        
        read -p "Enter registry URL: " registry
        if [[ -z "$registry" ]]; then
            echo "Registry URL is required"
            return 1
        fi
        
        # Sanitize and validate input
        registry=$(sanitize_input "$registry")
        if ! validate_registry_url "$registry"; then
            return 1
        fi
        
        # Add registry with null profile initially
        add_ecr_registry_with_null_profile "$registry"
        
        echo ""
        echo "Registry added. Profile will be assigned during next AWS sync."
        echo "Or you can assign a profile now:"
        echo "1) Assign profile now"
        echo "2) Skip (assign during AWS sync)"
        echo ""
        
        read -p "Select option (1-2): " choice
        case $choice in
            1)
                assign_profile_to_registry "$registry"
                ;;
            2)
                echo "Profile will be assigned during next AWS sync"
                ;;
            *)
                echo "Invalid option, profile will be assigned during next AWS sync"
                ;;
        esac
    }
    
    # Update ECR registry interactively
    update_ecr_registry_interactive() {
        echo "Update ECR Registry"
        echo "==================="
        echo ""
        
        # List existing registries
        local registries
        registries=$(list_ecr_registries)
        
        if [[ -z "$registries" ]]; then
            echo "No ECR registries found"
            return 0
        fi
        
        echo "Available registries:"
        echo "$registries" | nl -v1
        echo ""
        
        read -p "Enter registry number to update: " reg_num
        if [[ ! "$reg_num" =~ ^[0-9]+$ ]]; then
            echo "Invalid registry number"
            return 1
        fi
        
        local registry
        registry=$(echo "$registries" | sed -n "''${reg_num}p")
        if [[ -z "$registry" ]]; then
            echo "Invalid registry selection"
            return 1
        fi
        
        local current_profile
        current_profile=$(get_ecr_registry_profile "$registry")
        
        echo "Updating registry: $registry"
        echo "Current profile: $current_profile"
        echo ""
        
        # Select new AWS profile
        local new_profile
        new_profile=$(select_aws_profile "$current_profile")
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        
        # Update the registry profile
        update_ecr_registry_profile "$registry" "$new_profile"
        echo "Updated ECR registry: $registry -> $new_profile"
        
        # Validate the updated registry
        echo ""
        echo "Validating updated registry..."
        validate_ecr_registry "$registry" "$new_profile"
    }
    
    # Validate ECR registry interactively
    validate_ecr_registry_interactive() {
        echo "Validate ECR Registry"
        echo "====================="
        echo ""
        
        # List existing registries
        local registries
        registries=$(list_ecr_registries)
        
        if [[ -z "$registries" ]]; then
            echo "No ECR registries found"
            return 0
        fi
        
        echo "Available registries:"
        echo "$registries" | nl -v1
        echo ""
        
        read -p "Enter registry number to validate: " reg_num
        if [[ ! "$reg_num" =~ ^[0-9]+$ ]]; then
            echo "Invalid registry number"
            return 1
        fi
        
        local registry
        registry=$(echo "$registries" | sed -n "''${reg_num}p")
        if [[ -z "$registry" ]]; then
            echo "Invalid registry selection"
            return 1
        fi
        
        validate_ecr_registry "$registry"
    }
    
    # Test ECR registry interactively
    test_ecr_registry_interactive() {
        echo "Test ECR Registry"
        echo "================="
        echo ""
        
        # List existing registries
        local registries
        registries=$(list_ecr_registries)
        
        if [[ -z "$registries" ]]; then
            echo "No ECR registries found"
            return 0
        fi
        
        echo "Available registries:"
        echo "$registries" | nl -v1
        echo ""
        
        read -p "Enter registry number to test: " reg_num
        if [[ ! "$reg_num" =~ ^[0-9]+$ ]]; then
            echo "Invalid registry number"
            return 1
        fi
        
        local registry
        registry=$(echo "$registries" | sed -n "''${reg_num}p")
        if [[ -z "$registry" ]]; then
            echo "Invalid registry selection"
            return 1
        fi
        
        local profile
        profile=$(get_ecr_registry_profile "$registry")
        if [[ -n "$profile" ]]; then
            echo "Testing registry: $registry with profile: $profile"
            if docker pull "$registry/hello-world:latest" 2>/dev/null; then
                echo "✓ Registry test successful"
            else
                echo "✗ Registry test failed"
            fi
        else
            echo "No profile configured for registry: $registry"
        fi
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
    
    # Assign profile to new registry
    assign_profile_to_registry() {
        local registry="$1"
        local profile
        profile=$(select_aws_profile)
        
        if [[ $? -eq 0 && -n "$profile" ]]; then
            update_ecr_registry_profile "$registry" "$profile"
            if validate_ecr_registry "$registry" "$profile"; then
                echo "  ✓ Profile assigned and validated: $profile"
                return 0
            else
                echo "  ✗ Profile assignment failed validation"
                return 1
            fi
        else
            echo "  ✗ No profile selected"
            return 1
        fi
    }
    
    # Handle missing profile
    handle_missing_profile() {
        local registry="$1"
        local old_profile="$2"
        
        echo "  Profile '$old_profile' is missing. What would you like to do?"
        echo "  1) Assign new profile"
        echo "  2) Remove registry"
        echo ""
        
        read -p "Select option (1-2): " choice
        case $choice in
            1)
                assign_profile_to_registry "$registry"
                ;;
            2)
                remove_ecr_registry "$registry"
                        echo "  ✓ Registry removed"
                return 0
                ;;
            *)
                        echo "  ✗ Invalid option"
                return 1
                ;;
        esac
    }
    
    # Handle invalid profile
    handle_invalid_profile() {
        local registry="$1"
        local old_profile="$2"
        
        echo "  Profile '$old_profile' is invalid. What would you like to do?"
        echo "  1) Update profile"
        echo "  2) Remove registry"
        echo ""
        
        read -p "Select option (1-2): " choice
        case $choice in
            1)
                assign_profile_to_registry "$registry"
                ;;
            2)
                remove_ecr_registry "$registry"
                        echo "  ✓ Registry removed"
                return 0
                ;;
            *)
                        echo "  ✗ Invalid option"
                return 1
                ;;
        esac
    }
    
    # Main ECR Manager Menu
    ecr_manager() {
        while true; do
            echo ""
            echo "ECR Registry Manager"
            echo "==================="
            echo "1) List registries"
            echo "2) Add registry"
            echo "3) Update registry"
            echo "4) Remove registry"
            echo "5) Validate registry"
            echo "6) Test registry"
            echo "7) Exit"
            echo ""
            read -p "Select option (1-7): " choice
            
            case $choice in
                1)
                    echo "ECR Registries:"
                    list_ecr_registries | while read -r registry; do
                        if [[ -n "$registry" ]]; then
                            local profile
                            profile=$(get_ecr_registry_profile "$registry")
                            echo "  $registry -> $profile"
                        fi
                    done
                    ;;
                2)
                    add_ecr_registry_interactive
                    echo ""
                    echo "Validating registry after adding..."
                    validate_ecr_registry "$registry"
                    ;;
                3)
                    update_ecr_registry_interactive
                    echo ""
                    echo "Validating registry after updating..."
                    validate_ecr_registry "$registry"
                    ;;
                4)
                    echo "Available registries:"
                    list_ecr_registries | nl -v1
                    echo ""
                    read -p "Enter registry number to remove: " reg_num
                    local registry
                    registry=$(list_ecr_registries | sed -n "''${reg_num}p")
                    if [[ -n "$registry" ]]; then
                        read -p "Remove registry '$registry'? (y/N): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            remove_ecr_registry "$registry"
                        fi
                    fi
                    ;;
                5)
                    validate_ecr_registry_interactive
                    ;;
                6)
                    test_ecr_registry_interactive
                    ;;
                7)
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
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
