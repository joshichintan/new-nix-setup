#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Standalone ECR Setup Test Script
# =============================================================================
# This script contains everything needed to test ECR functionality on any computer
# Includes: smart-ecr-helper, Docker ECR utility, and ECR management functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}»${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    # Check required commands
    for cmd in aws jq docker; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - AWS CLI: https://aws.amazon.com/cli/"
        echo "  - jq: https://stedolan.github.io/jq/"
        echo "  - Docker: https://www.docker.com/get-started"
        exit 1
    fi
    
    print_success "All dependencies found"
}

# =============================================================================
# Smart ECR Helper Installation
# =============================================================================

install_smart_ecr_helper() {
    print_status "Installing smart-ecr-helper..."
    
    local bin_dir="$HOME/.local/share/bin"
    local smart_helper="$bin_dir/smart-ecr-helper"
    
    # Create directory if it doesn't exist
    mkdir -p "$bin_dir"
    
    # Create smart-ecr-helper script
    cat > "$smart_helper" << 'EOF'
#!/bin/bash
# Get the profile name from the calling binary name
PROFILE_NAME=$(basename "$0")
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
    
    chmod +x "$smart_helper"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$bin_dir"; then
        echo "export PATH=\"$bin_dir:\$PATH\"" >> ~/.bashrc
        echo "export PATH=\"$bin_dir:\$PATH\"" >> ~/.zshrc
        print_warning "Added $bin_dir to PATH in ~/.bashrc and ~/.zshrc"
        print_warning "Please run: source ~/.bashrc (or source ~/.zshrc) to update PATH"
    fi
    
    print_success "smart-ecr-helper installed at $smart_helper"
}

# =============================================================================
# Docker ECR Credential Helper Installation
# =============================================================================

install_docker_ecr_helper() {
    print_status "Installing docker-credential-helper-ecr..."
    
    # Check if already installed via Homebrew
    if command -v docker-credential-helper-ecr >/dev/null 2>&1; then
        print_success "docker-credential-helper-ecr already installed via Homebrew"
        return 0
    fi
    
    # Check if Homebrew is available
    if command -v brew >/dev/null 2>&1; then
        print_status "Installing via Homebrew..."
        if brew install amazon-ecr-credential-helper; then
            print_success "docker-credential-helper-ecr installed via Homebrew"
            return 0
        else
            print_warning "Homebrew installation failed, falling back to manual download"
        fi
    else
        print_warning "Homebrew not found, falling back to manual download"
    fi
    
    # Fallback: Manual download
    local bin_dir="$HOME/.local/share/bin"
    local ecr_helper="$bin_dir/docker-credential-helper-ecr"
    
    # Detect OS and architecture
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *) print_error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) print_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    
    # Download and install
    local version="0.7.0"
    local url="https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/${version}/docker-credential-ecr-login-${os}-${arch}-${version}"
    
    print_status "Downloading docker-credential-helper-ecr from $url"
    
    if curl -L -o "$ecr_helper" "$url"; then
        chmod +x "$ecr_helper"
        print_success "docker-credential-helper-ecr installed at $ecr_helper"
    else
        print_error "Failed to download docker-credential-helper-ecr"
        exit 1
    fi
}

# =============================================================================
# ECR Management Functions
# =============================================================================

# Main ECR profile management
setup-ecr-profiles() {
    echo "ECR Profile Management:"
    echo "1. Add new ECR registry"
    echo "2. Update ECR profile"
    echo "3. Remove ECR profile"
    echo "4. Resync ECR profiles"
    echo ""
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1) setup_new_ecr_profile ;;
        2) update_ecr_profile ;;
        3) remove_ecr_profile ;;
        4) resync_ecr_profiles ;;
        *) echo "Invalid choice" ;;
    esac
}

# Add new ECR registry
setup_new_ecr_profile() {
    echo "Add new ECR registry"
    echo ""
    
    # Get available AWS profiles
    aws_profiles=$(aws configure list-profiles)
    
    if [[ -z "$aws_profiles" ]]; then
        echo "No AWS profiles found"
        return 1
    fi
    
    echo "Available AWS profiles:"
    echo "$aws_profiles" | nl
    echo ""
    
    read -p "Select AWS profile number: " profile_num
    
    if [[ "$profile_num" =~ ^[0-9]+$ ]]; then
        selected_profile=$(aws configure list-profiles | sed -n "${profile_num}p")
        
        if [[ -n "$selected_profile" ]]; then
            echo ""
            read -p "ECR registry URL: " registry_url
            
            if [[ -n "$registry_url" ]]; then
                setup-ecr-profile "$selected_profile" "$registry_url"
                show_credhelper_config
            else
                echo "Registry URL is required"
            fi
        else
            echo "Invalid profile number"
        fi
    else
        echo "Invalid input"
    fi
}

# Update ECR profile
update_ecr_profile() {
    echo "Update ECR Profile"
    echo ""
    
    # List existing ECR profiles
    local ecr_profiles
    ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
    
    if [[ -z "$ecr_profiles" ]]; then
        echo "No ECR profiles found"
        return 0
    fi
    
    echo "Existing ECR profiles:"
    echo "$ecr_profiles" | nl
    echo ""
    
    read -p "Select ECR profile to update (number): " ecr_num
    
    if [[ "$ecr_num" =~ ^[0-9]+$ ]]; then
        local selected_ecr
        selected_ecr=$(echo "$ecr_profiles" | sed -n "${ecr_num}p")
        
        if [[ -n "$selected_ecr" ]]; then
            local registry_url
            registry_url=$(echo "$selected_ecr" | cut -d' ' -f1)
            local current_helper
            current_helper=$(echo "$selected_ecr" | cut -d' ' -f3)
            local current_aws_profile
            current_aws_profile=$(echo "$current_helper" | sed 's/^ecr-login-//')
            
            echo "Updating ECR profile for registry: $registry_url"
            echo ""
            
            # Get new AWS profile
            local new_aws_profile
            new_aws_profile=$(get_new_aws_profile "$current_aws_profile")
            
            if [[ -n "$new_aws_profile" ]]; then
                update_ecr_profile_direct "$registry_url" "$new_aws_profile"
                show_credhelper_config
            fi
        else
            echo "Invalid ECR profile number"
        fi
    else
        echo "Invalid input"
    fi
}

# Remove ECR profile
remove_ecr_profile() {
    echo "Remove ECR Profile"
    echo ""
    
    # List existing ECR profiles
    local ecr_profiles
    ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
    
    if [[ -z "$ecr_profiles" ]]; then
        echo "No ECR profiles found"
        return 0
    fi
    
    echo "Existing ECR profiles:"
    echo "$ecr_profiles" | nl
    echo ""
    
    read -p "Select ECR profile to remove (number): " ecr_num
    
    if [[ "$ecr_num" =~ ^[0-9]+$ ]]; then
        local selected_ecr
        selected_ecr=$(echo "$ecr_profiles" | sed -n "${ecr_num}p")
        
        if [[ -n "$selected_ecr" ]]; then
            local registry_url
            registry_url=$(echo "$selected_ecr" | cut -d' ' -f1)
            
            echo "Removing ECR profile for registry: $registry_url"
            echo ""
            
            read -p "Are you sure? (y/N): " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                remove_ecr_profile_direct "$registry_url"
                show_credhelper_config
            else
                echo "Cancelled"
            fi
        else
            echo "Invalid ECR profile number"
        fi
    else
        echo "Invalid input"
    fi
}

# Resync ECR profiles
resync_ecr_profiles() {
    echo "🔄 Resyncing ECR profiles..."
    echo ""
    
    # Get all ECR profiles from Docker config
    local ecr_profiles
    ecr_profiles=$(jq -r '.credHelpers // {} | to_entries[] | select(.value | startswith("ecr-login-")) | "\(.key) -> \(.value)"' ~/.docker/config.json 2>/dev/null || true)
    
    if [[ -z "$ecr_profiles" ]]; then
        echo "No ECR profiles found in Docker config"
        return 0
    fi
    
    # Check each ECR profile
    echo "$ecr_profiles" | while IFS=' -> ' read -r registry helper; do
        local aws_profile
        aws_profile=$(echo "$helper" | sed 's/^ecr-login-//')
        
        # Check if AWS profile exists
        if aws configure list-profiles | grep -q "^$aws_profile$"; then
            echo "✓ ECR profile is valid (AWS profile: $aws_profile exists)"
        else
            echo "⚠ ECR profile is invalid (AWS profile: $aws_profile missing)"
            handle_invalid_ecr_profile "$helper" "$registry"
        fi
    done
    
    echo ""
    echo "ECR resync complete!"
}

# Handle invalid ECR profile
handle_invalid_ecr_profile() {
    local ecr_profile="$1"
    local registry_url="$2"
    
    echo "ECR profile '$ecr_profile' has missing AWS profile"
    echo "Registry: $registry_url"
    echo ""
    echo "What would you like to do?"
    echo "1. Select new AWS profile"
    echo "2. Remove ECR profile"
    echo "3. Skip"
    echo ""
    
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            # Get new AWS profile
            local new_aws_profile
            new_aws_profile=$(get_new_aws_profile "")
            
            if [[ -n "$new_aws_profile" ]]; then
                update_ecr_profile_direct "$registry_url" "$new_aws_profile"
                show_credhelper_config
            fi
            ;;
        2)
            # Remove ECR profile
            remove_ecr_profile_direct "$registry_url"
            show_credhelper_config
            ;;
        3)
            echo "Skipping $ecr_profile"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# Get new AWS profile with validation
get_new_aws_profile() {
    local current_profile="$1"
    local prompt="New AWS profile"
    
    if [[ -n "$current_profile" ]]; then
        prompt="New AWS profile [$current_profile]"
    fi
    
    read -p "$prompt: " new_profile
    
    # Validate the profile exists
    if aws configure list-profiles | grep -q "^$new_profile$"; then
        echo "$new_profile"
    else
        echo "Invalid AWS profile: $new_profile" >&2
        return 1
    fi
}

# Update ECR profile direct
update_ecr_profile_direct() {
    local registry_url="$1"
    local new_aws_profile="$2"
    
    # Remove old ECR profile
    remove_ecr_profile_direct "$registry_url"
    
    # Create new ECR profile
    setup-ecr-profile "$new_aws_profile" "$registry_url"
}

# Remove ECR profile direct
remove_ecr_profile_direct() {
    local registry_url="$1"
    
    # Get current credential helper
    local current_helper
    current_helper=$(jq -r --arg reg "$registry_url" '.credHelpers[$reg] // empty' ~/.docker/config.json 2>/dev/null)
    
    if [[ -n "$current_helper" ]]; then
        # Remove binary
        local binary_path="$HOME/.local/share/bin/$current_helper"
        if [[ -f "$binary_path" ]]; then
            rm -f "$binary_path"
        fi
        
        # Remove from Docker config
        local docker_config="$HOME/.docker/config.json"
        if [[ -f "$docker_config" ]]; then
            jq --arg reg "$registry_url" 'del(.credHelpers[$reg])' "$docker_config" > "$docker_config.tmp" && mv "$docker_config.tmp" "$docker_config"
        fi
    fi
}

# Show credhelper config
show_credhelper_config() {
    echo ""
    echo "CredHelper config:"
    jq '.credHelpers // {}' ~/.docker/config.json 2>/dev/null || echo '{}'
}

# ECR profile setup helper
setup-ecr-profile() {
    local profile_name="$1"
    local registry_url="$2"
    
    # Validate inputs
    if [[ -z "$profile_name" || -z "$registry_url" ]]; then
        echo "Profile name and registry URL are required"
        return 1
    fi
    
    # Check if AWS profile exists
    if ! aws configure list-profiles | grep -q "^$profile_name$"; then
        echo "AWS profile '$profile_name' does not exist"
        return 1
    fi
    
    # Create binary name and path (no prefix)
    binary_name="$profile_name"
    binary_path="$HOME/.local/share/bin/$binary_name"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$binary_path")"
    
    # Create the profile-specific binary
    cat > "$binary_path" << 'EOF'
#!/bin/bash
exec smart-ecr-helper "$@"
EOF
    
    chmod +x "$binary_path"
    
    # Update Docker config
    docker_config="$HOME/.docker/config.json"
    if [[ ! -f "$docker_config" ]]; then
        mkdir -p "$(dirname "$docker_config")"
        echo '{"credHelpers": {}}' > "$docker_config"
    fi
    
    # Add registry to Docker config using jq
    if command -v jq >/dev/null 2>&1; then
        jq --arg url "$registry_url" --arg helper "$binary_name" \
           '.credHelpers[$url] = $helper' "$docker_config" > "$docker_config.tmp" && \
        mv "$docker_config.tmp" "$docker_config"
    else
        echo "jq not found. Please manually add to ~/.docker/config.json:"
        echo "  \"$registry_url\": \"$binary_name\""
    fi
}

# =============================================================================
# Test Functions
# =============================================================================

test_ecr_setup() {
    print_status "Testing ECR setup..."
    
    # Test smart-ecr-helper
    if [[ -f "$HOME/.local/share/bin/smart-ecr-helper" ]]; then
        print_success "smart-ecr-helper is installed"
    else
        print_error "smart-ecr-helper is not installed"
        return 1
    fi
    
    # Test docker-credential-helper-ecr (check both Homebrew and manual install)
    if command -v docker-credential-helper-ecr >/dev/null 2>&1; then
        print_success "docker-credential-helper-ecr is installed (via Homebrew)"
    elif [[ -f "$HOME/.local/share/bin/docker-credential-helper-ecr" ]]; then
        print_success "docker-credential-helper-ecr is installed (manual)"
    else
        print_error "docker-credential-helper-ecr is not installed"
        return 1
    fi
    
    # Test AWS CLI
    if aws --version >/dev/null 2>&1; then
        print_success "AWS CLI is working"
    else
        print_error "AWS CLI is not working"
        return 1
    fi
    
    # Test Docker
    if docker --version >/dev/null 2>&1; then
        print_success "Docker is working"
    else
        print_error "Docker is not working"
        return 1
    fi
    
    print_success "All components are ready for testing!"
}

# =============================================================================
# Main Installation Function
# =============================================================================

install_ecr_setup() {
    print_status "Installing ECR setup for testing..."
    
    check_dependencies
    install_smart_ecr_helper
    install_docker_ecr_helper
    test_ecr_setup
    
    echo ""
    print_success "ECR setup installation complete!"
    echo ""
    echo "Available functions:"
    echo "  - setup-ecr-profiles    # Main ECR management menu"
    echo "  - setup_new_ecr_profile # Add new ECR registry"
    echo "  - update_ecr_profile    # Update existing ECR profile"
    echo "  - remove_ecr_profile    # Remove ECR profile"
    echo "  - resync_ecr_profiles   # Resync ECR profiles"
    echo ""
    echo "To start using ECR management, run:"
    echo "  setup-ecr-profiles"
    echo ""
    print_warning "Make sure to source your shell config to update PATH:"
    print_warning "  source ~/.bashrc  # or source ~/.zshrc"
}

# =============================================================================
# Script Entry Point
# =============================================================================

main() {
    echo "============================================================================="
    echo "ECR Setup Test Script"
    echo "============================================================================="
    echo ""
    
    case "${1:-install}" in
        install)
            install_ecr_setup
            ;;
        test)
            test_ecr_setup
            ;;
        *)
            echo "Usage: $0 [install|test]"
            echo ""
            echo "Commands:"
            echo "  install  - Install ECR setup (default)"
            echo "  test     - Test existing ECR setup"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"