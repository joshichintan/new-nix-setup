{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/shell.nix
    ../../modules/wezterm.nix
    ../../modules/neovim.nix
    ../../modules/homebrew.nix
  ];

  # macOS work system settings
  networking.hostName = "work-mac";
} 