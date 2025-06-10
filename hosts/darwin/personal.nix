{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/shell.nix
    ../../modules/wezterm.nix
    ../../modules/neovim.nix
    ../../modules/homebrew.nix
  ];

  # macOS personal system settings
  services.openssh.enable = true;
} 