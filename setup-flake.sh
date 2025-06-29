#!/bin/bash

# Get current username
CURRENT_USER=$(whoami)

# Create or update flake.nix with the current username
cat > flake.nix << EOF
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    alejandra = {
      url = "github:kamadorueda/alejandra/4.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {...} @ inputs:
    with inputs; let
      inherit (self) outputs;

      stateVersion = "24.05";
      libx = import ./lib {inherit inputs outputs stateVersion;};
    in {
      darwinConfigurations = {
        chintan = libx.mkDarwin {
          hostname = "chintan";
          username = "nix-darwin";
        };
      };

      homeConfigurations = {
        "chintan" = libx.mkHome {
          username = "$CURRENT_USER";
        };
      };
    };
}
EOF

echo "Flake.nix updated with username: $CURRENT_USER" 