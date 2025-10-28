{ pkgs, ... }:

let
  aws-vault-custom = pkgs.stdenv.mkDerivation rec {
    pname = "aws-vault";
    version = "1.0.1";

    src = pkgs.fetchurl {
      url = "https://github.com/joshichintan/aws-vault/releases/download/v${version}/aws-vault-darwin-arm64";
      sha256 = "sha256:9f324ccd9044015b30fd1990438bd708ad33d6761d7a45cac573be2b3adc4397";
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

