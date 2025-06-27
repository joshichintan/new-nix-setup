{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    aerospace-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    alejandra = {
      url = "github:kamadorueda/alejandra/4.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko.url = "github:nix-community/disko";
    # disko.inputs.nixpkgs.follows = "nixpkgs";

    # vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = {...} @ inputs:
    with inputs; let
      inherit (self) outputs;

      stateVersion = "24.05";
      libx = import ./lib {inherit inputs outputs stateVersion;};
    in {
      darwinConfigurations = {
        # personal
        slartibartfast = libx.mkDarwin {hostname = "slartibartfast";};
        nauvis = libx.mkDarwin {hostname = "nauvis";};
        mac-studio = libx.mkDarwin {hostname = "mac-studio";};
        mac-mini = libx.mkDarwin {hostname = "mac-mini";};
        mooncake = libx.mkDarwin {hostname = "mooncake";};

        # work
        chintan = libx.mkDarwin {
          hostname = "chintan";
          username = "nix-darwin";
        };
        magrathea = libx.mkDarwin {hostname = "magrathea";};
      };
    };
}
