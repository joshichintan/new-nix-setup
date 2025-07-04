#!/bin/bash

# Nix Setup Wizard
# This script should be run with bash for best compatibility
# Usage: bash wizard.sh [--dry-run]

# Initialize variables
DRY_RUN=false
SKIP_INSTALL=false
INTERACTIVE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
done

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

print_dry_run() {
    echo -e "${YELLOW}[DRY RUN]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect system architecture
detect_architecture() {
    if [[ $(uname -m) == "arm64" ]]; then
        echo "aarch64-darwin"
    else
        echo "x86_64-darwin"
    fi
}

# Function to install Xcode Command Line Tools
install_xcode_tools() {
    print_status "Installing Xcode Command Line Tools..."
    
    # Define temp file path
    XCLT_TMP="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    
    # Function to cleanup temp file
    cleanup_temp_file() {
        if [ -f "$XCLT_TMP" ]; then
            sudo rm -f "$XCLT_TMP"
        fi
    }
    
    # Ensure cleanup on exit
    trap cleanup_temp_file EXIT
    
    if ! command_exists xcode-select; then
        print_error "Xcode Command Line Tools not found. Please install Xcode first."
        exit 1
    fi
    
    # Check if already installed
    if xcode-select -p >/dev/null 2>&1; then
        print_success "Xcode Command Line Tools already installed"
        return 0
    fi
    
    if [[ $DRY_RUN != true ]]; then
        print_status "Installing Xcode Command Line Tools (this may take a while)..."
        
        # Step 1: Create the temp file to trigger Command Line Tools listing
        sudo touch "$XCLT_TMP"
        
        # Step 2: Wait for Command Line Tools label to appear (timeout after 60s)
        TIMEOUT=60
        INTERVAL=3
        elapsed=0
        while true; do
            # Use POSIX-compatible array building instead of mapfile
            LABELS=()
            while IFS= read -r line; do
                LABELS+=("$line")
            done < <(softwareupdate --list 2>/dev/null | \
                grep -E 'Label: Command Line Tools for Xcode' | \
                sed -E 's/^.*Label: *//; s/^ *//; s/ *$//' | \
                sort -V)
            if [ ${#LABELS[@]} -gt 0 ]; then
                break
            fi
            if [ $elapsed -ge $TIMEOUT ]; then
                print_error "Timed out waiting for Command Line Tools to appear in softwareupdate list."
                exit 1
            fi
            sleep $INTERVAL
            elapsed=$((elapsed + INTERVAL))
        done
        
        echo "Available Command Line Tools versions:"
        for i in "${!LABELS[@]}"; do
            printf "  [%d] %s\n" "$((i+1))" "${LABELS[$i]}"
        done
        
        read -p "Enter the number of the version to install [${#LABELS[@]}]: " CHOICE
        if [[ -z "$CHOICE" ]]; then
            CHOICE=${#LABELS[@]}  # Default to the latest
        fi
        
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#LABELS[@]} )); then
            print_error "Invalid selection."
            exit 1
        fi
        
        LABEL="${LABELS[$((CHOICE-1))]}"
        print_status "Installing: $LABEL"
        sudo softwareupdate --install "$LABEL"
        
        # Verify installation
        if xcode-select -p >/dev/null 2>&1; then
            print_success "Xcode Command Line Tools installed successfully"
        else
            print_error "Xcode Command Line Tools installation failed"
            exit 1
        fi
    else
        print_dry_run "Would install Xcode Command Line Tools using softwareupdate"
    fi
}

# Function to install Rosetta 2
install_rosetta() {
    local arch=$(uname -m)
    
    if [[ $arch == "arm64" ]]; then
        print_status "Detected Apple Silicon Mac, installing Rosetta 2..."
        
        if /usr/bin/pgrep -q oahd; then
            print_success "Rosetta 2 already installed"
            return 0
        fi
        
        if [[ $DRY_RUN != true ]]; then
            print_status "Installing Rosetta 2..."
            /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            
            if [ $? -eq 0 ]; then
                print_success "Rosetta 2 installed successfully"
            else
                print_error "Failed to install Rosetta 2"
                exit 1
            fi
        else
            print_dry_run "Would install Rosetta 2 using softwareupdate --install-rosetta --agree-to-license"
        fi
    else
        print_status "Intel Mac detected, Rosetta 2 not needed"
    fi
}

# Function to check if NIX_USER_CONFIG_PATH is set and valid
check_existing_config() {
    if [[ -n "$NIX_USER_CONFIG_PATH" ]]; then
        print_status "Found existing NIX_USER_CONFIG_PATH: $NIX_USER_CONFIG_PATH"
        
        if [[ -d "$NIX_USER_CONFIG_PATH" ]] && [[ -f "$NIX_USER_CONFIG_PATH/flake.nix" ]]; then
            print_success "Valid Nix configuration found at: $NIX_USER_CONFIG_PATH"
            
            echo
            print_status "Existing configuration detected:"
            echo "  [1] Use existing config (change to directory)"
            echo "  [N] Install new config (clone a new repo)"
            echo
            read -p "Enter 1 to use existing config or N for new config [1]: " REPLY
            echo
            
            if [[ -z "$REPLY" || "$REPLY" == "1" ]]; then
                print_status "Using existing configuration..."
                print_success "Configuration ready at: $NIX_USER_CONFIG_PATH"
                return 0
            elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
                print_status "User chose to install a new config."
                return 1
            else
                print_error "Invalid selection"
                return 1
            fi
        else
            print_warning "NIX_USER_CONFIG_PATH is set but directory is invalid or missing flake.nix"
            print_status "Will proceed with new configuration setup"
            return 1
        fi
    fi
    
    return 1
}

# Function to clone git repository
clone_repo() {
    local default_repo="https://github.com/joshichintan/new-nix-setup.git"
    local repo_url=""
    local config_dir="$HOME/.config"
    local repo_dir="$config_dir/nix-config"
    
    print_status "Setting up git repository..."
    
    # First, check if we have an existing config
    if check_existing_config; then
        print_success "Repository directory is ready"
        return 0
    fi
    
    # Ask user for repository URL
    echo
    print_status "Repository setup:"
    echo "  1) Use default repository: $default_repo"
    echo "  2) Enter custom repository URL"
    echo "  3) Skip repository setup"
    echo
    read -p "Enter your choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            repo_url="$default_repo"
            ;;
        2)
            read -p "Enter repository URL: " repo_url
            if [[ -z "$repo_url" ]]; then
                print_error "Repository URL cannot be empty"
                return 1
            fi
            ;;
        3)
            print_status "Skipping repository setup"
            return 0
            ;;
        *)
            print_error "Invalid choice. Using default repository."
            repo_url="$default_repo"
            ;;
    esac
    
    if [[ $DRY_RUN != true ]]; then
        print_status "Setting up repository in: $repo_dir"
        print_status "Note: Repository will be cloned to 'nix-config' directory to match NIX_USER_CONFIG_PATH"
        
        # Create .config directory if it doesn't exist
        if [[ ! -d "$config_dir" ]]; then
            print_status "Creating .config directory..."
            mkdir -p "$config_dir"
        fi
        
        # If the target directory exists, back it up before cloning
        if [[ -d "$repo_dir" ]]; then
            local bak_dir="${repo_dir}-bak"
            local bak_index=1
            while [[ -d "$bak_dir" ]]; do
                bak_dir="${repo_dir}-bak-$bak_index"
                bak_index=$((bak_index + 1))
            done
            print_status "Backing up existing directory: $repo_dir -> $bak_dir"
            mv "$repo_dir" "$bak_dir"
        fi
        
        # Clone the repository into .config/nix-config directory
        print_status "Cloning repository: $repo_url"
        if git clone "$repo_url" "$repo_dir"; then
            print_success "Repository cloned successfully"
            print_success "Repository ready at: $repo_dir"
        else
            print_error "Failed to clone repository"
            return 1
        fi
    else
        print_dry_run "Would create .config directory if needed"
        print_dry_run "Would back up $repo_dir to $repo_dir-bak (or -bak-N if needed) if it exists"
        print_dry_run "Would clone repository: $repo_url"
        print_dry_run "Would clone into: $repo_dir (always 'nix-config' directory)"
    fi
    
    # Update NIX_USER_CONFIG_PATH after successful clone
    if [[ $DRY_RUN != true ]] && [[ -d "$repo_dir" ]]; then
        update_nix_config_path "$repo_dir"
    fi
}

# Function to update NIX_USER_CONFIG_PATH in nix.conf
update_nix_config_path() {
    local new_config_path="$1"
    
    # Set the environment variable for the current session
    export NIX_USER_CONFIG_PATH="$new_config_path"
    
    print_status "Repository cloned to: $new_config_path"
    print_success "NIX_USER_CONFIG_PATH is set to: $new_config_path"
    print_status "Note: Environment variable is managed by Home Manager in home/home.nix"
    print_status "You can rebuild your home configuration to apply changes:"
    print_status "  hm"
}

# Function to install Nix
install_nix() {
    
    if [[ $DRY_RUN != true ]]; then
        # Check if Nix is already installed
        if command_exists nix; then
            print_success "Nix already installed"
        else
            print_status "Installing Nix..."
            
            # Install Nix with official installer
            sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
            
            if [ $? -eq 0 ]; then
                print_success "Nix installed successfully"
            else
                print_error "Failed to install Nix"
                exit 1
            fi
        fi
            
        # Source Nix environment for current session
        print_status "Setting up Nix environment..."
        
        # Source the Nix environment
        if [ -f ~/.nix-profile/etc/profile.d/nix.sh ]; then
            # Direct Nix profile
            . ~/.nix-profile/etc/profile.d/nix.sh
        elif [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        
        # Also try to source from common locations
        if [ -f /etc/profile.d/nix.sh ]; then
            . /etc/profile.d/nix.sh
        fi
        
        # Enable flakes
        print_status "Enabling Nix flakes..."
        mkdir -p ~/.config/nix
        
        # Check if experimental features are already configured
        if [[ -f ~/.config/nix/nix.conf ]] && grep -q "experimental-features = nix-command flakes" ~/.config/nix/nix.conf; then
            print_success "Nix flakes already enabled"
        else
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
            print_success "Nix flakes enabled"
        fi
        
        # Verify Nix is available
        if command_exists nix; then
            print_success "Nix command is available"
        else
            print_warning "Nix command not found in PATH, you may need to restart your terminal"
            print_status "You can also run: source ~/.nix-profile/etc/profile.d/nix.sh"
        fi

    else
        if command_exists nix; then
            print_dry_run "Would check Nix installation (already installed)"
        else
            print_dry_run "Would install Nix using official installer and enable flakes"
        fi
    fi
}

# Function to check if host configuration exists in hosts.nix
check_host_config_exists() {
    local hostname=$1
    local config_dir="${2:-.}"
    if [[ -f "$config_dir/hosts.nix" ]]; then
        # Check if hostname exists as a proper host configuration entry
        # Look for pattern: hostname = { ... hostname = "hostname" ... }
        grep -A 5 -B 5 "\"$hostname\"" "$config_dir/hosts.nix" | grep -q "hostname = \"$hostname\""
    else
        false
    fi
}

# Function to add host configuration to hosts.nix
add_host_config() {
    local username=$1
    local hostname=$2
    local config_dir="${3:-.}"
    
    # Check if host configuration already exists
    if check_host_config_exists "$hostname" "$config_dir"; then
        print_warning "Host configuration for '$hostname' already exists in $config_dir/hosts.nix, skipping..."
        return 0
    fi
    
    if [[ $DRY_RUN != true ]]; then
        if [[ -f "$config_dir/hosts.nix" ]]; then
            # Add new host to existing hosts.nix
            sed -i.bak "/^}/i\\
  $hostname = {\\
    hostname = \"$hostname\";\\
    username = \"$username\";\\
  };" "$config_dir/hosts.nix"
            print_success "Added host configuration for '$username@$hostname' to $config_dir/hosts.nix"
        else
            # Create new hosts.nix file
            cat > "$config_dir/hosts.nix" << EOF
# Host configurations
{
  $hostname = {
    hostname = "$hostname";
    username = "$username";
  };
}
EOF
            print_success "Created $config_dir/hosts.nix with host configuration for '$username@$hostname'"
        fi
    else
        print_dry_run "Would add host configuration for '$username@$hostname' to $config_dir/hosts.nix"
    fi
}

# Function to show flake.nix boilerplate
show_flake_boilerplate() {
    print_status "Here's a suggested boilerplate for your flake.nix:"
    echo
    print_status "Create flake.nix with this structure:"
    cat << 'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    alejandra = {
      url = "github:kamadorueda/alejandra/4.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {...} @ inputs:
    with inputs; let
      inherit (self) outputs;

      stateVersion = "24.05";
      libx = import ./lib {inherit inputs outputs stateVersion;};
      
      # Import host configurations
      hosts = import ./hosts.nix;
    in {
      darwinConfigurations = builtins.mapAttrs (name: config: 
        libx.mkDarwin {
          hostname = config.hostname;
          username = config.username;
        }
      ) hosts;

      # Standalone Home Manager configurations
      homeConfigurations = builtins.foldl' (acc: host: 
        acc // {
          "${host.username}@${host.hostname}" = libx.mkHome {
            username = host.username;
          };
        }
      ) {} (builtins.attrValues hosts);
    };
}
EOF
    echo
    print_status "You can customize the inputs section according to your needs."
}

# Function to generate flake.nix
generate_flake() {
    local username=$(whoami)
    local hostname=$(hostname | cut -d'.' -f1)
    local system=$(detect_architecture)
    local config_dir="${NIX_USER_CONFIG_PATH:-.}"
    
    print_status "Managing host configurations:"
    print_status "  Username: $username"
    print_status "  Hostname: $hostname"
    print_status "  System: $system"
    print_status "  Config directory: $config_dir"
    
    # Only manage hosts.nix, don't touch flake.nix
    print_status "Managing host configuration in hosts.nix..."
    if [[ $DRY_RUN != true ]]; then
        add_host_config "$username" "$hostname" "$config_dir"
    else
        print_dry_run "Would add host configuration for '$username@$hostname' to $config_dir/hosts.nix"
    fi
    
    # Check if flake.nix exists and has the right structure
    if [[ -f "$config_dir/flake.nix" ]]; then
        if grep -q "import ./hosts.nix" "$config_dir/flake.nix"; then
            print_success "✓ flake.nix already imports hosts.nix correctly"
        else
            print_warning "flake.nix exists but doesn't import hosts.nix"
            print_status "You may need to update your flake.nix to use the modular approach:"
            print_status "  hosts = import ./hosts.nix;"
            print_status "  darwinConfigurations = builtins.mapAttrs (...) hosts;"
            print_status "  homeConfigurations = builtins.foldl' (...) hosts;"
        fi
    else
        print_warning "flake.nix not found in $config_dir"
        print_status "Here's a suggested boilerplate for your flake.nix:"
        echo
        show_flake_boilerplate
    fi
    
    print_success "Host configuration management completed"
}

# Function to run build commands
run_build_commands() {
    print_status "Running build commands..."
    
    print_status "1. Updating flake..."
    if [[ $DRY_RUN != true ]]; then
        nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}
    else
        print_dry_run "Would run: nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}"
    fi
    
    print_status "2. Building darwin configuration..."
    if [[ $DRY_RUN != true ]]; then
        sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)
    else
        print_dry_run "Would run: sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)"
    fi
    
    print_status "3. Building home configuration..."
    if [[ $DRY_RUN != true ]]; then
        nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage
    else
        print_dry_run "Would run: nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
    fi
    
    if [[ $DRY_RUN != true ]]; then
        print_success "All commands completed!"
    else
        print_dry_run "Would complete all build commands"
    fi
}

# Function to ask user for installation preference
ask_installation_preference() {
    echo
    print_status "What would you like to do?"
    echo "  1) Install everything automatically (recommended)"
    echo "  2) Interactive mode (ask at each step)"
    echo
    read -p "Enter your choice (1-2): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            DRY_RUN=false
            SKIP_INSTALL=false
            INTERACTIVE=false
            print_success "Proceeding with automatic installation"
            ;;
        2)
            INTERACTIVE=true
            print_status "Interactive mode enabled - you'll be asked at each step"
            ;;
        *)
            print_error "Invalid choice. Please run the wizard again."
            exit 1
            ;;
    esac
}

# Function to ask user for step preference
ask_step_preference() {
    local step_name=$1
    local step_description=$2
    
    echo
    print_status "About to: $step_description"
    echo "  1) Install/Skip (auto-detect if already installed)"
    echo "  2) Skip this step"
    echo "  3) Dry run (show what would be done)"
    echo
    read -p "Enter your choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            DRY_RUN=false
            SKIP_INSTALL=false
            print_status "Proceeding with $step_name"
            ;;
        2)
            DRY_RUN=false
            SKIP_INSTALL=true
            print_status "Skipping $step_name"
            ;;
        3)
            DRY_RUN=true
            SKIP_INSTALL=false
            print_warning "DRY RUN for $step_name"
            ;;
        *)
            print_error "Invalid choice. Skipping $step_name"
            DRY_RUN=false
            SKIP_INSTALL=true
            ;;
    esac
}

# Main wizard function
main() {
    print_status "Nix Setup Wizard Starting..."
    print_status "Checking system and running all necessary installations..."

    # Housekeeping: Ask about hostname
    local current_hostname=$(scutil --get LocalHostName 2>/dev/null || hostname | cut -d'.' -f1)
    echo
    print_status "Current system hostname: $current_hostname"
    read -p "Do you want to change the hostname? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new hostname: " new_hostname
        if [[ -n "$new_hostname" ]]; then
            if [[ $DRY_RUN == true ]]; then
                print_dry_run "Would run: sudo scutil --set LocalHostName $new_hostname"
            else
                print_status "Setting new hostname to: $new_hostname"
                sudo scutil --set LocalHostName "$new_hostname"
                print_success "Hostname set to: $new_hostname"
            fi
        else
            print_warning "No hostname entered. Keeping existing hostname: $current_hostname"
        fi
    else
        print_status "Keeping existing hostname: $current_hostname"
    fi

    # Ask user for installation preference
    ask_installation_preference
    
    # Always go through all installation steps
    # Each function will check if already installed and skip if needed
    
    if [[ $INTERACTIVE == true ]]; then
        # Interactive mode - ask at each step
        ask_step_preference "Xcode Command Line Tools" "check and install Xcode Command Line Tools"
        if [[ $SKIP_INSTALL != true ]]; then
            install_xcode_tools
        fi
        echo
        
        ask_step_preference "Rosetta 2" "check and install Rosetta 2 (if needed)"
        if [[ $SKIP_INSTALL != true ]]; then
            install_rosetta
        fi
        echo
        
        ask_step_preference "Nix" "check and install Nix with flakes"
        if [[ $SKIP_INSTALL != true ]]; then
            install_nix
        fi
        echo
        
        ask_step_preference "Git Repository" "clone git repository"
        if [[ $SKIP_INSTALL != true ]]; then
            clone_repo
        fi
        echo
        
        ask_step_preference "flake.nix" "generate or update flake.nix configuration"
        if [[ $SKIP_INSTALL != true ]]; then
            generate_flake
        fi
        echo
        
        ask_step_preference "build commands" "run nix build commands (flake update, darwin build, home build)"
        if [[ $SKIP_INSTALL != true ]]; then
            run_build_commands
        fi
        echo
    else
        # Auto mode - install everything
        install_xcode_tools
        echo
        
        install_rosetta
        echo
        
        install_nix
        echo
        
        clone_repo
        echo
        
        generate_flake
        echo
        
        # Auto mode also asks about build commands
        print_status "Next steps:"
        print_status "  1. Run: nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}"
        print_status "  2. Run: sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)"
        print_status "  3. Run: nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
        echo
        
        read -p "Do you want to run these commands now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_build_commands
        else
            print_status "Commands not run. You can run them manually:"
            print_status "  nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}"
            print_status "  sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)"
            print_status "  nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
        fi
    fi
    
    print_success "Wizard completed successfully!"
}

# Run the wizard
main "$@" 
