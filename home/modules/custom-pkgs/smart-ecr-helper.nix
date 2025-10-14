{ config, pkgs, ... }:
let
  # Universal Smart ECR Helper
  smartEcrHelper = pkgs.writeShellScriptBin "docker-credential-smart-ecr-helper" ''
    #!/bin/bash
    set -euo pipefail
    
    # Read input from Docker
    input=$(cat)
    if echo "$input" | jq . >/dev/null 2>&1; then
        server_url=$(echo "$input" | jq -r '.ServerURL')
    else
        server_url="$input"
    fi
    
    # Get profile from registry config
    profile=$(jq -r --arg reg "$server_url" '.registryConfigs[$reg].profile // empty' "$HOME/.docker/config.json" 2>/dev/null || true)
    
    if [[ -z "$profile" ]]; then
        echo "No profile configured for registry: $server_url" >&2
        exit 1
    fi
    
    # Get ECR token
    ecr_token=$(aws ecr get-login-password --profile "$profile" --region "$(echo "$server_url" | cut -d'.' -f4)")
    
    if [[ -z "$ecr_token" ]]; then
        echo "Failed to get ECR token for profile: $profile" >&2
        exit 1
    fi
    
    # Return credentials in Docker's expected format
    echo "{\"ServerURL\":\"$server_url\",\"Username\":\"AWS\",\"Secret\":\"$ecr_token\"}"
  '';

in
{
  home.packages = [
    smartEcrHelper
  ];
}
