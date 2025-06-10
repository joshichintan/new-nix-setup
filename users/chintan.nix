{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/shell.nix
    ../modules/wezterm.nix
    ../modules/neovim.nix
  ];

  home.username      = "chintan";
  home.homeDirectory = "/Users/chintan";

  # user-specific settings
} 