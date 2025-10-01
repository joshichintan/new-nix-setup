{
  config,
  lib,
  pkgs,
  ...
}: {
  # SSH configuration
  programs.ssh = {
    enable = true;
    
    # Global security settings
    extraConfig = ''
      # Security settings
      StrictHostKeyChecking ask
      UserKnownHostsFile ~/.ssh/known_hosts
      IdentitiesOnly yes
      AddKeysToAgent yes
      UseKeychain yes
      
      # Connection settings
      ServerAliveInterval 60
      ServerAliveCountMax 3
      TCPKeepAlive yes
      
      # Compression and multiplexing
      Compression yes
      ControlMaster auto
      ControlPath ~/.ssh/master-%r@%h:%p
      ControlPersist 10m
    '';
    
    matchBlocks = {
      # GitHub configuration
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };
      
      # Default settings for all hosts
      "*" = {
        user = "root";
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };
  };
}
