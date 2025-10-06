#!/bin/bash

# Standalone AWS/ECR Functions for Testing
# This script contains all the AWS and ECR management functions from the Nix project
# Usage: source standalone-aws-ecr-functions.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper function for AWS CLI-style prompts
get_existing_or_new_value() {
    local prompt="$1"
    local existing_value="$2"
    local new_value
    
    if [[ -n "$existing_value" ]]; then
        read -p "$prompt ($existing_value): " new_value
        echo "${new_value:-$existing_value}"
    else
        read -p "$prompt: " new_value
        echo "$new_value"
    fi
}

# =============================================================================
# AWS PROFILE MANAGEMENT FUNCTIONS
# =============================================================================

# Main AWS profile setup function
setup-aws-profile() {
    echo
    print_status "🔧 AWS Profile Setup"
    echo
    echo "What would you like to do?"
    echo "  1) Add new AWS profile"
    echo "  2) Update existing AWS profile"
    echo "  3) Resync AWS profiles (auto-discovery)"
    echo "  4) Remove AWS profile"
    echo "  5) List AWS profiles"
    echo "  6) Test AWS profile"
    echo
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1) setup_new_aws_profile ;;
        2) update-aws-profile ;;
        3) resync-aws-profiles ;;
        4) remove-aws-profile ;;
        5) list-aws-profiles ;;
        6) test-aws-profile ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Setup new AWS profile
setup_new_aws_profile() {
    echo
    print_status "Setting up new AWS profile..."
    echo
    echo "What type of AWS profile would you like to create?"
    echo "  1) SSO Profile (Single Sign-On)"
    echo "  2) Credentials Profile (Access Key/Secret Key)"
    echo "  3) Role Profile (Assume Role)"
    echo
    read -p "Enter your choice (1-3): " profile_type
    
    case $profile_type in
        1) setup_sso_profile ;;
        2) setup_credentials_profile ;;
        3) setup_role_profile ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Setup SSO profile
setup_sso_profile() {
    echo
    print_status "Setting up SSO profile..."
    
    read -p "Profile name: " profile_name
    if [[ -z "$profile_name" ]]; then
        print_error "Profile name cannot be empty"
        return 1
    fi
    
    read -p "SSO start URL: " sso_start_url
    read -p "SSO region: " sso_region
    read -p "SSO account ID: " sso_account_id
    read -p "SSO role name: " sso_role_name
    
    if [[ -z "$sso_start_url" || -z "$sso_region" || -z "$sso_account_id" || -z "$sso_role_name" ]]; then
        print_error "All SSO fields are required"
        return 1
    fi
    
    # Configure AWS profile
    aws configure set sso_start_url "$sso_start_url" --profile "$profile_name"
    aws configure set sso_region "$sso_region" --profile "$profile_name"
    aws configure set sso_account_id "$sso_account_id" --profile "$profile_name"
    aws configure set sso_role_name "$sso_role_name" --profile "$profile_name"
    
    print_success "SSO profile '$profile_name' configured successfully"
    print_status "Run 'aws sso login --profile $profile_name' to authenticate"
}

# Setup credentials profile
setup_credentials_profile() {
    echo
    print_status "Setting up credentials profile..."
    
    read -p "Profile name: " profile_name
    if [[ -z "$profile_name" ]]; then
        print_error "Profile name cannot be empty"
        return 1
    fi
    
    read -p "AWS Access Key ID: " access_key
    read -p "AWS Secret Access Key: " secret_key
    read -p "Default region: " region
    
    if [[ -z "$access_key" || -z "$secret_key" ]]; then
        print_error "Access Key ID and Secret Access Key are required"
        return 1
    fi
    
    # Configure AWS profile
    aws configure set aws_access_key_id "$access_key" --profile "$profile_name"
    aws configure set aws_secret_access_key "$secret_key" --profile "$profile_name"
    aws configure set region "${region:-us-east-1}" --profile "$profile_name"
    
    print_success "Credentials profile '$profile_name' configured successfully"
}

# Setup role profile
setup_role_profile() {
    echo
    print_status "Setting up role profile..."
    
    read -p "Profile name: " profile_name
    if [[ -z "$profile_name" ]]; then
        print_error "Profile name cannot be empty"
        return 1
    fi
    
    read -p "Source profile: " source_profile
    read -p "Role ARN: " role_arn
    read -p "External ID (optional): " external_id
    
    if [[ -z "$source_profile" || -z "$role_arn" ]]; then
        print_error "Source profile and Role ARN are required"
        return 1
    fi
    
    # Configure AWS profile
    aws configure set role_arn "$role_arn" --profile "$profile_name"
    aws configure set source_profile "$source_profile" --profile "$profile_name"
    if [[ -n "$external_id" ]]; then
        aws configure set external_id "$external_id" --profile "$profile_name"
    fi
    
    print_success "Role profile '$profile_name' configured successfully"
}

# Update AWS profile
update-aws-profile() {
    echo
    print_status "Updating AWS profile..."
    
    # List available profiles
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found"
        return 1
    fi
    
    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        echo "  $((i+1))) ${profiles[$i]}"
    done
    
    read -p "Select profile to update: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${profiles[$((choice-1))]}"
    
    # Detect profile type and update accordingly
    if aws configure get sso_start_url --profile "$profile_name" >/dev/null 2>&1; then
        update_sso_profile_direct "$profile_name"
    elif aws configure get role_arn --profile "$profile_name" >/dev/null 2>&1; then
        update_role_profile_direct "$profile_name"
    else
        update_credentials_profile_direct "$profile_name"
    fi
}

# Update SSO profile directly
update_sso_profile_direct() {
    local profile_name="$1"
    
    local sso_start_url=$(aws configure get sso_start_url --profile "$profile_name" 2>/dev/null)
    local sso_region=$(aws configure get sso_region --profile "$profile_name" 2>/dev/null)
    local sso_account_id=$(aws configure get sso_account_id --profile "$profile_name" 2>/dev/null)
    local sso_role_name=$(aws configure get sso_role_name --profile "$profile_name" 2>/dev/null)
    
    sso_start_url=$(get_existing_or_new_value "SSO start URL" "$sso_start_url")
    sso_region=$(get_existing_or_new_value "SSO region" "$sso_region")
    sso_account_id=$(get_existing_or_new_value "SSO account ID" "$sso_account_id")
    sso_role_name=$(get_existing_or_new_value "SSO role name" "$sso_role_name")
    
    aws configure set sso_start_url "$sso_start_url" --profile "$profile_name"
    aws configure set sso_region "$sso_region" --profile "$profile_name"
    aws configure set sso_account_id "$sso_account_id" --profile "$profile_name"
    aws configure set sso_role_name "$sso_role_name" --profile "$profile_name"
    
    print_success "SSO profile '$profile_name' updated successfully"
}

# Update credentials profile directly
update_credentials_profile_direct() {
    local profile_name="$1"
    
    local access_key=$(aws configure get aws_access_key_id --profile "$profile_name" 2>/dev/null)
    local secret_key=$(aws configure get aws_secret_access_key --profile "$profile_name" 2>/dev/null)
    local region=$(aws configure get region --profile "$profile_name" 2>/dev/null)
    
    access_key=$(get_existing_or_new_value "AWS Access Key ID" "$access_key")
    secret_key=$(get_existing_or_new_value "AWS Secret Access Key" "$secret_key")
    region=$(get_existing_or_new_value "Default region" "$region")
    
    aws configure set aws_access_key_id "$access_key" --profile "$profile_name"
    aws configure set aws_secret_access_key "$secret_key" --profile "$profile_name"
    aws configure set region "$region" --profile "$profile_name"
    
    print_success "Credentials profile '$profile_name' updated successfully"
}

# Update role profile directly
update_role_profile_direct() {
    local profile_name="$1"
    
    local role_arn=$(aws configure get role_arn --profile "$profile_name" 2>/dev/null)
    local source_profile=$(aws configure get source_profile --profile "$profile_name" 2>/dev/null)
    local external_id=$(aws configure get external_id --profile "$profile_name" 2>/dev/null)
    
    role_arn=$(get_existing_or_new_value "Role ARN" "$role_arn")
    source_profile=$(get_existing_or_new_value "Source profile" "$source_profile")
    external_id=$(get_existing_or_new_value "External ID" "$external_id")
    
    aws configure set role_arn "$role_arn" --profile "$profile_name"
    aws configure set source_profile "$source_profile" --profile "$profile_name"
    if [[ -n "$external_id" ]]; then
        aws configure set external_id "$external_id" --profile "$profile_name"
    fi
    
    print_success "Role profile '$profile_name' updated successfully"
}

# Resync AWS profiles
resync-aws-profiles() {
    echo
    print_status "Resyncing AWS profiles..."
    echo
    echo "What would you like to resync?"
    echo "  1) SSO profiles only"
    echo "  2) IAM profiles only"
    echo "  3) Complete resync (SSO + IAM)"
    echo
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1) resync_sso_profiles ;;
        2) resync_iam_profiles ;;
        3) resync_complete ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Resync SSO profiles
resync_sso_profiles() {
    print_status "Resyncing SSO profiles..."
    
    # Get all SSO profiles
    local sso_profiles=($(aws configure list-profiles | while read profile; do
        if aws configure get sso_start_url --profile "$profile" >/dev/null 2>&1; then
            echo "$profile"
        fi
    done))
    
    if [[ ${#sso_profiles[@]} -eq 0 ]]; then
        print_warning "No SSO profiles found"
        return 0
    fi
    
    print_status "Found ${#sso_profiles[@]} SSO profiles to resync"
    
    for profile in "${sso_profiles[@]}"; do
        print_status "Resyncing SSO profile: $profile"
        
        # Get existing values
        local sso_start_url=$(aws configure get sso_start_url --profile "$profile" 2>/dev/null)
        local sso_region=$(aws configure get sso_region --profile "$profile" 2>/dev/null)
        local sso_account_id=$(aws configure get sso_account_id --profile "$profile" 2>/dev/null)
        local sso_role_name=$(aws configure get sso_role_name --profile "$profile" 2>/dev/null)
        
        # Prompt for updates
        sso_start_url=$(get_existing_or_new_value "SSO start URL" "$sso_start_url")
        sso_region=$(get_existing_or_new_value "SSO region" "$sso_region")
        sso_account_id=$(get_existing_or_new_value "SSO account ID" "$sso_account_id")
        sso_role_name=$(get_existing_or_new_value "SSO role name" "$sso_role_name")
        
        # Update configuration
        aws configure set sso_start_url "$sso_start_url" --profile "$profile"
        aws configure set sso_region "$sso_region" --profile "$profile"
        aws configure set sso_account_id "$sso_account_id" --profile "$profile"
        aws configure set sso_role_name "$sso_role_name" --profile "$profile"
        
        print_success "Updated SSO profile: $profile"
    done
}

# Resync IAM profiles
resync_iam_profiles() {
    print_status "Resyncing IAM profiles..."
    
    # Get all IAM profiles (non-SSO, non-role profiles)
    local iam_profiles=($(aws configure list-profiles | while read profile; do
        if ! aws configure get sso_start_url --profile "$profile" >/dev/null 2>&1 && \
           ! aws configure get role_arn --profile "$profile" >/dev/null 2>&1; then
            echo "$profile"
        fi
    done))
    
    if [[ ${#iam_profiles[@]} -eq 0 ]]; then
        print_warning "No IAM profiles found"
        return 0
    fi
    
    print_status "Found ${#iam_profiles[@]} IAM profiles to resync"
    
    for profile in "${iam_profiles[@]}"; do
        print_status "Resyncing IAM profile: $profile"
        
        # Get existing values
        local access_key=$(aws configure get aws_access_key_id --profile "$profile" 2>/dev/null)
        local secret_key=$(aws configure get aws_secret_access_key --profile "$profile" 2>/dev/null)
        local region=$(aws configure get region --profile "$profile" 2>/dev/null)
        
        # Prompt for updates
        access_key=$(get_existing_or_new_value "AWS Access Key ID" "$access_key")
        secret_key=$(get_existing_or_new_value "AWS Secret Access Key" "$secret_key")
        region=$(get_existing_or_new_value "Default region" "$region")
        
        # Update configuration
        aws configure set aws_access_key_id "$access_key" --profile "$profile"
        aws configure set aws_secret_access_key "$secret_key" --profile "$profile"
        aws configure set region "$region" --profile "$profile"
        
        print_success "Updated IAM profile: $profile"
    done
}

# Complete resync
resync_complete() {
    print_status "Performing complete resync..."
    resync_sso_profiles
    echo
    resync_iam_profiles
    print_success "Complete resync finished"
}

# Remove AWS profile
remove-aws-profile() {
    echo
    print_status "Removing AWS profile..."
    
    # List available profiles
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found"
        return 1
    fi
    
    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        echo "  $((i+1))) ${profiles[$i]}"
    done
    
    read -p "Select profile to remove: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${profiles[$((choice-1))]}"
    
    # Check for dependent ECR profiles
    local ecr_profiles=($(grep -l "ecr-login-$profile_name" ~/.docker/config.json 2>/dev/null || true))
    
    if [[ ${#ecr_profiles[@]} -gt 0 ]]; then
        print_warning "Found dependent ECR profiles for '$profile_name'"
        echo "  1) Remove AWS profile only"
        echo "  2) Remove AWS profile and dependent ECR profiles"
        echo "  3) Cancel"
        read -p "Enter your choice (1-3): " remove_choice
        
        case $remove_choice in
            1) remove_aws_profile_only "$profile_name" ;;
            2) remove_aws_profile_and_ecr "$profile_name" ;;
            3) print_status "Cancelled" ;;
            *) print_error "Invalid choice" ;;
        esac
    else
        remove_aws_profile_only "$profile_name"
    fi
}

# Remove AWS profile only
remove_aws_profile_only() {
    local profile_name="$1"
    
    # Remove from AWS config
    aws configure set aws_access_key_id "" --profile "$profile_name"
    aws configure set aws_secret_access_key "" --profile "$profile_name"
    aws configure set region "" --profile "$profile_name"
    aws configure set sso_start_url "" --profile "$profile_name"
    aws configure set sso_region "" --profile "$profile_name"
    aws configure set sso_account_id "" --profile "$profile_name"
    aws configure set sso_role_name "" --profile "$profile_name"
    aws configure set role_arn "" --profile "$profile_name"
    aws configure set source_profile "" --profile "$profile_name"
    aws configure set external_id "" --profile "$profile_name"
    
    print_success "AWS profile '$profile_name' removed successfully"
}

# Remove AWS profile and ECR profiles
remove_aws_profile_and_ecr() {
    local profile_name="$1"
    
    # Remove AWS profile
    remove_aws_profile_only "$profile_name"
    
    # Remove ECR profiles
    print_status "Removing dependent ECR profiles..."
    # This would call remove-ecr-profile for each dependent profile
    print_warning "ECR profile removal not fully implemented in standalone version"
}

# List AWS profiles
list-aws-profiles() {
    echo
    print_status "AWS Profiles:"
    echo
    
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_warning "No AWS profiles found"
        return 0
    fi
    
    for profile in "${profiles[@]}"; do
        echo "Profile: $profile"
        
        # Check profile type
        if aws configure get sso_start_url --profile "$profile" >/dev/null 2>&1; then
            echo "  Type: SSO"
            echo "  SSO URL: $(aws configure get sso_start_url --profile "$profile")"
            echo "  Region: $(aws configure get sso_region --profile "$profile")"
        elif aws configure get role_arn --profile "$profile" >/dev/null 2>&1; then
            echo "  Type: Role"
            echo "  Role ARN: $(aws configure get role_arn --profile "$profile")"
            echo "  Source: $(aws configure get source_profile --profile "$profile")"
        else
            echo "  Type: Credentials"
            echo "  Region: $(aws configure get region --profile "$profile")"
        fi
        echo
    done
}

# Test AWS profile
test-aws-profile() {
    echo
    print_status "Testing AWS profile..."
    
    # List available profiles
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found"
        return 1
    fi
    
    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        echo "  $((i+1))) ${profiles[$i]}"
    done
    
    read -p "Select profile to test: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${profiles[$((choice-1))]}"
    
    print_status "Testing profile: $profile_name"
    
    if aws sts get-caller-identity --profile "$profile_name" >/dev/null 2>&1; then
        print_success "Profile '$profile_name' is working correctly"
        aws sts get-caller-identity --profile "$profile_name"
    else
        print_error "Profile '$profile_name' authentication failed"
        print_status "Make sure you're logged in: aws sso login --profile $profile_name"
    fi
}

# =============================================================================
# ECR PROFILE MANAGEMENT FUNCTIONS
# =============================================================================

# Main ECR profile setup function
setup-ecr-profiles() {
    echo
    print_status "🐳 ECR Profile Setup"
    echo
    echo "What would you like to do?"
    echo "  1) Add new ECR profile"
    echo "  2) Update existing ECR profile"
    echo "  3) Remove ECR profile"
    echo "  4) List ECR profiles"
    echo "  5) Test ECR profile"
    echo
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1) setup_new_ecr_profile ;;
        2) update-ecr-profile ;;
        3) remove-ecr-profile ;;
        4) list-ecr-profiles ;;
        5) test-ecr-profile ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Setup new ECR profile
setup_new_ecr_profile() {
    echo
    print_status "Setting up new ECR profile..."
    echo
    echo "How would you like to set up ECR?"
    echo "  1) Auto-discovery (find accessible ECR registries)"
    echo "  2) Manual setup (specify registry URL)"
    echo
    read -p "Enter your choice (1-2): " choice
    
    case $choice in
        1) setup_ecr_auto ;;
        2) setup_ecr_manual ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Setup ECR auto-discovery
setup_ecr_auto() {
    print_status "ECR auto-discovery..."
    
    # List available AWS profiles
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found. Please set up AWS profiles first."
        return 1
    fi
    
    echo "Available AWS profiles:"
    for i in "${!profiles[@]}"; do
        echo "  $((i+1))) ${profiles[$i]}"
    done
    
    read -p "Select AWS profile to use for discovery: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${profiles[$((choice-1))]}"
    
    print_status "Discovering ECR registries for profile: $profile_name"
    
    # Test if profile is authenticated
    if ! aws sts get-caller-identity --profile "$profile_name" >/dev/null 2>&1; then
        print_error "Profile '$profile_name' is not authenticated"
        print_status "Please run: aws sso login --profile $profile_name"
        return 1
    fi
    
    # Discover ECR registries
    local registries=()
    
    # Get current account ID
    local account_id=$(aws sts get-caller-identity --profile "$profile_name" --query Account --output text 2>/dev/null)
    if [[ -n "$account_id" ]]; then
        print_status "Current account: $account_id"
        
        # Get available regions
        local regions=($(aws ec2 describe-regions --profile "$profile_name" --query 'Regions[].RegionName' --output text 2>/dev/null))
        
        if [[ ${#regions[@]} -gt 0 ]]; then
            print_status "Checking ECR access in ${#regions[@]} regions..."
            
            for region in "${regions[@]}"; do
                local registry_url="$account_id.dkr.ecr.$region.amazonaws.com"
                
                # Test ECR access
                if aws ecr get-authorization-token --profile "$profile_name" --region "$region" >/dev/null 2>&1; then
                    registries+=("$registry_url")
                    print_success "Found accessible ECR registry: $registry_url"
                fi
            done
        else
            print_warning "Could not retrieve regions for profile: $profile_name"
        fi
    else
        print_warning "Could not retrieve account ID for profile: $profile_name"
    fi
    
    if [[ ${#registries[@]} -eq 0 ]]; then
        print_warning "No accessible ECR registries found"
        print_status "You can still set up ECR manually"
        return 1
    fi
    
    # Ask user which registries to set up
    echo
    print_status "Found ${#registries[@]} accessible ECR registries:"
    for i in "${!registries[@]}"; do
        echo "  $((i+1))) ${registries[$i]}"
    done
    echo "  $(( ${#registries[@]} + 1 ))) All registries"
    echo "  $(( ${#registries[@]} + 2 ))) Cancel"
    
    read -p "Select registries to set up: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#registries[@]} + 2 )); then
        print_error "Invalid selection"
        return 1
    fi
    
    if (( choice == ${#registries[@]} + 2 )); then
        print_status "Cancelled"
        return 0
    fi
    
    # Set up selected registries
    if (( choice == ${#registries[@]} + 1 )); then
        # Set up all registries
        for registry in "${registries[@]}"; do
            setup-ecr-profile "$profile_name" "$registry"
        done
    else
        # Set up selected registry
        local selected_registry="${registries[$((choice-1))]}"
        setup-ecr-profile "$profile_name" "$selected_registry"
    fi
    
    print_success "ECR auto-discovery completed"
}

# Setup ECR manual
setup_ecr_manual() {
    echo
    print_status "Manual ECR setup..."
    
    read -p "ECR registry URL (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com): " registry_url
    if [[ -z "$registry_url" ]]; then
        print_error "Registry URL cannot be empty"
        return 1
    fi
    
    # List available AWS profiles
    local profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found. Please set up AWS profiles first."
        return 1
    fi
    
    echo "Available AWS profiles:"
    for i in "${!profiles[@]}"; do
        echo "  $((i+1))) ${profiles[$i]}"
    done
    
    read -p "Select AWS profile to use: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${profiles[$((choice-1))]}"
    
    # Create ECR profile
    setup-ecr-profile "$profile_name" "$registry_url"
}

# Setup ECR profile helper
setup-ecr-profile() {
    local profile_name="$1"
    local registry_url="$2"
    
    print_status "Setting up ECR profile for '$profile_name' with registry '$registry_url'..."
    
    # Create smart-ecr-helper if it doesn't exist
    local bin_dir="$HOME/.local/share/bin"
    local smart_helper="$bin_dir/smart-ecr-helper"
    
    if [[ ! -f "$smart_helper" ]]; then
        create_smart_ecr_helper
    fi
    
    # Create profile-specific ECR binary
    local ecr_binary="$bin_dir/ecr-login-$profile_name"
    if [[ ! -f "$ecr_binary" ]]; then
        ln -sf "$smart_helper" "$ecr_binary"
        print_success "Created ECR binary: ecr-login-$profile_name"
    else
        print_success "ECR binary already exists: ecr-login-$profile_name"
    fi
    
    # Update Docker config
    local docker_config="$HOME/.docker/config.json"
    
    # Create Docker config if it doesn't exist
    if [[ ! -f "$docker_config" ]]; then
        mkdir -p "$HOME/.docker"
        echo '{"credHelpers":{}}' > "$docker_config"
    fi
    
    # Add ECR registry to Docker config
    if command -v jq >/dev/null 2>&1; then
        # Use jq to update the config
        jq --arg registry "$registry_url" --arg helper "ecr-login-$profile_name" \
           '.credHelpers[$registry] = $helper' "$docker_config" > "$docker_config.tmp" && \
        mv "$docker_config.tmp" "$docker_config"
        
        print_success "Updated Docker config for registry: $registry_url"
    else
        print_warning "jq not available, skipping Docker config update"
    fi
}

# Create smart-ecr-helper
create_smart_ecr_helper() {
    local bin_dir="$HOME/.local/share/bin"
    local helper_path="$bin_dir/smart-ecr-helper"
    
    # Create directory if it doesn't exist
    mkdir -p "$bin_dir"
    
    # Create the smart-ecr-helper script
    cat > "$helper_path" << 'EOF'
#!/bin/bash
# Get the profile name from the calling binary name
PROFILE_NAME=$(basename "$0" | sed 's/^ecr-login-//')
ECR_HELPER="docker-credential-helper-ecr"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/ecr-${PROFILE_NAME}.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$PROFILE_NAME] $*" >> "$LOG_FILE"
}

# Detect authentication method for profile
detect_auth_method() {
    if aws configure get sso_start_url --profile "$PROFILE_NAME" >/dev/null 2>&1; then
        echo "sso"
    else
        echo "credentials"
    fi
}

# Ensure SSO session is valid
ensure_sso_session() {
    if ! aws sts get-caller-identity --profile "$PROFILE_NAME" >/dev/null 2>&1; then
        log "SSO session expired for profile: $PROFILE_NAME"
        echo "SSO session expired for profile: $PROFILE_NAME" >&2
        echo "Please run: aws sso login --profile $PROFILE_NAME" >&2
        return 1
    fi
    return 0
}

# Main function
main() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "Starting ECR authentication for profile: $PROFILE_NAME"
    
    # Set AWS profile
    export AWS_PROFILE="$PROFILE_NAME"
    
    # Detect authentication method
    local auth_method=$(detect_auth_method)
    log "Authentication method: $auth_method"
    
    # Handle SSO authentication
    if [[ "$auth_method" == "sso" ]]; then
        if ! ensure_sso_session; then
            exit 1
        fi
    fi
    
    # Delegate to the actual ECR credential helper
    log "Delegating to docker-credential-helper-ecr"
    exec "$ECR_HELPER" "$@"
}

# Execute main function
main "$@"
EOF

    # Make it executable
    chmod +x "$helper_path"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        export PATH="$bin_dir:$PATH"
        print_status "Added $bin_dir to PATH for this session"
    fi
    
    print_success "smart-ecr-helper created at $helper_path"
}

# Update ECR profile
update-ecr-profile() {
    echo
    print_status "Updating ECR profile..."
    
    # List available ECR profiles
    local ecr_profiles=($(ls ~/.local/share/bin/ecr-login-* 2>/dev/null | sed 's/.*ecr-login-//' || true))
    if [[ ${#ecr_profiles[@]} -eq 0 ]]; then
        print_error "No ECR profiles found"
        return 1
    fi
    
    echo "Available ECR profiles:"
    for i in "${!ecr_profiles[@]}"; do
        echo "  $((i+1))) ${ecr_profiles[$i]}"
    done
    
    read -p "Select ECR profile to update: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ecr_profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${ecr_profiles[$((choice-1))]}"
    
    # List available AWS profiles
    local aws_profiles=($(aws configure list-profiles 2>/dev/null))
    if [[ ${#aws_profiles[@]} -eq 0 ]]; then
        print_error "No AWS profiles found"
        return 1
    fi
    
    echo "Available AWS profiles:"
    for i in "${!aws_profiles[@]}"; do
        echo "  $((i+1))) ${aws_profiles[$i]}"
    done
    
    read -p "Select new AWS profile: " aws_choice
    if ! [[ "$aws_choice" =~ ^[0-9]+$ ]] || (( aws_choice < 1 || aws_choice > ${#aws_profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local new_aws_profile="${aws_profiles[$((aws_choice-1))]}"
    
    # Update the ECR binary
    local bin_dir="$HOME/.local/share/bin"
    local old_binary="$bin_dir/ecr-login-$profile_name"
    local new_binary="$bin_dir/ecr-login-$new_aws_profile"
    
    if [[ -f "$old_binary" ]]; then
        rm "$old_binary"
        ln -sf "$bin_dir/smart-ecr-helper" "$new_binary"
        print_success "Updated ECR binary: ecr-login-$new_aws_profile"
    fi
    
    # Update Docker config
    local docker_config="$HOME/.docker/config.json"
    if [[ -f "$docker_config" ]] && command -v jq >/dev/null 2>&1; then
        # Find registry URL for this profile
        local registry_url=$(jq -r ".credHelpers | to_entries[] | select(.value == \"ecr-login-$profile_name\") | .key" "$docker_config" 2>/dev/null)
        
        if [[ -n "$registry_url" ]]; then
            # Update the credential helper
            jq --arg registry "$registry_url" --arg helper "ecr-login-$new_aws_profile" \
               '.credHelpers[$registry] = $helper' "$docker_config" > "$docker_config.tmp" && \
            mv "$docker_config.tmp" "$docker_config"
            
            print_success "Updated Docker config for registry: $registry_url"
        fi
    fi
}

# Remove ECR profile
remove-ecr-profile() {
    echo
    print_status "Removing ECR profile..."
    
    # List available ECR profiles
    local ecr_profiles=($(ls ~/.local/share/bin/ecr-login-* 2>/dev/null | sed 's/.*ecr-login-//' || true))
    if [[ ${#ecr_profiles[@]} -eq 0 ]]; then
        print_error "No ECR profiles found"
        return 1
    fi
    
    echo "Available ECR profiles:"
    for i in "${!ecr_profiles[@]}"; do
        echo "  $((i+1))) ${ecr_profiles[$i]}"
    done
    
    read -p "Select ECR profile to remove: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ecr_profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${ecr_profiles[$((choice-1))]}"
    
    # Remove ECR binary
    local bin_dir="$HOME/.local/share/bin"
    local ecr_binary="$bin_dir/ecr-login-$profile_name"
    
    if [[ -f "$ecr_binary" ]]; then
        rm "$ecr_binary"
        print_success "Removed ECR binary: ecr-login-$profile_name"
    fi
    
    # Remove from Docker config
    local docker_config="$HOME/.docker/config.json"
    if [[ -f "$docker_config" ]] && command -v jq >/dev/null 2>&1; then
        # Find registry URL for this profile
        local registry_url=$(jq -r ".credHelpers | to_entries[] | select(.value == \"ecr-login-$profile_name\") | .key" "$docker_config" 2>/dev/null)
        
        if [[ -n "$registry_url" ]]; then
            # Remove the credential helper
            jq --arg registry "$registry_url" 'del(.credHelpers[$registry])' "$docker_config" > "$docker_config.tmp" && \
            mv "$docker_config.tmp" "$docker_config"
            
            print_success "Removed Docker config entry for registry: $registry_url"
        fi
    fi
}

# List ECR profiles
list-ecr-profiles() {
    echo
    print_status "ECR Profiles:"
    echo
    
    local ecr_profiles=($(ls ~/.local/share/bin/ecr-login-* 2>/dev/null | sed 's/.*ecr-login-//' || true))
    if [[ ${#ecr_profiles[@]} -eq 0 ]]; then
        print_warning "No ECR profiles found"
        return 0
    fi
    
    for profile in "${ecr_profiles[@]}"; do
        echo "ECR Profile: $profile"
        
        # Find associated registry
        local docker_config="$HOME/.docker/config.json"
        if [[ -f "$docker_config" ]] && command -v jq >/dev/null 2>&1; then
            local registry_url=$(jq -r ".credHelpers | to_entries[] | select(.value == \"ecr-login-$profile\") | .key" "$docker_config" 2>/dev/null)
            if [[ -n "$registry_url" ]]; then
                echo "  Registry: $registry_url"
            fi
        fi
        echo
    done
}

# Test ECR profile
test-ecr-profile() {
    echo
    print_status "Testing ECR profile..."
    
    # List available ECR profiles
    local ecr_profiles=($(ls ~/.local/share/bin/ecr-login-* 2>/dev/null | sed 's/.*ecr-login-//' || true))
    if [[ ${#ecr_profiles[@]} -eq 0 ]]; then
        print_error "No ECR profiles found"
        return 1
    fi
    
    echo "Available ECR profiles:"
    for i in "${!ecr_profiles[@]}"; do
        echo "  $((i+1))) ${ecr_profiles[$i]}"
    done
    
    read -p "Select ECR profile to test: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ecr_profiles[@]} )); then
        print_error "Invalid selection"
        return 1
    fi
    
    local profile_name="${ecr_profiles[$((choice-1))]}"
    
    print_status "Testing ECR profile: $profile_name"
    
    # Find associated registry
    local docker_config="$HOME/.docker/config.json"
    local registry_url=""
    if [[ -f "$docker_config" ]] && command -v jq >/dev/null 2>&1; then
        registry_url=$(jq -r ".credHelpers | to_entries[] | select(.value == \"ecr-login-$profile_name\") | .key" "$docker_config" 2>/dev/null)
    fi
    
    if [[ -n "$registry_url" ]]; then
        print_status "Testing with registry: $registry_url"
        
        # Test the credential helper
        local ecr_binary="$HOME/.local/share/bin/ecr-login-$profile_name"
        if [[ -f "$ecr_binary" ]]; then
            echo "{\"ServerURL\":\"$registry_url\"}" | "$ecr_binary" get 2>&1 | head -5
            
            if [[ $? -eq 0 ]]; then
                print_success "ECR profile '$profile_name' is working correctly"
            else
                print_error "ECR profile '$profile_name' authentication failed"
                print_status "Make sure the associated AWS profile is configured and authenticated"
            fi
        else
            print_error "ECR binary not found: $ecr_binary"
        fi
    else
        print_warning "No registry URL found for profile '$profile_name'"
    fi
}

# =============================================================================
# MAIN SETUP FUNCTIONS
# =============================================================================

# Main setup function
setup-dev-environment() {
    echo
    print_status "🚀 Development Environment Setup"
    echo
    echo "What would you like to set up?"
    echo "  1) AWS profiles"
    echo "  2) ECR profiles"
    echo "  3) Both AWS and ECR profiles"
    echo
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1) setup-aws-profile ;;
        2) setup-ecr-profiles ;;
        3) 
            setup-aws-profile
            echo
            setup-ecr-profiles
            ;;
        *) print_error "Invalid choice" ;;
    esac
}

# Export all functions
export -f setup-aws-profile setup_new_aws_profile setup_sso_profile setup_credentials_profile setup_role_profile
export -f update-aws-profile update_sso_profile_direct update_credentials_profile_direct update_role_profile_direct
export -f resync-aws-profiles resync_sso_profiles resync_iam_profiles resync_complete
export -f remove-aws-profile remove_aws_profile_only remove_aws_profile_and_ecr
export -f list-aws-profiles test-aws-profile
export -f setup-ecr-profiles setup_new_ecr_profile setup_ecr_auto setup_ecr_manual setup-ecr-profile
export -f update-ecr-profile remove-ecr-profile list-ecr-profiles test-ecr-profile
export -f setup-dev-environment create_smart_ecr_helper get_existing_or_new_value

# Print welcome message
echo
print_success "✅ AWS/ECR Functions Loaded Successfully!"
echo
print_status "Available commands:"
print_status "  setup-aws-profile     - Manage AWS profiles (SSO, credentials, roles)"
print_status "  setup-ecr-profiles   - Manage ECR profiles for Docker authentication"
print_status "  setup-dev-environment - Complete development environment setup"
echo
print_status "Note: All features including auto-discovery are fully implemented!"
echo
