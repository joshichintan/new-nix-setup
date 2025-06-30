#!/bin/bash

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
            mapfile -t LABELS < <(softwareupdate --list 2>/dev/null | \
                grep -E '^ *Command Line Tools for Xcode' | \
                sed -E 's/^ *//; s/ *$//' | \
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

# Function to install Nix
install_nix() {
    if command_exists nix; then
        print_success "Nix already installed"
        return 0
    fi
    
    if [[ $DRY_RUN != true ]]; then
        print_status "Installing Nix..."
        
        # Install Nix with official installer
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
        
        if [ $? -eq 0 ]; then
            print_success "Nix installed successfully"
            
            # Source nix environment
            if [ -f /etc/nix/nix.conf ]; then
                . /etc/nix/nix.conf
            fi
            
            # Enable flakes
            print_status "Enabling Nix flakes..."
            mkdir -p ~/.config/nix
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
            
            print_success "Nix flakes enabled"
        else
            print_error "Failed to install Nix"
            exit 1
        fi
    else
        print_dry_run "Would install Nix using official installer and enable flakes"
    fi
}

# Function to check if host configuration exists in hosts.nix
check_host_config_exists() {
    local hostname=$1
    if [[ -f hosts.nix ]]; then
        grep -q "\"$hostname\"" hosts.nix
    else
        false
    fi
}

# Function to add host configuration to hosts.nix
add_host_config() {
    local username=$1
    local hostname=$2
    
    if [[ $DRY_RUN != true ]]; then
        if [[ -f hosts.nix ]]; then
            # Add new host to existing hosts.nix
            sed -i.bak "/^}/i\\
  $hostname = {\\
    hostname = \"$hostname\";\\
    username = \"$username\";\\
  };
" hosts.nix
        else
            # Create new hosts.nix file
            cat > hosts.nix << EOF
# Host configurations
{
  $hostname = {
    hostname = "$hostname";
    username = "$username";
  };
}
EOF
        fi
    else
        print_dry_run "Would add host configuration for '$username@$hostname' to hosts.nix"
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
    
    print_status "Managing host configurations:"
    print_status "  Username: $username"
    print_status "  Hostname: $hostname"
    print_status "  System: $system"
    
    # Only manage hosts.nix, don't touch flake.nix
    if check_host_config_exists "$hostname"; then
        print_status "Host configuration for hostname '$hostname' already exists in hosts.nix, skipping..."
    else
        print_status "Adding new host configuration to hosts.nix..."
        if [[ $DRY_RUN != true ]]; then
            add_host_config "$username" "$hostname"
        else
            print_dry_run "Would add host configuration for '$username@$hostname' to hosts.nix"
        fi
    fi
    
    # Check if flake.nix exists and has the right structure
    if [[ -f flake.nix ]]; then
        if grep -q "import ./hosts.nix" flake.nix; then
            print_success "✓ flake.nix already imports hosts.nix correctly"
        else
            print_warning "flake.nix exists but doesn't import hosts.nix"
            print_status "You may need to update your flake.nix to use the modular approach:"
            print_status "  hosts = import ./hosts.nix;"
            print_status "  darwinConfigurations = builtins.mapAttrs (...) hosts;"
            print_status "  homeConfigurations = builtins.foldl' (...) hosts;"
        fi
    else
        print_warning "flake.nix not found"
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
        nix flake update
    else
        print_dry_run "Would run: nix flake update"
    fi
    
    print_status "2. Building darwin configuration..."
    if [[ $DRY_RUN != true ]]; then
        nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system
    else
        print_dry_run "Would run: nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
    fi
    
    print_status "3. Building home configuration..."
    if [[ $DRY_RUN != true ]]; then
        nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage
    else
        print_dry_run "Would run: nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
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
        
        generate_flake
        echo
        
        # Auto mode also asks about build commands
        print_status "Next steps:"
        print_status "  1. Run: nix flake update"
        print_status "  2. Run: nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
        print_status "  3. Run: nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
        echo
        
        read -p "Do you want to run these commands now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_build_commands
        else
            print_status "Commands not run. You can run them manually:"
            print_status "  nix flake update"
            print_status "  nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
            print_status "  nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
        fi
    fi
    
    print_success "Wizard completed successfully!"
}

# Run the wizard
main "$@" 
