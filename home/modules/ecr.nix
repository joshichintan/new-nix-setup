{ pkgs, ... }:
{
  smartEcrHelper = pkgs.writeShellScriptBin "smart-ecr-helper" ''
    #!/bin/bash
    # Get the profile name from the calling binary name
    PROFILE_NAME=$(basename "$0" | sed 's/^ecr-login-//')
    ECR_HELPER="docker-credential-helper-ecr"
    LOG_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/ecr-''${PROFILE_NAME}.log"
    
    # Logging function
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [''$PROFILE_NAME] $*" >> "$LOG_FILE"
    }
    
    # Detect authentication method for profile
    detect_auth_method() {
        if aws configure get sso_start_url --profile "$PROFILE_NAME" >/dev/null 2>&1; then
            echo "sso"
        else
            echo "credentials"
        fi
    }
    
    # Ensure SSO session is valid
    ensure_sso_session() {
        if ! aws sts get-caller-identity --profile "$PROFILE_NAME" >/dev/null 2>&1; then
            log "SSO session expired for profile: $PROFILE_NAME"
            echo "SSO session expired for profile: $PROFILE_NAME" >&2
            echo "Please run: aws sso login --profile $PROFILE_NAME" >&2
            return 1
        fi
        return 0
    }
    
    # Main function
    main() {
        # Ensure log directory exists
        mkdir -p "$(dirname "$LOG_FILE")"
        
        log "Starting ECR authentication for profile: $PROFILE_NAME"
        
        # Set AWS profile
        export AWS_PROFILE="$PROFILE_NAME"
        
        # Detect authentication method
        local auth_method=$(detect_auth_method)
        log "Authentication method: $auth_method"
        
        # Handle SSO authentication
        if [[ "$auth_method" == "sso" ]]; then
            if ! ensure_sso_session; then
                exit 1
            fi
        fi
        
        # Delegate to the actual ECR credential helper
        log "Delegating to docker-credential-helper-ecr"
        exec "$ECR_HELPER" "$@"
    }
    
    # Execute main function
    main "$@"
  '';

}
