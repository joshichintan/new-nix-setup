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
    # wget

    # Programming languages
    # nodejs_20
    # python3
    # rustc
    # cargo
    # go
    # jdk17  # Java Development Kit 17 (using mise instead)

    # # Build tools
    # cmake
    # ninja
    # pkg-config

    # # Version managers
    # fnm  # Node.js version manager
    # pyenv  # Python version manager
    # rustup  # Rust toolchain manager
    mise  # Runtime manager (better than Homebrew version)

    # # Database tools
    # postgresql
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
