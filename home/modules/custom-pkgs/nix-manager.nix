{ config, pkgs, ... }:
let
  # Nix Management Script
  nixManagerScript = pkgs.writeShellScriptBin "nix-manager" ''
    #!/bin/bash
    set -euo pipefail
    
    # Nix Management Functions
    
    # Home Manager
    hm() {
      nix --extra-experimental-features 'nix-command flakes' run "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
    }

    hm-build() {
      nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage"
    }

    hm-check() {
      nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\"$(whoami)@$(scutil --get LocalHostName)\".activationPackage" --dry-run
    }

    # nix-darwin
    darwin() {
      sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-rebuild' -- switch --flake "''${NIX_USER_CONFIG_PATH:-.}#$(scutil --get LocalHostName)"
    }

    darwin-build() {
      nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system"
    }

    darwin-check() {
      nix --extra-experimental-features 'nix-command flakes' build "''${NIX_USER_CONFIG_PATH:-.}#darwinConfigurations.$(scutil --get LocalHostName).system" --dry-run
    }

    # Combined rebuilds
    rebuild() {
      darwin && hm
    }
    
    rebuild-home() {
      hm
    }
    
    rebuild-system() {
      darwin
    }
    
    # Main Nix Manager Menu
    nix_manager() {
      while true; do
        echo ""
        echo "Nix Management"
        echo "=============="
        echo "1) Rebuild Home Manager"
        echo "2) Rebuild Darwin System"
        echo "3) Rebuild Both (Home + System)"
        echo "4) Build Home Manager (dry run)"
        echo "5) Build Darwin System (dry run)"
        echo "6) Check Home Manager"
        echo "7) Check Darwin System"
        echo "8) Exit"
        echo ""
        read -p "Select option (1-8): " choice
        
        case $choice in
            1)
                echo "Rebuilding Home Manager..."
                rebuild-home
                ;;
            2)
                echo "Rebuilding Darwin System..."
                rebuild-system
                ;;
            3)
                echo "Rebuilding Both Home Manager and Darwin System..."
                rebuild
                ;;
            4)
                echo "Building Home Manager (dry run)..."
                hm-build
                ;;
            5)
                echo "Building Darwin System (dry run)..."
                darwin-build
                ;;
            6)
                echo "Checking Home Manager..."
                hm-check
                ;;
            7)
                echo "Checking Darwin System..."
                darwin-check
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
      done
    }
    
    # Execute the manager
    nix_manager "$@"
  '';

in
{
  home.packages = [
    nixManagerScript
  ];

  # Shell aliases for easy access
  programs.zsh.shellAliases = {
    nix-mgr = "nix-manager";
  };
}
