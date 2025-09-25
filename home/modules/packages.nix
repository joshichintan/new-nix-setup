{
  config,
  lib,
  pkgs,
  ...
}: {
  # Home packages
  home.packages = with pkgs; [
    # Development tools
    mise
    git
    # curl
    # wget

    # # Programming languages
    # nodejs_20
    # python3
    # rustc
    # cargo
    # go

    # # Build tools
    # cmake
    # ninja
    # pkg-config

    # # Version managers
    # fnm  # Node.js version manager
    # pyenv  # Python version manager
    # rustup  # Rust toolchain manager

    # # Database tools
    postgresql
    # redis

    # # Cloud tools
    # awscli2
    # kubectl
    # docker
    # docker-compose

    # # Network tools
    # nmap
    # netcat
    # mtr

    # # System tools
    # tmux
    # fzf
    # zoxide  # Better cd
    # direnv  # Environment management

    # # Text processing
    # ripgrep
    # fd
    # bat
    # sd  # sed alternative
    # xsv  # CSV processing

    # # Monitoring
    # htop
    # iotop
    # nethogs

    # # Security
    # gpg
    # pass  # Password manager
  ];
}
