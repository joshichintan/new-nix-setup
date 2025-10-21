{
  inputs,
  pkgs,
  unstablePkgs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # unused but here just incase I forget how to install it
    # nixpkgs-unstable.legacyPackages.${pkgs.system}.beszel

    ## stable
    # Packages moved to home-manager packages.nix
    # bat
    # coreutils
    # diffr # Modern Unix `diff`
    # difftastic # Modern Unix `diff`
    # drill
    # du-dust # Modern Unix `du`
    # dua # Modern Unix `du`
    # duf # Modern Unix `df`
    # entr # Modern Unix `watch`
    # kubectl
    # fzf
    # gh
    # ripgrep
    # wget
    # wezterm
  ];
}
