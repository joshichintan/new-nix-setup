{ config, pkgs, lib, ... }:
{
  # Install GUI apps via Homebrew on macOS
  services.brew.packages = with pkgs; [
    firefox
    vlc
    # Add more Homebrew packages here
  ];
} 