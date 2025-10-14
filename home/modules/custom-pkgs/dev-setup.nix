{ config, pkgs, ... }:
let
  # Development Setup Script
  devSetupScript = pkgs.writeShellScriptBin "dev-setup" ''
    #!/bin/bash
    set -euo pipefail
    
    # Input validation functions
    validate_email() {
        local email="$1"
        if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            echo "Invalid email format" >&2
            return 1
        fi
    }
    
    validate_username() {
        local username="$1"
        if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            echo "Invalid username. Only alphanumeric characters, dots, hyphens, and underscores allowed" >&2
            return 1
        fi
    }
    
    sanitize_input() {
        local input="$1"
        # Remove any potentially dangerous characters
        echo "$input" | tr -d ';|&$`"'"'"'\\'
    }
    
    # Development Environment Setup Functions
    
    generate-ssh-key() {
      echo "» SSH Key Generation"
      
      if [[ ! -t 0 ]]; then
        echo "✗ This function requires an interactive shell"
        echo "  Please run this function directly in your terminal"
        return 1
      fi
      
      if [ -f ~/.ssh/id_ed25519 ]; then
        echo "! SSH key already exists: ~/.ssh/id_ed25519"
        echo "1. Keep existing key"
        echo "2. Replace with new key (backup old)"
        echo "3. Show existing key"
        
        choice=""
        vared -p "Choose option (1-3): " choice
        
        case $choice in
          1)
            echo "• Keeping existing key"
            cat ~/.ssh/id_ed25519.pub
            return 0
            ;;
          2)
            echo "→ Replacing existing key..."
            # Backup old key
            cp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup.$(date +%Y%m%d_%H%M%S)
            cp ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub.backup.$(date +%Y%m%d_%H%M%S)
            ;;
          3)
            echo "→ Existing public key:"
            cat ~/.ssh/id_ed25519.pub
            return 0
            ;;
          *)
            echo "✗ Invalid option"
            return 1
            ;;
        esac
      fi
      
      # Prompt for email
      email=""
      while true; do
        vared -p "Enter your email address: " email
        if [ -z "$email" ]; then
          echo "✗ Email is required"
          continue
        fi
        
        if ! validate_email "$email"; then
          continue
        fi
        
        break
      done
      
      # Generate key
      mkdir -p ~/.ssh
      chmod 700 ~/.ssh
      ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
      chmod 600 ~/.ssh/id_ed25519
      chmod 644 ~/.ssh/id_ed25519.pub
      
      # Add to SSH agent
      eval "$(ssh-agent -s)"
      ssh-add ~/.ssh/id_ed25519
      
      echo "✓ SSH key generated for: $email"
      echo "→ Public key:"
      cat ~/.ssh/id_ed25519.pub
      echo ""
      echo "→ Add this key to GitHub: https://github.com/settings/keys"
    }
    
    setup-git-ssh() {
      echo "» Git Configuration"
      
      # Check if we're in an interactive shell
      if [[ ! -t 0 ]]; then
        echo "✗ This function requires an interactive shell"
        echo "  Please run this function directly in your terminal"
        return 1
      fi
      
      # Check existing configuration
      existing_name=$(git config --global user.name 2>/dev/null)
      existing_email=$(git config --global user.email 2>/dev/null)
      
      if [ -n "$existing_name" ] || [ -n "$existing_email" ]; then
        echo "! Git is already configured:"
        echo "  Name: $existing_name"
        echo "  Email: $existing_email"
        echo ""
        echo "1. Keep existing configuration"
        echo "2. Replace with new configuration"
        echo "3. Update specific values"
        
        choice=""
        vared -p "Choose option (1-3): " choice
        
        case $choice in
          1)
            echo "• Keeping existing configuration"
            return 0
            ;;
          2)
            echo "→ Replacing configuration..."
            ;;
          3)
            echo "→ Updating specific values..."
            ;;
          *)
            echo "✗ Invalid option"
            return 1
            ;;
        esac
      fi
      
      # Get name
      name=""
      if [ "$choice" = "3" ] && [ -n "$existing_name" ]; then
        vared -p "Enter your Git username [$existing_name]: " name
        name="''${name:-$existing_name}"
      else
        while true; do
          vared -p "Enter your Git username: " name
          if [ -z "$name" ]; then
            echo "✗ Username is required"
            continue
          fi
          
          # Sanitize and validate input
          name=$(sanitize_input "$name")
          if ! validate_username "$name"; then
            continue
          fi
          break
        done
      fi
      
      # Get email
      email=""
      if [ "$choice" = "3" ] && [ -n "$existing_email" ]; then
        vared -p "Enter your Git email [$existing_email]: " email
        email="''${email:-$existing_email}"
      else
        while true; do
          vared -p "Enter your Git email: " email
          if [ -z "$email" ]; then
            echo "✗ Email is required"
            continue
          fi
          
          # Sanitize and validate input
          email=$(sanitize_input "$email")
          if ! validate_email "$email"; then
            continue
          fi
          
          break
        done
      fi
      
      # Configure Git
      git config --global user.name "$name"
      git config --global user.email "$email"
      git config --global init.defaultBranch main
      git config --global pull.rebase false
      
      echo "✓ Git configured for: $name <$email>"
    }
    
    setup-dev-environment() {
      echo "» Development Environment Setup"
      
      # SSH Key setup
      generate-ssh-key
      
      echo ""
      echo "→ Waiting for you to add the SSH key to GitHub..."
      dummy=""
      vared -p "Press Enter after adding the key to GitHub... " dummy
      
      # Test GitHub connection
      echo "→ Testing GitHub connection..."
      if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "✓ GitHub connection successful"
      else
        echo "✗ GitHub connection failed"
        return 1
      fi
      
      # Git setup
      setup-git-ssh
      
      echo "✓ Development environment setup complete"
    }
    
    # Main Dev Setup Menu
    dev_setup() {
      while true; do
        echo ""
        echo "Development Environment Setup"
        echo "============================="
        echo "1) Generate SSH Key"
        echo "2) Setup Git Configuration"
        echo "3) Complete Dev Environment Setup"
        echo "4) Exit"
        echo ""
        read -p "Select option (1-4): " choice
        
        case $choice in
            1)
                generate-ssh-key
                ;;
            2)
                setup-git-ssh
                ;;
            3)
                setup-dev-environment
                ;;
            4)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
      done
    }
    
    # Execute the setup
    dev_setup "$@"
  '';

in
{
  home.packages = [
    devSetupScript
  ];

  # Shell aliases for easy access
  programs.zsh.shellAliases = {
    dev-setup = "dev-setup";
  };
}
