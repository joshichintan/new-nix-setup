{
  description = "My personal dotfiles (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    darwin.url         = "github:LnL7/nix-darwin";
    home-manager.url   = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }:
 {
    # nix-darwin host configurations
    darwinConfigurations = {
      personal = darwin.lib.darwinSystem {
        services.nix-daemon.enable = true;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        programs.zsh.enable = true;
        system.configurationRevision = self.rev or self.dirtyRev or null;
        system.stateVersion = 5;
        nixpkgs.hostPlatform = "aarch64-darwin";
      };
    };
  };
} 