{ config, pkgs, ... }:
{
  # Create shell script with dev tools
  home.file."${config.xdg.configHome}/zsh/dev-tools.sh".text = ''
    #!/bin/zsh
    
    # =============================================================================
    # DEV TOOLS - GENERIC SSH KEY MANAGEMENT
    # =============================================================================
    
    # Generic SSH Setup Manager
    ssh-setup() {
      local command=''${1:-help}
      local name=''${2}
      local email=''${3}
      local host=''${4}
      local port=''${5:-443}
      local user=''${6}
      
      case "$command" in
        "create")
          echo "» Creating SSH key: $name"
          
          # Validate required parameters
          if [[ -z "$name" ]]; then
            echo "✗ Error: name is required"
            echo "Usage: ssh-setup create <name> <email> <host> [port] <user>"
            return 1
          fi
          
          if [[ -z "$host" ]]; then
            echo "✗ Error: host is required"
            echo "Usage: ssh-setup create <name> <email> <host> [port] <user>"
            return 1
          fi
          
          if [[ -z "$user" ]]; then
            echo "✗ Error: user is required"
            echo "Usage: ssh-setup create <name> <email> <host> [port] <user>"
            return 1
          fi
          
          # Check if key already exists
          if [[ -f ~/.ssh/id_ed25519_$name ]]; then
            echo "⚠ SSH key id_ed25519_$name already exists"
            echo "Use 'ssh-setup renew $name' to regenerate or 'ssh-setup delete $name' to remove"
            return 1
          fi
          
          # Generate SSH key (with or without email comment)
          if [[ -n "$email" ]]; then
            ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519_$name -N ""
          else
            ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_$name -N ""
          fi
          chmod 600 ~/.ssh/id_ed25519_$name
          chmod 644 ~/.ssh/id_ed25519_$name.pub
          
          # Add to SSH agent
          ssh-add ~/.ssh/id_ed25519_$name
          
          # Create SSH config directory
          mkdir -p ~/.ssh/config.d
          
          # Create generic SSH config
          cat > ~/.ssh/config.d/$name.conf << EOF
Host $name
  HostName $host
  Port $port
  User $user
  IdentityFile ~/.ssh/id_ed25519_$name
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF
          
          echo "✓ SSH key generated: id_ed25519_$name"
          echo "✓ SSH config created: ~/.ssh/config.d/$name.conf"
          echo "✓ Key added to SSH agent"
          echo ""
          echo "→ Public key:"
          cat ~/.ssh/id_ed25519_$name.pub
          echo ""
          echo "→ Usage: ssh -T $name"
          ;;
          
        "renew")
          echo "» Renewing SSH key: $name"
          
          if [[ ! -f ~/.ssh/id_ed25519_$name ]]; then
            echo "⚠ SSH key id_ed25519_$name does not exist"
            echo "Use 'ssh-setup create $name' to create it"
            return 1
          fi
          
          # Get email from existing key
          local email=$(ssh-keygen -l -f ~/.ssh/id_ed25519_$name 2>/dev/null | cut -d' ' -f3- || echo "")
          
          # Backup existing key
          cp ~/.ssh/id_ed25519_$name ~/.ssh/id_ed25519_$name.backup
          cp ~/.ssh/id_ed25519_$name.pub ~/.ssh/id_ed25519_$name.pub.backup
          
          # Remove from SSH agent
          ssh-add -d ~/.ssh/id_ed25519_$name 2> /dev/null || true
          
          # Generate new key
          ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519_$name -N ""
          chmod 600 ~/.ssh/id_ed25519_$name
          chmod 644 ~/.ssh/id_ed25519_$name.pub
          
          # Add to SSH agent
          ssh-add ~/.ssh/id_ed25519_$name
          
          echo "✓ SSH key renewed: id_ed25519_$name"
          echo "✓ Backup saved: id_ed25519_$name.backup"
          echo ""
          echo "→ New public key:"
          cat ~/.ssh/id_ed25519_$name.pub
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
            ssh-add -d ~/.ssh/id_ed25519_$name 2> /dev/null || true
            
            # Delete key files
            rm ~/.ssh/id_ed25519_$name
            rm ~/.ssh/id_ed25519_$name.pub
            
            # Remove SSH config
            if [[ -f ~/.ssh/config.d/$name.conf ]]; then
              rm ~/.ssh/config.d/$name.conf
            fi
            
            echo "✓ SSH key deleted: id_ed25519_$name"
            echo "✓ Removed SSH config"
          else
            echo "✗ Deletion cancelled"
          fi
          ;;
          
        "show")
          echo "» Public key for $name:"
          
          if [[ ! -f ~/.ssh/id_ed25519_$name.pub ]]; then
            echo "⚠ SSH key id_ed25519_$name does not exist"
            return 1
          fi
          
          cat ~/.ssh/id_ed25519_$name.pub
          ;;
          
        "test")
          echo "» Testing SSH connection: $name"
          
          if [[ ! -f ~/.ssh/config.d/$name.conf ]]; then
            echo "⚠ SSH config for $name does not exist"
            return 1
          fi
          
          # Extract host and port from config
          local host=$(grep "HostName" ~/.ssh/config.d/$name.conf | awk '{print $2}')
          local port=$(grep "Port" ~/.ssh/config.d/$name.conf | awk '{print $2}')
          local user=$(grep "User" ~/.ssh/config.d/$name.conf | awk '{print $2}')
          
          echo "Testing connection to $host:$port as $user..."
          
          if ssh -o ConnectTimeout=10 -o BatchMode=yes $name exit 2>/dev/null; then
            echo "✓ Connection successful"
          else
            echo "✗ Connection failed"
            echo "→ Check if the key is added to the remote server"
          fi
          ;;
          
        "ls"|"list")
          echo "» SSH keys:"
          local found=false
          for key_file in $(find ~/.ssh -name "id_ed25519_*" 2>/dev/null); do
            if [[ -f "$key_file" && ! "$key_file" =~ \.backup$ ]]; then
              found=true
              local key_name=$(basename "$key_file" | sed 's/id_ed25519_//')
              local email=$(ssh-keygen -l -f "$key_file" 2>/dev/null | cut -d' ' -f3- || echo "unknown")
              
              # Get host info from config
              local host_info=""
              if [[ -f ~/.ssh/config.d/$key_name.conf ]]; then
                local host=$(grep "HostName" ~/.ssh/config.d/$key_name.conf | awk '{print $2}')
                local port=$(grep "Port" ~/.ssh/config.d/$key_name.conf | awk '{print $2}')
                host_info=" ($host:$port)"
              fi
              
              # Check if loaded in SSH agent
              local loaded=""
              if ssh-add -l 2> /dev/null | grep -q "$key_file"; then
                loaded=" (loaded)"
              fi
              
              echo "  $key_name: $email$host_info$loaded"
            fi
          done
          if [[ "$found" == false ]]; then
            echo "  No SSH keys found"
          fi
          ;;
          
                "help"|*)
                  echo "Generic SSH Setup Manager"
                  echo ""
                  echo "Usage: ssh-setup <command> [name] [email] [host] [port] [user]"
                  echo ""
                  echo "Commands:"
                  echo "  create <name> [email] <host> [port] <user>  Create new SSH key"
                  echo "  renew [name]                               Renew SSH key, keep backup"
                  echo "  delete [name]                              Delete SSH key"
                  echo "  show [name]                                Show public key"
                  echo "  test [name]                                Test SSH connection"
                  echo "  ls                                        List all SSH keys"
                  echo "  help                                      Show this help"
                  echo ""
                  echo "Examples:"
                  echo "  ssh-setup create personal chintan@example.com github.com 443 git"
                  echo "  ssh-setup create work work@company.com gitlab.com 22 git"
                  echo "  ssh-setup create server admin@myserver.com 192.168.1.100 2222 admin"
                  echo "  ssh-setup show personal"
                  echo "  ssh-setup test personal"
                  echo "  ssh-setup ls"
                  echo ""
                  echo "Required for create:"
                  echo "  name: SSH key identifier (e.g., personal, work, server)"
                  echo "  host: Target hostname (e.g., github.com, gitlab.com)"
                  echo "  user: SSH username (e.g., git, admin, root)"
                  echo ""
                  echo "Optional:"
                  echo "  email: Email for key comment (if not provided, no comment is added)"
                  echo "  port: SSH port (default: 443)"
                  ;;
      esac
    }
  '';
}