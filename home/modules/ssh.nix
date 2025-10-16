{
  config,
  lib,
  pkgs,
  ...
}: {
  # SSH configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    
    # Global security settings
    extraConfig = ''
      # Security settings
      StrictHostKeyChecking ask
      UserKnownHostsFile ${config.home.homeDirectory}/.ssh/known_hosts
      IdentitiesOnly yes
      AddKeysToAgent yes
      UseKeychain yes
      
      # Additional security
      PasswordAuthentication no
      PubkeyAuthentication yes
      ChallengeResponseAuthentication no
      GSSAPIAuthentication no
      HostbasedAuthentication no
      
      # Connection settings
      ServerAliveInterval 60
      ServerAliveCountMax 3
      TCPKeepAlive yes
      ConnectTimeout 30
      
      # Compression and multiplexing
      Compression yes
      ControlMaster auto
      ControlPath ${config.home.homeDirectory}/.ssh/master-%r@%h:%p
      ControlPersist 10m
      
      # Include user-managed configs
      Include ${config.home.homeDirectory}/.ssh/config.d/*.conf
    '';
    
    matchBlocks = {
      # Default settings for all hosts (replaces Home Manager defaults)
      "*" = {
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };
}
