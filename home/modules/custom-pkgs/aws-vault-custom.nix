{ pkgs, ... }:

let
  aws-vault-custom = pkgs.stdenv.mkDerivation rec {
    pname = "aws-vault";
    version = "1.0.0";

    src = pkgs.fetchurl {
      url = "https://github.com/joshichintan/aws-vault/releases/download/v${version}/aws-vault-darwin-arm64";
      sha256 = "sha256:54837bd874cea55d1d96254f6d43eddd2b6c274f4e9d70716f4cf65cf9b53959";
    };

    dontUnpack = true;
    
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/aws-vault
      chmod +x $out/bin/aws-vault
    '';

    meta = with pkgs.lib; {
      description = "Custom aws-vault build with completion support";
      homepage = "https://github.com/joshichintan/aws-vault";
      platforms = platforms.darwin;
    };
  };
in
{
  home.packages = [
    aws-vault-custom
  ];
}

