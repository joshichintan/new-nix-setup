#!/bin/bash

# Initialize DRY_RUN variable
DRY_RUN=false

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
        # Install without popups using AppleScript
        print_status "Installing Xcode Command Line Tools (this may take a while)..."
        
        # Trigger installation
        xcode-select --install
        
        # Wait for installation to complete
        local timeout=600  # 10 minutes
        local elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            if xcode-select -p >/dev/null 2>&1; then
                print_success "Xcode Command Line Tools installed successfully"
                return 0
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            print_status "Waiting for installation to complete... ($elapsed seconds elapsed)"
        done
        
        print_error "Xcode Command Line Tools installation timed out"
        exit 1
    else
        print_dry_run "Would install Xcode Command Line Tools and wait for completion"
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
        sh <(curl -L https://nixos.org/nix/install) --daemon
        
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

# Function to generate flake.nix
generate_flake() {
    local username=$(whoami)
    local hostname=$(hostname | cut -d'.' -f1)
    local system=$(detect_architecture)
    
    print_status "Generating flake.nix with:"
    print_status "  Username: $username"
    print_status "  Hostname: $hostname"
    print_status "  System: $system"
    
    if [[ -f flake.nix ]]; then
        print_status "flake.nix exists, checking for existing configuration..."
        
        # Check if darwinConfigurations already exists for this hostname
        if grep -A 10 "darwinConfigurations = {" flake.nix | grep -q "$hostname ="; then
            print_status "Darwin configuration for hostname '$hostname' already exists, skipping..."
        else
            print_status "Adding new darwinConfigurations entry..."
            if [[ $DRY_RUN != true ]]; then
                # Add new entry inside darwinConfigurations block
                sed -i.bak "/darwinConfigurations = {/a\\
        $hostname = libx.mkDarwin {\\
          hostname = \"$hostname\";\\
          username = \"$username\";\\
        };
" flake.nix
            else
                print_dry_run "Would add darwinConfigurations entry for hostname '$hostname'"
            fi
        fi
        
        # Check if homeConfigurations already exists for this username@hostname
        if grep -A 10 "homeConfigurations = {" flake.nix | grep -q "\"$username@$hostname\""; then
            print_status "Home Manager configuration for '$username@$hostname' already exists, skipping..."
        else
            print_status "Adding new homeConfigurations entry..."
            if [[ $DRY_RUN != true ]]; then
                # Add new entry inside homeConfigurations block
                sed -i.bak "/homeConfigurations = {/a\\
        \"$username@$hostname\" = libx.mkHome {\\
          username = \"$username\";\\
        };
" flake.nix
            else
                print_dry_run "Would add homeConfigurations entry for '$username@$hostname'"
            fi
        fi
        
        print_success "Configuration check completed"

    else
        print_status "Creating new flake.nix..."
        if [[ $DRY_RUN != true ]]; then
            cat > flake.nix << EOF
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
    in {
      darwinConfigurations = {
        $hostname = libx.mkDarwin {
          hostname = "$hostname";
          username = "$username";
        };
      };

      homeConfigurations = {
        "$username@$hostname" = libx.mkHome {
          username = "$username";
        };
      };
    };
}
EOF      
        else
            print_dry_run "Would create new flake.nix with username='$username', hostname='$hostname', system='$system'"
        fi
        print_success "flake.nix created successfully"
    fi
}

# Main wizard function
main() {
    print_status "Nix Setup Wizard Starting..."
    print_status "Checking system and running all necessary installations..."
    
    # Always go through all installation steps
    # Each function will check if already installed and skip if needed
    
    print_status "1. Checking/Installing Xcode Command Line Tools..."
    install_xcode_tools
    
    print_status "2. Checking/Installing Rosetta 2..."
    install_rosetta
    
    print_status "3. Checking/Installing Nix..."
    install_nix
    
    print_status "4. Generating/Updating flake.nix..."
    generate_flake
    
    print_success "Setup completed!"
    print_status "Next steps:"
    print_status "  1. Run: nix flake update"
    print_status "  2. Run: nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
    print_status "  3. Run: nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
    
    echo
    read -p "Do you want to run these commands now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Running commands..."
        
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
    else
        print_status "Commands not run. You can run them manually:"
        print_status "  nix flake update"
        print_status "  nix run .#darwinConfigurations.$(hostname | cut -d'.' -f1).system"
        print_status "  nix run .#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage"
    fi
    
    print_success "Wizard completed successfully!"
}

# Run the wizard
main "$@" 