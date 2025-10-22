{ pkgs, lib, ... }:

{
  programs.zsh.initContent = ''
    # Home Manager Activation Script
    hm() {
      USERNAME=$(whoami)
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"

      echo "» Activating Home Manager..."
      if nix --extra-experimental-features 'nix-command flakes' run \
        "''${CONFIG_PATH}#homeConfigurations.\"''${USERNAME}@''${HOSTNAME}\".activationPackage"; then
        # Basic cleanup - keeps generations for rollback safety
        (nohup nix-collect-garbage > /dev/null 2>&1 &) 2>/dev/null
        echo "✓ Home Manager activated"
      else
        echo "✗ Home Manager activation failed"
        return 1
      fi
    }

    # Darwin System Activation Script
    darwin() {
      USERNAME=$(whoami)
      HOSTNAME=$(scutil --get LocalHostName | sed 's/\.local$//')
      CONFIG_PATH="''${NIX_USER_CONFIG_PATH:-.}"

      echo "» Activating Darwin system..."
      if sudo nix run nix-darwin#darwin-rebuild -- switch --flake "''${CONFIG_PATH}#''${HOSTNAME}"; then
        # Basic cleanup - keeps generations for rollback safety
        (nohup nix-collect-garbage > /dev/null 2>&1 &) 2>/dev/null
        echo "✓ Darwin system activated"
      else
        echo "✗ Darwin activation failed"
        return 1
      fi
    }

    # Shell Configuration Reload Script
    reload() {
      source ~/.zshenv 2>/dev/null || true
      source "$ZDOTDIR/.zshrc" 2>/dev/null || true
    }

    # Mise Auto-activation and Installation Script
    mise_precmd() {
      # Skip first run to avoid p10k instant prompt interference
      if [[ -z "$POWERLEVEL9K_INSTANT_PROMPT_THEME_STYLED" ]]; then
        return 0
      fi
      
      # Install missing tools and display if installed
      if mise ls --current --json 2>/dev/null | grep -q '"installed": false'; then
        echo "» Installing missing tools..."
        mise install
      fi
    }
    add-zsh-hook precmd mise_precmd
  '';
}
