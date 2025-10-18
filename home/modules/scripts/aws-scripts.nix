{ pkgs, lib, ... }:

{
  programs.zsh.initContent = ''
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
