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
    
    # Show usage information
    show_usage() {
      echo "Nix Manager - Manage your Nix configurations"
      echo ""
      echo "Usage: nix-mgr [OPTION]"
      echo ""
      echo "Options:"
      echo "  -h, --help              Show this help message"
      echo "  -i, --interactive       Run interactive menu (default)"
      echo ""
      echo "Home Manager commands:"
      echo "  hm                      Apply Home Manager configuration"
      echo "  hm-build                Build Home Manager configuration (dry run)"
      echo "  hm-check                Check Home Manager configuration for errors"
      echo ""
      echo "Darwin System commands:"
      echo "  darwin                  Rebuild Darwin system"
      echo "  darwin-build            Build Darwin system (dry run)"
      echo "  darwin-check            Check Darwin system for errors"
      echo ""
      echo "Combined commands:"
      echo "  rebuild                 Rebuild both Darwin system and Home Manager"
      echo "  rebuild-home            Rebuild Home Manager only"
      echo "  rebuild-system          Rebuild Darwin system only"
      echo ""
      echo "Examples:"
      echo "  nix-mgr hm              # Apply Home Manager configuration"
      echo "  nix-mgr darwin          # Rebuild Darwin system"
      echo "  nix-mgr rebuild         # Rebuild both"
      echo "  nix-mgr hm-check        # Check Home Manager for errors"
    }

    # Main Nix Manager Menu
    nix_manager() {
      # Handle command line arguments
      case "''${1:-}" in
        -h|--help)
          show_usage
          return 0
          ;;
        hm)
          echo "Rebuilding Home Manager..."
          rebuild-home
          return 0
          ;;
        hm-build)
          echo "Building Home Manager (dry run)..."
          hm-build
          return 0
          ;;
        hm-check)
          echo "Checking Home Manager..."
          hm-check
          return 0
          ;;
        darwin)
          echo "Rebuilding Darwin System..."
          rebuild-system
          return 0
          ;;
        darwin-build)
          echo "Building Darwin System (dry run)..."
          darwin-build
          return 0
          ;;
        darwin-check)
          echo "Checking Darwin System..."
          darwin-check
          return 0
          ;;
        rebuild)
          echo "Rebuilding Both Home Manager and Darwin System..."
          rebuild
          return 0
          ;;
        rebuild-home)
          echo "Rebuilding Home Manager..."
          rebuild-home
          return 0
          ;;
        rebuild-system)
          echo "Rebuilding Darwin System..."
          rebuild-system
          return 0
          ;;
        -i|--interactive|"")
          # Run interactive menu
          ;;
        *)
          echo "Unknown option: $1"
          echo ""
          show_usage
          return 1
          ;;
      esac

      # Interactive menu
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