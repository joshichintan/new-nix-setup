{ config, pkgs, ... }:
let
  # Shell Utils Script
  shellUtilsScript = pkgs.writeShellScriptBin "shell-utils" ''
    #!/bin/bash
    set -euo pipefail
    
    # Shell Utility Functions
    
    reload-shell() {
      echo "» Reloading shell configuration"
      source ~/.zshenv 2>/dev/null || true
      source "$ZDOTDIR/.zshrc" 2>/dev/null || true
      echo "✓ Configuration reloaded"
    }
    
    # Main Shell Utils Menu
    shell_utils() {
      while true; do
        echo ""
        echo "Shell Utilities"
        echo "==============="
        echo "1) Reload Shell Configuration"
        echo "2) Exit"
        echo ""
        read -p "Select option (1-2): " choice
        
        case $choice in
            1)
                reload-shell
                ;;
            2)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
      done
    }
    
    # Execute the utils
    shell_utils "$@"
  '';

in
{
  home.packages = [
    shellUtilsScript
  ];

  # Shell aliases for easy access
  programs.zsh.shellAliases = {
    shell-utils = "shell-utils";
    reload = "reload-shell";
  };
}
