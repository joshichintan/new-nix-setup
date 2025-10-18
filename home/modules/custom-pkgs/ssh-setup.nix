{ config, pkgs, ... }:
let
  # SSH Setup Utility
  sshSetupScript = pkgs.writeShellScriptBin "ssh-setup" ''
    #!/bin/bash
    set -euo pipefail
    
    # SSH Setup Utility - Generic SSH Key Management
    # Usage: ssh-setup <command> [name] [email] [host] [port] [user]
    
    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    
    # Helper functions
    log_info() {
        echo -e "''${BLUE}»''${NC} $1"
    }
    
    log_success() {
        echo -e "''${GREEN}✓''${NC} $1"
    }
    
    log_warning() {
        echo -e "''${YELLOW}⚠''${NC} $1"
    }
    
    log_error() {
        echo -e "''${RED}✗''${NC} $1" >&2
    }
    
    # Input validation functions
    validate_name() {
        local name="$1"
        if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            log_error "Invalid name. Only alphanumeric characters, hyphens, and underscores allowed"
            return 1
        fi
    }
    
    validate_host() {
        local host="$1"
        if [[ -z "$host" ]]; then
            log_error "Host is required"
            return 1
        fi
    }
    
    validate_user() {
        local user="$1"
        if [[ -z "$user" ]]; then
            log_error "User is required"
            return 1
        fi
    }
    
    # Add SSH key
    add_key() {
        local name="''${1:-}"
        local email="''${2:-}"
        local host="''${3:-}"
        local port="''${4:-443}"
        local user="''${5:-}"
        
        log_info "Creating SSH key: $name"
        
        # Validate required parameters
        validate_name "$name" || return 1
        validate_host "$host" || return 1
        validate_user "$user" || return 1
        
        # Check if key already exists
        if [[ -f "$HOME/.ssh/id_ed25519_$name" ]]; then
            log_warning "SSH key id_ed25519_$name already exists"
            echo "Use 'ssh-setup update $name' to regenerate or 'ssh-setup delete $name' to remove"
            return 1
        fi
        
        # Generate SSH key (with or without email comment)
        if [[ -n "$email" ]]; then
            ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519_$name" -N ""
        else
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_$name" -N ""
        fi
        chmod 600 "$HOME/.ssh/id_ed25519_$name"
        chmod 644 "$HOME/.ssh/id_ed25519_$name.pub"
        
        # Add to SSH agent
        ssh-add "$HOME/.ssh/id_ed25519_$name" 2>/dev/null || true
        
        # Create SSH config directory
        mkdir -p "$HOME/.ssh/config.d"
        
        # Create generic SSH config
        cat > "$HOME/.ssh/config.d/$name.conf" << EOF
Host $name
  HostName $host
  Port $port
  User $user
  IdentityFile $HOME/.ssh/id_ed25519_$name
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF
        
        log_success "SSH key generated: id_ed25519_$name"
        log_success "SSH config created: $HOME/.ssh/config.d/$name.conf"
        log_success "Key added to SSH agent"
        echo ""
        echo "→ Public key:"
        cat "$HOME/.ssh/id_ed25519_$name.pub"
        echo ""
        echo "→ Usage: ssh -T $name"
    }
    
    # Update SSH key
    update_key() {
        local name="''${1:-}"
        
        log_info "Updating SSH key: $name"
        
        validate_name "$name" || return 1
        
        if [[ ! -f "$HOME/.ssh/id_ed25519_$name" ]]; then
            log_warning "SSH key id_ed25519_$name does not exist"
            echo "Use 'ssh-setup add $name' to create it"
            return 1
        fi
        
        # Get email from existing key
        local email=$(ssh-keygen -l -f "$HOME/.ssh/id_ed25519_$name" 2>/dev/null | cut -d' ' -f3- || echo "")
        
        # Backup existing key
        cp "$HOME/.ssh/id_ed25519_$name" "$HOME/.ssh/id_ed25519_$name.backup"
        cp "$HOME/.ssh/id_ed25519_$name.pub" "$HOME/.ssh/id_ed25519_$name.pub.backup"
        
        # Remove from SSH agent
        ssh-add -d "$HOME/.ssh/id_ed25519_$name" 2>/dev/null || true
        
        # Generate new key
        ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519_$name" -N ""
        chmod 600 "$HOME/.ssh/id_ed25519_$name"
        chmod 644 "$HOME/.ssh/id_ed25519_$name.pub"
        
        # Add to SSH agent
        ssh-add "$HOME/.ssh/id_ed25519_$name" 2>/dev/null || true
        
        log_success "SSH key updated: id_ed25519_$name"
        log_success "Backup saved: id_ed25519_$name.backup"
        echo ""
        echo "→ New public key:"
        cat "$HOME/.ssh/id_ed25519_$name.pub"
    }
    
    # Delete SSH key
    delete_key() {
        local name="''${1:-}"
        
        log_info "Deleting SSH key: $name"
        
        validate_name "$name" || return 1
        
        if [[ ! -f "$HOME/.ssh/id_ed25519_$name" ]]; then
            log_warning "SSH key id_ed25519_$name does not exist"
            return 1
        fi
        
        echo "Are you sure you want to delete id_ed25519_$name? (y/N)"
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Remove from SSH agent
            ssh-add -d "$HOME/.ssh/id_ed25519_$name" 2>/dev/null || true
            
            # Delete key files
            rm "$HOME/.ssh/id_ed25519_$name"
            rm "$HOME/.ssh/id_ed25519_$name.pub"
            
            # Remove SSH config
            if [[ -f "$HOME/.ssh/config.d/$name.conf" ]]; then
                rm "$HOME/.ssh/config.d/$name.conf"
            fi
            
            log_success "SSH key deleted: id_ed25519_$name"
            log_success "Removed SSH config"
        else
            log_error "Deletion cancelled"
        fi
    }
    
    # List SSH key
    list_key() {
        local name="''${1:-}"
        
        log_info "Public key for $name:"
        
        validate_name "$name" || return 1
        
        if [[ ! -f "$HOME/.ssh/id_ed25519_$name.pub" ]]; then
            log_warning "SSH key id_ed25519_$name does not exist"
            return 1
        fi
        
        cat "$HOME/.ssh/id_ed25519_$name.pub"
    }
    
    # Test SSH connection
    test_connection() {
        local name="''${1:-}"
        
        log_info "Testing SSH connection: $name"
        
        validate_name "$name" || return 1
        
        if [[ ! -f "$HOME/.ssh/config.d/$name.conf" ]]; then
            log_warning "SSH config for $name does not exist"
            return 1
        fi
        
        # Extract host and port from config
        local host=$(grep "HostName" "$HOME/.ssh/config.d/$name.conf" | awk '{print $2}')
        local port=$(grep "Port" "$HOME/.ssh/config.d/$name.conf" | awk '{print $2}')
        local user=$(grep "User" "$HOME/.ssh/config.d/$name.conf" | awk '{print $2}')
        
        echo "Testing connection to $host:$port as $user..."
        
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$name" exit 2>/dev/null; then
            log_success "Connection successful"
        else
            log_error "Connection failed"
            echo "→ Check if the key is added to the remote server"
        fi
    }
    
    # List SSH keys
    list_keys() {
        log_info "SSH keys:"
        local found=false
        for key_file in $(find "$HOME/.ssh" -name "id_ed25519_*" 2>/dev/null); do
            if [[ -f "$key_file" && ! "$key_file" =~ \.backup$ ]]; then
                found=true
                local key_name=$(basename "$key_file" | sed 's/id_ed25519_//')
                local email=$(ssh-keygen -l -f "$key_file" 2>/dev/null | cut -d' ' -f3- || echo "unknown")
                
                # Get host info from config
                local host_info=""
                if [[ -f "$HOME/.ssh/config.d/$key_name.conf" ]]; then
                    local host=$(grep "HostName" "$HOME/.ssh/config.d/$key_name.conf" | awk '{print $2}')
                    local port=$(grep "Port" "$HOME/.ssh/config.d/$key_name.conf" | awk '{print $2}')
                    host_info=" ($host:$port)"
                fi
                
                # Check if loaded in SSH agent
                local loaded=""
                if ssh-add -l 2>/dev/null | grep -q "$key_file"; then
                    loaded=" (loaded)"
                fi
                
                echo "  $key_name: $email$host_info$loaded"
            fi
        done
        if [[ "$found" == false ]]; then
            echo "  No SSH keys found"
        fi
    }
    
    # Show help
    show_help() {
        echo "Generic SSH Setup Manager"
        echo ""
        echo "Usage: ssh-setup <command> [name] [email] [host] [port] [user]"
        echo ""
        echo "Commands:"
        echo "  add <name> [email] <host> [port] <user>     Add new SSH key"
        echo "  update [name]                              Update SSH key, keep backup"
        echo "  delete [name]                              Delete SSH key"
        echo "  ls [name]                                  List public key"
        echo "  test [name]                                Test SSH connection"
        echo "  ls                                        List all SSH keys"
        echo "  help                                      Show this help"
        echo ""
        echo "Examples:"
        echo "  ssh-setup add personal chintan@example.com github.com 443 git"
        echo "  ssh-setup add work work@company.com gitlab.com 22 git"
        echo "  ssh-setup add server admin@myserver.com 192.168.1.100 2222 admin"
        echo "  ssh-setup ls personal"
        echo "  ssh-setup test personal"
        echo "  ssh-setup ls"
        echo ""
        echo "Required for add:"
        echo "  name: SSH key identifier (e.g., personal, work, server)"
        echo "  host: Target hostname (e.g., github.com, gitlab.com)"
        echo "  user: SSH username (e.g., git, admin, root)"
        echo ""
        echo "Optional:"
        echo "  email: Email for key comment (if not provided, no comment is added)"
        echo "  port: SSH port (default: 443)"
    }
    
    # Main command dispatcher
    main() {
        local command="''${1:-help}"
        
        case "$command" in
            "add")
                add_key "''${2:-}" "''${3:-}" "''${4:-}" "''${5:-}" "''${6:-}"
                ;;
            "update")
                update_key "''${2:-}"
                ;;
            "delete")
                delete_key "''${2:-}"
                ;;
            "ls")
                if [[ -n "''${2:-}" ]]; then
                    list_key "''${2:-}"
                else
                    list_keys
                fi
                ;;
            "test")
                test_connection "''${2:-}"
                ;;
            "help"|*)
                show_help
                ;;
        esac
    }
    
    # Run main function with all arguments
    main "$@"
  '';

in
{
  home.packages = [
    sshSetupScript
  ];
}
