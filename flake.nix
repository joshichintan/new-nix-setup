{
  description = "My personal dotfiles (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    darwin.url         = "github:LnL7/nix-darwin";
    home-manager.url   = "github:nix-community/home-manager";
    flake-utils.url    = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        # nix-darwin host configurations
        darwinConfigurations = {
          personal = darwin.lib.darwinSystem {
            system                 = system;
            modules                = [ ./hosts/darwin/personal.nix ];
            pkgs                   = pkgs;
            darwinUseHomeManager   = true;
            homeManagerConfiguration = ./users/chintan.nix;
          };

          work = darwin.lib.darwinSystem {
            system                 = system;
            modules                = [ ./hosts/darwin/work.nix ];
            pkgs                   = pkgs;
            darwinUseHomeManager   = true;
            homeManagerConfiguration = ./users/chintan.nix;
          };
        };

        # standalone home-manager configuration
        homeConfigurations = {
          chintan = home-manager.lib.homeManagerConfiguration {
            pkgs          = pkgs;
            modules       = [ ./users/chintan.nix ];
            homeDirectory = "/Users/chintan";
            username      = "chintan";
          };
        };
      });
} 