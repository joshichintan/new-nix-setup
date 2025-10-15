{ config, pkgs, ... }:
{
  # Create shell script with core utilities only
  home.file."${config.xdg.configHome}/zsh/shell-utils.sh".text = ''
    #!/bin/bash
    
    # =============================================================================
    # CORE UTILITIES
    # =============================================================================
    
    hm() {
      echo "» Running garbage collection..."
      nix-collect-garbage

      USERNAME=$(whoami)
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"

      echo "» Activating Home Manager via activationPackage..."
      nix --extra-experimental-features 'nix-command flakes' run \
        "''${CONFIG_PATH}#homeConfigurations.''${USERNAME}@''${HOSTNAME}.activationPackage"
    }
    
    darwin() {
      echo "» Running garbage collection..."
      nix-collect-garbage
      
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"
      
      sudo nix --extra-experimental-features 'nix-command flakes' run \
        'nix-darwin#darwin-rebuild' -- switch --flake "''${CONFIG_PATH}#''${HOSTNAME}"
    }
    
    reload() {
      source ~/.zshenv 2>/dev/null || true
      source "$ZDOTDIR/.zshrc" 2>/dev/null || true
    }
    
    nix-gc() {
      nix-collect-garbage
    }
    
    nix-clean() {
      nix-collect-garbage -d
    }
    
    # Export functions for zsh
    export -f hm darwin reload nix-gc nix-clean
  '';
}
