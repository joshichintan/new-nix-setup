{ pkgs, lib, ... }:

{
  programs.zsh.initContent = ''
    # AWS SSO Token Check Script
    check_aws_sso_tokens() {
      # Only check if AWS CLI is available
      if ! command -v aws >/dev/null 2>&1; then
        return 0
      fi
      
      local P10K_INITIALIZATION_COMPLETE=false
      if [[ -n "$POWERLEVEL9K_INSTANT_PROMPT_THEME_STYLED" ]]; then
        P10K_INITIALIZATION_COMPLETE=true
      fi
      
      local aws_cache_dir="$HOME/.aws/sso/cache"
      local current_time=$(date +%s)
      local valid_tokens=0
      
      if [[ -d "$aws_cache_dir" ]]; then
        for cache_file in "$aws_cache_dir"/*.json; do
          if [[ -f "$cache_file" ]]; then
            local expires_at=$(jq -r '.expiresAt' "$cache_file" 2>/dev/null)
            if [[ -n "$expires_at" && "$expires_at" != "null" ]]; then
              local expires_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo "0")
              if [[ $current_time -lt $expires_time ]]; then
                valid_tokens=$((valid_tokens + 1))
              fi
            fi
          fi
        done
      fi
      
      if [[ $valid_tokens -eq 0 && "$P10K_INITIALIZATION_COMPLETE" == true ]]; then
        echo "  ⚠ AWS SSO tokens expired or not found. Run 'aws sso login' for each session."
      fi
    }
    add-zsh-hook precmd check_aws_sso_tokens

    # AWS Context Script
    # Sets AWS_PROFILE and AWS_DEFAULT_REGION environment variables for current session
    aws-context() {
      # Show help if no arguments
      if [[ $# -eq 0 ]]; then
        cat << EOF
AWS Context Script

Usage: aws-context <profile> [region]

Arguments:
  profile    AWS profile name (required)
  region     AWS region (optional, but required if profile has no default region)

Region Resolution Priority:
  1. Explicit region argument (highest priority)
  2. Profile's default region (aws configure set region --profile <profile>)
  3. Global default region (aws configure set region)

Examples:
  aws-context company-dev-frontend                    # Uses profile's or global default region
  aws-context company-dev-frontend us-west-2          # Uses explicit region
  aws-context personal-projects eu-west-1             # Uses explicit region

This script directly exports AWS_PROFILE and AWS_DEFAULT_REGION to your current shell.
Use tab completion to see available profiles and regions.

EOF
        return 0
      fi
      
      local profile="$1"
      local region="''${2:-}"
      
      # Validate profile exists
      if ! aws configure list-profiles | grep -q "^''${profile}$"; then
        echo "✗ Profile '$profile' not found" >&2
        echo "Available profiles:" >&2
        aws configure list-profiles | sed 's/^/  /' >&2
        return 1
      fi
      
      # Get region if not provided
      if [[ -z "$region" ]]; then
        # Try to get region from profile first
        region=$(aws configure get region --profile "$profile" 2>/dev/null || echo "")
        
        # If profile doesn't have region, try global default
        if [[ -z "$region" ]]; then
          region=$(aws configure get region 2>/dev/null || echo "")
        fi
      fi
      
      # Validate that we have a region from somewhere
      if [[ -z "$region" ]]; then
        echo "✗ No region available" >&2
        echo "Region must be provided in one of these ways:" >&2
        echo "  1. As second argument: aws-context $profile <region>" >&2
        echo "  2. In profile config: aws configure set region <region> --profile $profile" >&2
        echo "  3. As global default: aws configure set region <region>" >&2
        echo "" >&2
        echo "Available regions:" >&2
        echo "  us-east-1, us-west-2, us-west-1, eu-west-1, eu-central-1, ap-southeast-1, ap-northeast-1" >&2
        return 1
      fi
      
      # Export variables directly to current shell
      export AWS_PROFILE="$profile"
      export AWS_DEFAULT_REGION="$region"
      
      # Show status
      echo "✓ Set AWS_PROFILE to $profile"
      echo "✓ Set AWS_DEFAULT_REGION to $region"
      echo ""
      echo "Current AWS context:"
      echo "  Profile: $profile"
      echo "  Region: $region"
      echo ""
      echo "Note: These are environment variables for this session only"
    }
  '';
}
