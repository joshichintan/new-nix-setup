{
  config,
  lib,
  pkgs,
  ...
}: {
  # direnv configuration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    
    config = {
      # Global direnv configuration
      global = {
        # Hide "direnv: loading" messages
        hide_env_diff = false;
        
        # Warn after 5 seconds if direnv is taking too long
        warn_timeout = "5s";
      };
    };
    
    stdlib = ''
      # Custom direnv functions
      # Note: mise is globally activated via shell hook in zsh.nix
      # No need for mise-specific direnv integration
    '';
  };
}

