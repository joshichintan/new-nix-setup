#!/bin/bash

# Nix Setup Wizard
# This script should be run with bash for best compatibility
# Usage: bash wizard.sh [--dry-run]

# Initialize variables
DRY_RUN=false
SKIP_INSTALL=false
INTERACTIVE=false

# Global array to store warnings/errors for the current step
wizard_log=()

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
    echo -ne "${BLUE}[INFO]${NC} $1\r\033[K"
    sleep 0.1
}

print_success() {
    echo -ne "${GREEN}[SUCCESS]${NC} $1\r\033[K"
    sleep 0.1
}

print_dry_run() {
    echo -ne "${YELLOW}[DRY RUN]${NC} $1\r\033[K"
    sleep 0.1
}

# Record cursor position and print step label with gray circle
wizard_step_begin() {
    local num="$1"
    local label="$2"
    # Clear wizard_log array
    wizard_log=()
    # Print the label with a gray circle
    local CIRCLE="\033[1;30m●${NC}"
    printf " %s. %-30s %b\n" "$num" "$label" "$CIRCLE"
}

# Update label with status, print warnings/errors
wizard_step_end() {
    local num="$1"
    local label="$2"
    local status="$3" # ok, fail, skip, warn
    
    local symbol=""
    case "$status" in
        ok)   symbol="${GREEN}✓${NC}";;
        fail) symbol="${RED}✗${NC}";;
        skip) symbol="${YELLOW}–${NC}";;
        warn) symbol="${YELLOW}!${NC}";;
    esac
    
    # Move cursor up to the step label line and update it
    echo -ne "\033[A\r"
    printf " %s. %-30s %b" "$num" "$label" "$symbol"
    
    # Print all warnings/errors if any
    if [ ${#wizard_log[@]} -gt 0 ]; then
        echo
        for msg in "${wizard_log[@]}"; do
            echo -ne "    $msg\n"
        done
    else
        echo
    fi
}

# Modified print_warning and print_error to append to wizard_log
print_warning() {
    local msg="${YELLOW}[WARNING]${NC} $1"
    echo -ne "$msg\n"
    wizard_log+=("$msg")
}

print_error() {
    local msg="${RED}[ERROR]${NC} $1"
    echo -ne "$msg\n"
    wizard_log+=("$msg")
}

# For prompts: after reading input, clear the prompt block
clear_prompt_block() {
    local lines=$1
    for ((i=0; i<lines; i++)); do
        echo -ne "\033[A\r\033[K"
    done
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
    echo "${BLUE}Installing Xcode Command Line Tools...${NC}"
    
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
        echo "${GREEN}Xcode Command Line Tools already installed${NC}"
        return 0
    fi
    
    if [[ $DRY_RUN != true ]]; then
        echo "${BLUE}Installing Xcode Command Line Tools (this may take a while)...${NC}"
        
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
        clear_prompt_block 2
        if [[ -z "$CHOICE" ]]; then
            CHOICE=${#LABELS[@]}  # Default to the latest
        fi
        
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#LABELS[@]} )); then
            print_error "Invalid selection."
            exit 1
        fi
        
        LABEL="${LABELS[$((CHOICE-1))]}"
        echo "${BLUE}Installing: $LABEL${NC}"
        sudo softwareupdate --install "$LABEL"
        
        # Verify installation
        if xcode-select -p >/dev/null 2>&1; then
            echo "${GREEN}Xcode Command Line Tools installed successfully${NC}"
        else
            print_error "Xcode Command Line Tools installation failed"
            exit 1
        fi
    else
        echo "${YELLOW}Would install Xcode Command Line Tools using softwareupdate${NC}"
    fi
}

# Function to install Rosetta 2
install_rosetta() {
    local arch=$(uname -m)
    
    if [[ $arch == "arm64" ]]; then
        echo "${BLUE}Detected Apple Silicon Mac, installing Rosetta 2...${NC}"
        
        if /usr/bin/pgrep -q oahd; then
            echo "${GREEN}Rosetta 2 already installed${NC}"
            return 0
        fi
        
        if [[ $DRY_RUN != true ]]; then
            echo "${BLUE}Installing Rosetta 2...${NC}"
            /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            
            if [ $? -eq 0 ]; then
                echo "${GREEN}Rosetta 2 installed successfully${NC}"
            else
                print_error "Failed to install Rosetta 2"
                exit 1
            fi
        else
            echo "${YELLOW}Would install Rosetta 2 using softwareupdate --install-rosetta --agree-to-license${NC}"
        fi
    else
        echo "${BLUE}Intel Mac detected, Rosetta 2 not needed${NC}"
    fi
}

# Function to check if NIX_USER_CONFIG_PATH is set and valid
check_existing_config() {
    if [[ -n "$NIX_USER_CONFIG_PATH" ]]; then
        echo "${BLUE}Found existing NIX_USER_CONFIG_PATH: $NIX_USER_CONFIG_PATH${NC}"
        
        if [[ -d "$NIX_USER_CONFIG_PATH" ]] && [[ -f "$NIX_USER_CONFIG_PATH/flake.nix" ]]; then
            echo "${GREEN}Valid Nix configuration found at: $NIX_USER_CONFIG_PATH${NC}"
            
            echo
            echo "${BLUE}Existing configuration detected:${NC}"
            echo "  1) Use existing config (change to directory)"
            echo "  2) Install new config (clone a new repo)"
            echo
            read -p "Enter 1 to use existing config or N for new config [1]: " REPLY
            clear_prompt_block 6
            echo
            
            if [[ -z "$REPLY" || "$REPLY" == "1" ]]; then
                echo "${BLUE}Using existing configuration...${NC}"
                echo "${GREEN}Configuration ready at: $NIX_USER_CONFIG_PATH${NC}"
                return 0
            elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
                echo "${BLUE}User chose to install a new config.${NC}"
                return 1
            else
                print_error "Invalid selection"
                return 1
            fi
        else
            print_warning "NIX_USER_CONFIG_PATH is set but directory is invalid or missing flake.nix"
            echo "${BLUE}Will proceed with new configuration setup${NC}"
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
    
    echo "${BLUE}Setting up git repository...${NC}"
    
    # First, check if we have an existing config
    if check_existing_config; then
        echo "${GREEN}Repository directory is ready${NC}"
        return 0
    fi
    
    # Ask user for repository URL
    echo
    echo "${BLUE}Repository setup:${NC}"
    echo "  1) Use default repository: $default_repo"
    echo "  2) Enter custom repository URL"
    echo "  3) Skip repository setup"
    echo
    read -p "Enter your choice (1-3): " -n 1 -r
    clear_prompt_block 6
    
    case $REPLY in
        1)
            repo_url="$default_repo"
            ;;
        2)
            read -p "Enter repository URL: " repo_url
            clear_prompt_block 1
            if [[ -z "$repo_url" ]]; then
                print_error "Repository URL cannot be empty"
                return 1
            fi
            ;;
        3)
            echo "${BLUE}Skipping repository setup${NC}"
            return 0
            ;;
        *)
            print_error "Invalid choice. Using default repository."
            repo_url="$default_repo"
            ;;
    esac
    
    if [[ $DRY_RUN != true ]]; then
        echo "${BLUE}Setting up repository in: $repo_dir${NC}"
        echo "${BLUE}Note: Repository will be cloned to 'nix-config' directory to match NIX_USER_CONFIG_PATH${NC}"
        
        # Create .config directory if it doesn't exist
        if [[ ! -d "$config_dir" ]]; then
            echo "${BLUE}Creating .config directory...${NC}"
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
            echo "${BLUE}Backing up existing directory: $repo_dir -> $bak_dir${NC}"
            mv "$repo_dir" "$bak_dir"
        fi
        
        # Clone the repository into .config/nix-config directory
        echo "${BLUE}Cloning repository: $repo_url${NC}"
        if git clone "$repo_url" "$repo_dir"; then
            echo "${GREEN}Repository cloned successfully${NC}"
            echo "${GREEN}Repository ready at: $repo_dir${NC}"
        else
            print_error "Failed to clone repository"
            return 1
        fi
    else
        echo "${YELLOW}Would create .config directory if needed${NC}"
        echo "${YELLOW}Would back up $repo_dir to $repo_dir-bak (or -bak-N if needed) if it exists${NC}"
        echo "${YELLOW}Would clone repository: $repo_url${NC}"
        echo "${YELLOW}Would clone into: $repo_dir (always 'nix-config' directory)${NC}"
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
    
    echo "${BLUE}Repository cloned to: $new_config_path${NC}"
    echo "${GREEN}NIX_USER_CONFIG_PATH is set to: $new_config_path${NC}"
    echo "${BLUE}Note: Environment variable is managed by Home Manager in home/home.nix${NC}"
    echo "${BLUE}You can rebuild your home configuration to apply changes:${NC}"
    echo "${BLUE}  hm${NC}"
}

# Function to install Nix
install_nix() {
    
    if [[ $DRY_RUN != true ]]; then
        # Check if Nix is already installed
        if command_exists nix; then
            echo "${GREEN}Nix already installed${NC}"
        else
            echo "${BLUE}Installing Nix...${NC}"
            
            # Install Nix with official installer
            sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
            
            if [ $? -eq 0 ]; then
                echo "${GREEN}Nix installed successfully${NC}"
            else
                print_error "Failed to install Nix"
                exit 1
            fi
        fi
            
        # Source Nix environment for current session
        echo "${BLUE}Setting up Nix environment...${NC}"
        
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
        echo "${BLUE}Enabling Nix flakes...${NC}"
        mkdir -p ~/.config/nix
        
        # Check if experimental features are already configured
        if [[ -f ~/.config/nix/nix.conf ]] && grep -q "experimental-features = nix-command flakes" ~/.config/nix/nix.conf; then
            echo "${GREEN}Nix flakes already enabled${NC}"
        else
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
            echo "${GREEN}Nix flakes enabled${NC}"
        fi
        
        # Verify Nix is available
        if command_exists nix; then
            echo "${GREEN}Nix command is available${NC}"
        else
            print_warning "Nix command not found in PATH, you may need to restart your terminal"
            echo "${BLUE}You can also run: source ~/.nix-profile/etc/profile.d/nix.sh${NC}"
        fi

    else
        if command_exists nix; then
            echo "${YELLOW}Would check Nix installation (already installed)${NC}"
        else
            echo "${YELLOW}Would install Nix using official installer and enable flakes${NC}"
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
            echo "${GREEN}Added host configuration for '$username@$hostname' to $config_dir/hosts.nix${NC}"
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
            echo "${GREEN}Created $config_dir/hosts.nix with host configuration for '$username@$hostname'${NC}"
        fi
    else
        echo "${YELLOW}Would add host configuration for '$username@$hostname' to $config_dir/hosts.nix${NC}"
    fi
}

# Function to show flake.nix boilerplate
show_flake_boilerplate() {
    echo "${BLUE}Here's a suggested boilerplate for your flake.nix:${NC}"
    echo
    echo "${BLUE}Create flake.nix with this structure:${NC}"
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
    echo "${BLUE}You can customize the inputs section according to your needs.${NC}"
}

# Function to generate flake.nix
generate_flake() {
    local username=$(whoami)
    local hostname=$(hostname | cut -d'.' -f1)
    local system=$(detect_architecture)
    local config_dir="${NIX_USER_CONFIG_PATH:-.}"
    
    echo "${BLUE}Managing host configurations:${NC}"
    echo "${BLUE}  Username: $username${NC}"
    echo "${BLUE}  Hostname: $hostname${NC}"
    echo "${BLUE}  System: $system${NC}"
    echo "${BLUE}  Config directory: $config_dir${NC}"
    
    # Only manage hosts.nix, don't touch flake.nix
    echo "${BLUE}Managing host configuration in hosts.nix...${NC}"
    if [[ $DRY_RUN != true ]]; then
        add_host_config "$username" "$hostname" "$config_dir"
    else
        echo "${YELLOW}Would add host configuration for '$username@$hostname' to $config_dir/hosts.nix${NC}"
    fi
    
    # Check if flake.nix exists and has the right structure
    if [[ -f "$config_dir/flake.nix" ]]; then
        if grep -q "import ./hosts.nix" "$config_dir/flake.nix"; then
            echo "${GREEN}✓ flake.nix already imports hosts.nix correctly${NC}"
        else
            print_warning "flake.nix exists but doesn't import hosts.nix"
            echo "${BLUE}You may need to update your flake.nix to use the modular approach:${NC}"
            echo "${BLUE}  hosts = import ./hosts.nix;${NC}"
            echo "${BLUE}  darwinConfigurations = builtins.mapAttrs (...) hosts;${NC}"
            echo "${BLUE}  homeConfigurations = builtins.foldl' (...) hosts;${NC}"
        fi
    else
        print_warning "flake.nix not found in $config_dir"
        echo "${BLUE}Here's a suggested boilerplate for your flake.nix:${NC}"
        echo
        show_flake_boilerplate
    fi
    
    echo "${GREEN}Host configuration management completed${NC}"
}

# Function to run build commands
run_build_commands() {
    echo "${BLUE}Running build commands...${NC}"
    
    echo "${BLUE}1. Updating flake...${NC}"
    if [[ $DRY_RUN != true ]]; then
        nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}
    else
        echo "${YELLOW}Would run: nix flake update --flake ${NIX_USER_CONFIG_PATH:-.}${NC}"
    fi
    
    echo "${BLUE}2. Building darwin configuration...${NC}"
    if [[ $DRY_RUN != true ]]; then
        sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)
    else
        echo "${YELLOW}Would run: sudo nix run nix-darwin#darwin-rebuild -- switch --flake ${NIX_USER_CONFIG_PATH:-.}#$(hostname | cut -d'.' -f1)${NC}"
    fi
    
    echo "${BLUE}3. Building home configuration...${NC}"
    if [[ $DRY_RUN != true ]]; then
        nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage
    else
        echo "${YELLOW}Would run: nix run ${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.$(whoami)@$(hostname | cut -d'.' -f1).activationPackage${NC}"
    fi
    
    if [[ $DRY_RUN != true ]]; then
        echo "${GREEN}All commands completed!${NC}"
    else
        echo "${YELLOW}Would complete all build commands${NC}"
    fi
}

# Function to ask user for installation preference
ask_installation_preference() {
    echo
    echo "${BLUE}What would you like to do?${NC}"
    echo "  1) Install everything automatically (recommended)"
    echo "  2) Interactive mode (ask at each step)"
    echo
    read -p "Enter your choice (1-2): " -n 1 -r
    clear_prompt_block 5
    
    case $REPLY in
        1)
            DRY_RUN=false
            SKIP_INSTALL=false
            INTERACTIVE=false
            echo "${GREEN}Proceeding with automatic installation${NC}"
            ;;
        2)
            INTERACTIVE=true
            echo "${BLUE}Interactive mode enabled - you'll be asked at each step${NC}"
            ;;
        *)
            echo "${RED}Invalid choice. Please run the wizard again.${NC}"
            exit 1
            ;;
    esac
}

# Function to ask user for step preference
ask_step_preference() {
    local step_name=$1
    local step_description=$2
    
    echo
    echo "${BLUE}About to: $step_description${NC}"
    echo "  1) Install/Skip (auto-detect if already installed)"
    echo "  2) Skip this step"
    echo "  3) Dry run (show what would be done)"
    echo
    read -p "Enter your choice (1-3): " -n 1 -r
    clear_prompt_block 7
    
    case $REPLY in
        1)
            DRY_RUN=false
            SKIP_INSTALL=false
            echo "${BLUE}Proceeding with $step_name${NC}"
            ;;
        2)
            DRY_RUN=false
            SKIP_INSTALL=true
            echo "${BLUE}Skipping $step_name${NC}"
            ;;
        3)
            DRY_RUN=true
            SKIP_INSTALL=false
            echo "${YELLOW}DRY RUN for $step_name${NC}"
            ;;
        *)
            echo "${RED}Invalid choice. Skipping $step_name${NC}"
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
        echo "${BLUE}Keeping existing hostname: $current_hostname${NC}"
    fi

    # Ask user for installation preference
    ask_installation_preference

    step_num=1
    wizard_step_begin $step_num "Install Xcode Command Line Tools"
    ask_step_preference "Xcode Command Line Tools" "check and install Xcode Command Line Tools"
    local xcode_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! install_xcode_tools; then
            xcode_status="fail"
        fi
    else
        xcode_status="skip"
    fi
    wizard_step_end $step_num "Install Xcode Command Line Tools" $xcode_status

    step_num=2
    wizard_step_begin $step_num "Install Rosetta 2"
    ask_step_preference "Rosetta 2" "check and install Rosetta 2 (if needed)"
    local rosetta_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! install_rosetta; then
            rosetta_status="fail"
        fi
    else
        rosetta_status="skip"
    fi
    wizard_step_end $step_num "Install Rosetta 2" $rosetta_status

    step_num=3
    wizard_step_begin $step_num "Install Nix"
    ask_step_preference "Nix" "check and install Nix with flakes"
    local nix_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! install_nix; then
            nix_status="fail"
        fi
    else
        nix_status="skip"
    fi
    wizard_step_end $step_num "Install Nix" $nix_status

    step_num=4
    wizard_step_begin $step_num "Clone Git Repository"
    ask_step_preference "Git Repository" "clone git repository"
    local repo_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! clone_repo; then
            repo_status="fail"
        fi
    else
        repo_status="skip"
    fi
    wizard_step_end $step_num "Clone Git Repository" $repo_status

    step_num=5
    wizard_step_begin $step_num "Generate flake.nix"
    ask_step_preference "flake.nix" "generate or update flake.nix configuration"
    local flake_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! generate_flake; then
            flake_status="fail"
        fi
    else
        flake_status="skip"
    fi
    wizard_step_end $step_num "Generate flake.nix" $flake_status

    step_num=6
    wizard_step_begin $step_num "Run build commands"
    ask_step_preference "build commands" "run nix build commands (flake update, darwin build, home build)"
    local build_status="ok"
    if [[ $SKIP_INSTALL != true ]]; then
        if ! run_build_commands; then
            build_status="fail"
        fi
    else
        build_status="skip"
    fi
    wizard_step_end $step_num "Run build commands" $build_status

    echo
    echo "${GREEN}Wizard completed successfully!${NC}"
}

# Run the wizard
main "$@" 
