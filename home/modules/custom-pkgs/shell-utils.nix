{ config, pkgs, ... }:
{
    # Create shell script with core utilities only
    home.file."${config.xdg.configHome}/zsh/shell-utils.sh".text = ''
    #!/bin/zsh
    
    # =============================================================================
    # CORE UTILITIES
    # =============================================================================
    
    hm() {
      USERNAME=$(whoami)
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"

      echo "» Activating Home Manager..."
      nix --extra-experimental-features 'nix-command flakes' run \
        "''${CONFIG_PATH}#homeConfigurations.\"''${USERNAME}@''${HOSTNAME}\".activationPackage"
      
      # Hand off cleanup to background at the end
      (nohup nix-collect-garbage -d > /dev/null 2>&1 &) 2>/dev/null
      
      echo "✓ Home Manager activated"
    }
    
    darwin() {
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"
      
      echo "» Activating Darwin..."
      sudo nix --extra-experimental-features 'nix-command flakes' run \
        'nix-darwin#darwin-rebuild' -- switch --flake "''${CONFIG_PATH}#''${HOSTNAME}"
      
      # Hand off cleanup to background at the end
      (nohup nix-collect-garbage -d > /dev/null 2>&1 &) 2>/dev/null
      
      echo "✓ Darwin activated"
    }
    
    reload() {
      source ~/.zshenv 2>/dev/null || true
      source "$ZDOTDIR/.zshrc" 2>/dev/null || true
    }
    
    # Functions are automatically available in zsh when sourced
  '';
}
