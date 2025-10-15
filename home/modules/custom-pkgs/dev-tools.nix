{ config, pkgs, ... }:
{
  # Create shell script with dev tools using subcommands
  home.file."${config.xdg.configHome}/zsh/dev-tools.sh".text = ''
    #!/bin/bash
    
    # =============================================================================
    # DEV TOOLS - GIT SETUP
    # =============================================================================
    
    git-setup() {
      local command=''${1:-help}
      local name=''${2:-personal}
      
      case "$command" in
        "create")
          echo "» Creating git config: $name"
          
          # Check if config already exists
          if [[ -f ~/.config/git/config_$name ]]; then
            echo "⚠ Git config ~/.config/git/config_$name already exists"
            echo "Use 'git-setup update $name' to update or 'git-setup delete $name' to remove"
            return 1
          fi
          
          # Create ~/.config/git/ directory
          mkdir -p ~/.config/git
          
          # Get user input
          echo "Enter your full name:"
          read -r full_name
          echo "Enter your email:"
          read -r email
          
          # Create git config
          cat > ~/.config/git/config_$name << EOF
[user]
    name = $full_name
    email = $email
[init]
    defaultBranch = main
[pull]
    rebase = false
[core]
    editor = nvim
EOF
          
          echo "✓ Git config created: ~/.config/git/config_$name"
          echo "→ Use: git config --file ~/.config/git/config_$name"
          ;;
          
        "update")
          echo "» Updating git config: $name"
          
          if [[ ! -f ~/.config/git/config_$name ]]; then
            echo "⚠ Git config ~/.config/git/config_$name does not exist"
            echo "Use 'git-setup create $name' to create it"
            return 1
          fi
          
          # Get user input
          echo "Enter your full name:"
          read -r full_name
          echo "Enter your email:"
          read -r email
          
          # Update git config
          cat > ~/.config/git/config_$name << EOF
[user]
    name = $full_name
    email = $email
[init]
    defaultBranch = main
[pull]
    rebase = false
[core]
    editor = nvim
EOF
          
          echo "✓ Git config updated: ~/.config/git/config_$name"
          ;;
          
        "delete")
          echo "» Deleting git config: $name"
          
          if [[ ! -f ~/.config/git/config_$name ]]; then
            echo "⚠ Git config ~/.config/git/config_$name does not exist"
            return 1
          fi
          
          echo "Are you sure you want to delete ~/.config/git/config_$name? (y/N)"
          read -r confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm ~/.config/git/config_$name
            echo "✓ Git config deleted: ~/.config/git/config_$name"
          else
            echo "✗ Deletion cancelled"
          fi
          ;;
          
        "ls"|"list")
          echo "» Git configurations:"
          if [[ -d ~/.config/git ]]; then
            for config_file in ~/.config/git/config_*; do
              if [[ -f "$config_file" ]]; then
                local name=$(basename "$config_file" | sed 's/config_//')
                local name_val=$(grep 'name =' "$config_file" | cut -d'=' -f2 | tr -d ' ')
                local email_val=$(grep 'email =' "$config_file" | cut -d'=' -f2 | tr -d ' ')
                echo "  $name: $name_val <$email_val>"
              fi
            done
          else
            echo "  No git configurations found"
          fi
          ;;
          
        "help"|*)
          echo "Git Setup Manager"
          echo ""
          echo "Usage: git-setup <command> [name]"
          echo ""
          echo "Commands:"
          echo "  create [name]  Create new git config (default: personal)"
          echo "  update [name]  Update existing git config (default: personal)"
          echo "  delete [name]  Delete git config (default: personal)"
          echo "  ls            List all git configs"
          echo "  help          Show this help"
          echo ""
          echo "Examples:"
          echo "  git-setup create personal"
          echo "  git-setup update work"
          echo "  git-setup delete custom"
          echo "  git-setup ls"
          ;;
      esac
    }
    
    # =============================================================================
    # DEV TOOLS - SSH SETUP
    # =============================================================================
    
    ssh-setup() {
      local command=''${1:-help}
      local name=''${2:-personal}
      
      case "$command" in
        "create")
          echo "» Creating SSH key: $name"
          
          # Check if key already exists
          if [[ -f ~/.ssh/id_ed25519_$name ]]; then
            echo "⚠ SSH key id_ed25519_$name already exists"
            echo "Use 'ssh-setup renew $name' to regenerate or 'ssh-setup delete $name' to remove"
            return 1
          fi
          
          # Generate SSH key
          ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-$name" -f ~/.ssh/id_ed25519_$name -N ""
          
          # Set proper permissions
          chmod 600 ~/.ssh/id_ed25519_$name
          chmod 644 ~/.ssh/id_ed25519_$name.pub
          
          # Add to SSH agent
          ssh-add ~/.ssh/id_ed25519_$name
          
          # Update SSH config
          if [[ ! -f ~/.ssh/config ]]; then
            touch ~/.ssh/config
            chmod 600 ~/.ssh/config
          fi
          
          # Add host mapping to SSH config
          cat >> ~/.ssh/config << EOF

Host github-$name
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_$name
EOF
          
          echo "✓ SSH key generated: id_ed25519_$name"
          echo "✓ SSH config updated for github-$name"
          echo "→ Public key:"
          cat ~/.ssh/id_ed25519_$name.pub
          echo ""
          echo "→ Add this key to GitHub: https://github.com/settings/keys"
          ;;
          
        "renew")
          echo "» Renewing SSH key: $name"
          
          if [[ ! -f ~/.ssh/id_ed25519_$name ]]; then
            echo "⚠ SSH key id_ed25519_$name does not exist"
            echo "Use 'ssh-setup create $name' to create it"
            return 1
          fi
          
          # Backup existing key
          cp ~/.ssh/id_ed25519_$name ~/.ssh/id_ed25519_$name.backup
          cp ~/.ssh/id_ed25519_$name.pub ~/.ssh/id_ed25519_$name.pub.backup
          
          # Remove from SSH agent
          ssh-add -d ~/.ssh/id_ed25519_$name 2>/dev/null || true
          
          # Generate new key
          ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-$name" -f ~/.ssh/id_ed25519_$name -N ""
          
          # Set proper permissions
          chmod 600 ~/.ssh/id_ed25519_$name
          chmod 644 ~/.ssh/id_ed25519_$name.pub
          
          # Add to SSH agent
          ssh-add ~/.ssh/id_ed25519_$name
          
          echo "✓ SSH key renewed: id_ed25519_$name"
          echo "✓ Backup saved: id_ed25519_$name.backup"
          echo "→ New public key:"
          cat ~/.ssh/id_ed25519_$name.pub
          echo ""
          echo "→ Update this key in GitHub: https://github.com/settings/keys"
          ;;
          
        "delete")
          echo "» Deleting SSH key: $name"
          
          if [[ ! -f ~/.ssh/id_ed25519_$name ]]; then
            echo "⚠ SSH key id_ed25519_$name does not exist"
            return 1
          fi
          
          echo "Are you sure you want to delete id_ed25519_$name? (y/N)"
          read -r confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Remove from SSH agent
            ssh-add -d ~/.ssh/id_ed25519_$name 2>/dev/null || true
            
            # Delete key files
            rm ~/.ssh/id_ed25519_$name
            rm ~/.ssh/id_ed25519_$name.pub
            
            # Remove from SSH config
            if [[ -f ~/.ssh/config ]]; then
              sed -i '' "/Host github-$name/,/^$/d" ~/.ssh/config
            fi
            
            echo "✓ SSH key deleted: id_ed25519_$name"
            echo "✓ Removed from SSH config"
          else
            echo "✗ Deletion cancelled"
          fi
          ;;
          
        "ls"|"list")
          echo "» SSH keys:"
          for key_file in ~/.ssh/id_ed25519_*; do
            if [[ -f "$key_file" && ! "$key_file" =~ \.backup$ ]]; then
              local name=$(basename "$key_file" | sed 's/id_ed25519_//')
              local email=$(ssh-keygen -l -f "$key_file" 2>/dev/null | cut -d' ' -f3- || echo "unknown")
              local loaded=""
              if ssh-add -l 2>/dev/null | grep -q "$key_file"; then
                loaded=" (loaded)"
              fi
              echo "  $name: $email$loaded"
            fi
          done
          ;;
          
        "help"|*)
          echo "SSH Setup Manager"
          echo ""
          echo "Usage: ssh-setup <command> [name]"
          echo ""
          echo "Commands:"
          echo "  create [name]  Create new SSH key (default: personal)"
          echo "  renew [name]   Renew SSH key, keep backup (default: personal)"
          echo "  delete [name]  Delete SSH key (default: personal)"
          echo "  ls            List all SSH keys"
          echo "  help          Show this help"
          echo ""
          echo "Examples:"
          echo "  ssh-setup create personal"
          echo "  ssh-setup renew work"
          echo "  ssh-setup delete custom"
          echo "  ssh-setup ls"
          ;;
      esac
    }
    
    # Export functions for zsh
    export -f git-setup ssh-setup
  '';
}
