{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable   = true;
    package  = pkgs.neovim;
    # Configure NVF or other Neovim settings here
  };
} 