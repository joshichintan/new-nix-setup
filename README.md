# Nix Configuration

This repository contains configuration for personal machines running nix-darwin with standalone Home Manager support.

## Overview

This setup provides:
- **nix-darwin** for system configuration
- **Home Manager** in standalone mode for user configuration
- **nvf** for modern Neovim configuration
- **nix-homebrew** for package management

## Quick Start

### Prerequisites

- macOS with nix-darwin
- Nix with flakes enabled
- Git

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd new-nix-setup
   ```

2. **Apply system configuration:**
   ```bash
   # Build and switch to nix-darwin configuration
   nix run .#darwinConfigurations.chintan.system
   ```

3. **Apply Home Manager configuration:**
   ```bash
   # Apply user configuration (standalone)
   nix run .#homeConfigurations.nix-darwin@chintan.activationPackage
   ```

## Home Manager Standalone Mode

### What is Standalone Mode?

Standalone Home Manager allows you to manage your user configuration (dotfiles, Neovim, etc.) **independently** of your system configuration. This means:

- ✅ **Fast updates**: Only rebuild user config, not the whole system
- ✅ **Independent management**: Update dotfiles without touching system settings
- ✅ **Better separation**: System and user concerns are separate

### Quick Command Aliases

For easier usage, the following aliases are available:

#### Home Manager Commands
```bash
hm          # Apply Home Manager configuration
hm-build    # Build Home Manager configuration without applying
hm-check    # Check Home Manager configuration for errors
```

#### nix-darwin Commands
```bash
darwin      # Apply nix-darwin system configuration
darwin-build # Build nix-darwin configuration without applying
darwin-check # Check nix-darwin configuration for errors
```

#### Combined Commands
```bash
rebuild        # Rebuild both system and home configurations
rebuild-home   # Rebuild only home configuration
rebuild-system # Rebuild only system configuration
```

#### General Nix Commands
```bash
nix-update     # Update all flake inputs
nix-gc         # Garbage collect Nix store
nix-clean      # Clean old generations and garbage collect
```

### Available Home Manager Configurations

```bash
# List available configurations
nix flake show

# Available configurations:
# - nix-darwin@chintan (work user)
# - chintan@slartibartfast (personal user)
# - chintan@nauvis (personal user)
```

### How to Use

#### Apply Home Manager Configuration
```bash
# Apply configuration for work user
nix run .#homeConfigurations.nix-darwin@chintan.activationPackage

# Apply configuration for personal user
nix run .#homeConfigurations.chintan@slartibartfast.activationPackage
```

#### Build Without Applying
```bash
# Build configuration without activating
nix build .#homeConfigurations.nix-darwin@chintan.activationPackage

# Then activate manually
./result/activate
```

#### Check Configuration
```bash
# Check for errors without building
nix build .#homeConfigurations.nix-darwin@chintan.activationPackage --dry-run
```

### Configuration Files

- `home/nix-darwin.nix` - Work user configuration
- `home/chintan.nix` - Personal user configuration
- `home/nvim/` - Neovim configuration files
- `home/modules/` - Reusable Home Manager modules

## Features

### Neovim with nvf

Modern Neovim configuration using **nvf** (Neovim Flake):

- **Terminal detection**: Automatically adapts to Apple Terminal vs other terminals
- **Plugin management**: Declarative plugin configuration
- **Keymap management**: Structured keymap definitions
- **Colorscheme**: Automatic terminal-specific colorscheme selection

### nix-homebrew Integration

Standalone Homebrew management:

- **Declarative taps**: Homebrew repositories defined in Nix
- **Auto-updates**: Automatic cleanup and upgrades on activation
- **Rosetta support**: Intel app support on Apple Silicon
- **Package management**: Use `brew install` normally after setup

### Terminal Detection

Neovim automatically detects your terminal and applies appropriate settings:

- **Apple Terminal**: Light theme, no true colors
- **WezTerm/iTerm2**: Dark theme with full color support
- **Other terminals**: Default dark theme

## Development

### Adding New Packages

#### Nix Packages (via Home Manager)
```nix
# In home/nix-darwin.nix
{
  home.packages = with pkgs; [
    htop
    tree
    bat
    # Add more packages here
  ];
}
```

#### Homebrew Packages
```bash
# Install normally after nix-homebrew is set up
brew install package-name
brew install --cask app-name
```

### Updating Configuration

#### Update Flake Inputs
```bash
# Update all inputs to latest
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

#### Apply Changes
```bash
# Apply Home Manager changes (fast)
nix run .#homeConfigurations.nix-darwin@chintan.activationPackage

# Apply system changes (slower)
nix run .#darwinConfigurations.chintan.system
```

### Adding New Users

1. **Create user configuration:**
   ```nix
   # In flake.nix
   "newuser@hostname" = libx.mkHome {
     username = "newuser";
     homeDirectory = "/Users/newuser";
     modules = [ ./home/newuser.nix ];
   };
   ```

2. **Create home configuration file:**
   ```bash
   # Create home/newuser.nix
   touch home/newuser.nix
   ```

3. **Apply configuration:**
   ```bash
   nix run .#homeConfigurations.newuser@hostname.activationPackage
   ```

## Troubleshooting

### Common Issues

#### Home Manager Activation Fails
```bash
# Check for errors
nix build .#homeConfigurations.nix-darwin@chintan.activationPackage --show-trace

# Check configuration
nix eval .#homeConfigurations.nix-darwin@chintan.activationPackage
```

#### Neovim Issues
```bash
# Check nvf configuration
nvim --headless -c "checkhealth"

# Reset Neovim state
rm -rf ~/.local/share/nvim
rm -rf ~/.cache/nvim
```