{ config, pkgs, ... }:
{
  # Simple Nix aliases
  programs.zsh.shellAliases = {
    # Home Manager
    hm = "nix --extra-experimental-features 'nix-command flakes' run \"''${NIX_USER_CONFIG_PATH:-.}#homeConfigurations.\\\"$(whoami)@$(scutil --get LocalHostName)\\\".activationPackage\"";
    
    # Darwin System
    darwin = "sudo nix --extra-experimental-features 'nix-command flakes' run 'nix-darwin#darwin-rebuild' -- switch --flake \"''${NIX_USER_CONFIG_PATH:-.}#$(scutil --get LocalHostName)\"";
  };
}