{
  config,
  lib,
  pkgs,
  ...
}: {
  # Home packages
  home.packages = with pkgs; [
    # Development tools
    # git
    # curl
    wget

    # Programming languages
    # nodejs_20
    # python3
    # rustc
    # cargo
    # go
    # jdk17  # Java Development Kit 17

    # Build tools
    gradle  # Gradle build tool
    # cmake
    # ninja
    # pkg-config

    # # Version managers
    # fnm  # Node.js version manager
    # pyenv  # Python version manager
    # rustup  # Rust toolchain manager
    # mise  # Runtime manager (managed by programs.mise in mise.nix)

    # Database tools
    postgresql_13  # PostgreSQL 13
    # redis
    
    # JSON and API tools
    jq  # JSON processor
    postman  # API development platform

    # # Cloud tools
    awscli2
    # amazon-ecr-credential-helper
    aws-vault
    terraform
    # Note: smart-ecr-helper is provided by ecr.nix module
    # kubectl # installed through rancher-desktop
    # docker

    # # Network tools
    # nmap
    # netcat
    # mtr

    # # System tools
    # tmux
    # fzf  # Already enabled in programs.fzf
    # zoxide  # Already enabled in programs.zoxide
    # direnv  # Already enabled in programs.direnv

    # # Text processing
    ripgrep
    # fd
    # bat  # Already enabled in programs.bat
    # sd  # sed alternative
    # xsv  # CSV processing

    # # Monitoring
    # htop  # Already enabled in programs.htop
    # iotop
    # nethogs

    # # Security
    # gpg
    # pass  # Password manager
    _1password-cli

    # Moved from darwin common packages
    nix  # Nix package manager
    coreutils
    diffr # Modern Unix `diff`
    difftastic # Modern Unix `diff`
    drill
    du-dust # Modern Unix `du`
    dua # Modern Unix `du`
    duf # Modern Unix `df`
    entr # Modern Unix `watch`
    gh
    vault
    wezterm
    # k9s
  ];
}
