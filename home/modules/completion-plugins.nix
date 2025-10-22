{ config, ... }: {
  # Custom completion plugins for antidote
  home.file = {
    # AWS Manager completion plugin
    "${config.programs.zsh.dotDir}/plugins/aws-manager/aws-manager.plugin.zsh" = {
      text = ''
        # AWS Manager Completion Plugin
        # Provides tab completion for aws-mgr command
        
        # AWS Manager completion function
        _aws-manager() {
          local context state line
          typeset -A opt_args
          
          _arguments -C \
            '1: :->utility' \
            '2: :->object' \
            '3: :->target' \
            && return 0
          
          case $state in
            utility)
              _values 'utility' 'ls' 'add' 'update' 'rm' 'set' 'test' 'sync' 'status' 'help'
              ;;
            object)
              case $words[2] in
                ls)
                  _values 'object' 'sso' 'profiles' 'region' 'output'
                  ;;
                add|update|rm)
                  _values 'object' 'sso'
                  ;;
                test)
                  _values 'object' 'profiles'
                  ;;
                set)
                  _values 'object' 'region' 'output'
                  ;;
              esac
              ;;
            target)
              case $words[2] in
                update|rm)
                  case $words[3] in
                    sso)
                      # Get real SSO sessions from AWS config file
                      local sessions
                      sessions=($(grep '^\[sso-session ' ~/.aws/config 2>/dev/null | sed 's/^\[sso-session //' | sed 's/\]$//' | sort 2>/dev/null || true))
                      if [[ ''${#sessions[@]} -gt 0 ]]; then
                        _values 'sso-sessions' $sessions
                      else
                        _message "No SSO sessions found. Run 'aws-mgr add sso' to create one."
                      fi
                      ;;
                    *)
                      # If we're here, we need to complete the sso parameter
                      _values 'object' 'sso'
                      ;;
                  esac
                  ;;
                set)
                  case $words[3] in
                    region)
                      _values 'regions' 'us-east-1' 'us-west-2' 'us-west-1' 'eu-west-1' 'eu-central-1' 'ap-southeast-1' 'ap-northeast-1'
                      ;;
                    output)
                      _values 'output-formats' 'json' 'table' 'text' 'yaml'
                      ;;
                  esac
                  ;;
              esac
              ;;
          esac
        }
        
        # Register completion functions (for both command and alias)
        compdef _aws-manager aws-manager aws-mgr
      '';
    };

    # ECR Manager completion plugin
    "${config.programs.zsh.dotDir}/plugins/ecr-manager/ecr-manager.plugin.zsh" = {
      text = ''
        # ECR Manager Completion Plugin
        # Provides tab completion for ecr-mgr command
        
        # ECR Manager completion function
        _ecr-manager() {
          local context state line
          typeset -A opt_args
          
          _arguments -C \
            '1: :->utility' \
            '2: :->target' \
            '3: :->profile' \
            && return 0
          
          case $state in
            utility)
              _values 'utility' 'ls' 'add' 'update' 'rm' 'validate' 'help'
              ;;
            target)
              case $words[2] in
                add)
                  # For add, we need a registry URL (no completion for this)
                  _message "Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com)"
                  ;;
                update|rm|validate)
                  # Get real ECR registries for completion
                  local registries
                  registries=($(jq -r '.registryConfigs // {} | keys[]' ~/.docker/config.json 2>/dev/null || true))
                  if [[ ''${#registries[@]} -gt 0 ]]; then
                    _values 'ecr-registries' $registries
                  else
                    _message "No ECR registries found. Run 'ecr-mgr add <url> <profile>' to add registries."
                  fi
                  ;;
              esac
              ;;
            profile)
              case $words[2] in
                add|update)
                  # Get real AWS profiles for completion
                  local profiles
                  profiles=($(aws configure list-profiles 2>/dev/null || true))
                  if [[ ''${#profiles[@]} -gt 0 ]]; then
                    _values 'aws-profiles' $profiles
                  else
                    _message "No AWS profiles found. Run 'aws configure' to create profiles."
                  fi
                  ;;
              esac
              ;;
          esac
        }
        
        # Register completion functions (for both command and alias)
        compdef _ecr-manager ecr-manager ecr-mgr
      '';
    };

    # SSH Setup completion plugin
    "${config.programs.zsh.dotDir}/plugins/ssh-setup/ssh-setup.plugin.zsh" = {
      text = ''
        # SSH Setup Completion Plugin
        # Provides tab completion for ssh-setup command
        
        # SSH Setup completion function
        _ssh-setup() {
          local context state line
          typeset -A opt_args
          
          _arguments -C \
            '1: :->utility' \
            '2: :->target' \
            && return 0
          
          case $state in
            utility)
              _values 'utility' 'add' 'update' 'delete' 'ls' 'test' 'help'
              ;;
            target)
              case $words[2] in
                update|delete|ls|test)
                  # Get real SSH key names from ~/.ssh directory
                  local keys
                  keys=($(find ~/.ssh -name "id_ed25519_*" 2>/dev/null | sed 's|.*/id_ed25519_||' | grep -v '\.backup$' || true))
                  if [[ ''${#keys[@]} -gt 0 ]]; then
                    _values 'ssh-keys' $keys
                  else
                    _message "No SSH keys found. Run 'ssh-setup add <name> <email> <host> [port] [user]' to create one."
                  fi
                  ;;
                *)
                  # If we're here, we need to complete the key parameter
                  _values 'utility' 'update' 'delete' 'ls' 'test'
                  ;;
              esac
              ;;
          esac
        }
        
        # Register completion functions
        compdef _ssh-setup ssh-setup
      '';
    };

  };
}
