{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: {
  # Zsh configuration
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh"; # make sure xdg.enable = true; in home config for this to work.
    history = {
      path = "${config.programs.zsh.dotDir}/history/.zsh_history";
      append = true;
      saveNoDups = true;
      ignoreAllDups = true;
      findNoDups = true;
      share = true;
    };

    historySubstringSearch = {
      enable = true;
      searchUpKey = ["^k"];
      searchDownKey = ["^j"];
    };
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    syntaxHighlighting.enable = true;

    # Antidote plugin manager configuration
    # Using antidote instead of oh-my-zsh for better performance
    # antidote = {
    #   enable = true;
    #   plugins = [
    #     # Load the use-omz plugin to handle Oh My Zsh dependencies
    #     "getantidote/use-omz"
    #     
    #     # Load Oh My Zsh's library
    #     "ohmyzsh/ohmyzsh path:lib"
    #     
    #     # Core utilities
    #     "ohmyzsh/ohmyzsh path:plugins/aliases"
    #     "ohmyzsh/ohmyzsh path:plugins/colored-man-pages"
    #     "ohmyzsh/ohmyzsh path:plugins/command-not-found"
    #     "ohmyzsh/ohmyzsh path:plugins/copypath"
    #     "ohmyzsh/ohmyzsh path:plugins/copyfile"
    #     "ohmyzsh/ohmyzsh path:plugins/dirhistory"
    #     "ohmyzsh/ohmyzsh path:plugins/extract"
    #     "ohmyzsh/ohmyzsh path:plugins/history"
    #     "ohmyzsh/ohmyzsh path:plugins/jsontools"
    #     "ohmyzsh/ohmyzsh path:plugins/urltools"
    #     "ohmyzsh/ohmyzsh path:plugins/web-search"
    #     "ohmyzsh/ohmyzsh path:plugins/z"
    #     
    #     # Version managers
    #     "ohmyzsh/ohmyzsh path:plugins/nvm"
    #     "ohmyzsh/ohmyzsh path:plugins/pyenv"
    #     "ohmyzsh/ohmyzsh path:plugins/rbenv"
    #     "ohmyzsh/ohmyzsh path:plugins/rvm"
    #     
    #     # Languages & Frameworks
    #     "ohmyzsh/ohmyzsh path:plugins/node"
    #     "ohmyzsh/ohmyzsh path:plugins/npm"
    #     "ohmyzsh/ohmyzsh path:plugins/yarn"
    #     "ohmyzsh/ohmyzsh path:plugins/composer"
    #     "ohmyzsh/ohmyzsh path:plugins/pip"
    #     "ohmyzsh/ohmyzsh path:plugins/rust"
    #     "ohmyzsh/ohmyzsh path:plugins/golang"
    #     "ohmyzsh/ohmyzsh path:plugins/ruby"
    #     "ohmyzsh/ohmyzsh path:plugins/rails"
    #     "ohmyzsh/ohmyzsh path:plugins/rake"
    #     "ohmyzsh/ohmyzsh path:plugins/gem"
    #     "ohmyzsh/ohmyzsh path:plugins/bundler"
    #     "ohmyzsh/ohmyzsh path:plugins/coffee"
    #     "ohmyzsh/ohmyzsh path:plugins/cake"
    #     "ohmyzsh/ohmyzsh path:plugins/capistrano"
    #     "ohmyzsh/ohmyzsh path:plugins/celery"
    #     "ohmyzsh/ohmyzsh path:plugins/ember-cli"
    #     "ohmyzsh/ohmyzsh path:plugins/gulp"
    #     "ohmyzsh/ohmyzsh path:plugins/grunt"
    #     "ohmyzsh/ohmyzsh path:plugins/heroku"
    #     "ohmyzsh/ohmyzsh path:plugins/jira"
    #     "ohmyzsh/ohmyzsh path:plugins/laravel"
    #     "ohmyzsh/ohmyzsh path:plugins/laravel5"
    #     "ohmyzsh/ohmyzsh path:plugins/lein"
    #     "ohmyzsh/ohmyzsh path:plugins/mix"
    #     "ohmyzsh/ohmyzsh path:plugins/mvn"
    #     "ohmyzsh/ohmyzsh path:plugins/perl"
    #     "ohmyzsh/ohmyzsh path:plugins/phing"
    #     "ohmyzsh/ohmyzsh path:plugins/pipenv"
    #     "ohmyzsh/ohmyzsh path:plugins/poetry"
    #     "ohmyzsh/ohmyzsh path:plugins/react-native"
    #     "ohmyzsh/ohmyzsh path:plugins/scala"
    #     "ohmyzsh/ohmyzsh path:plugins/sbt"
    #     "ohmyzsh/ohmyzsh path:plugins/spring"
    #     "ohmyzsh/ohmyzsh path:plugins/symfony"
    #     "ohmyzsh/ohmyzsh path:plugins/symfony2"
    #     "ohmyzsh/ohmyzsh path:plugins/thor"
    #     "ohmyzsh/ohmyzsh path:plugins/vagrant"
    #     "ohmyzsh/ohmyzsh path:plugins/vagrant-prompt"
    #     "ohmyzsh/ohmyzsh path:plugins/wp-cli"
    #     "ohmyzsh/ohmyzsh path:plugins/yii"
    #     "ohmyzsh/ohmyzsh path:plugins/yii2"
    #     
    #     # Cloud & DevOps
    #     "ohmyzsh/ohmyzsh path:plugins/aws"
    #     "ohmyzsh/ohmyzsh path:plugins/azure"
    #     "ohmyzsh/ohmyzsh path:plugins/docker"
    #     "ohmyzsh/ohmyzsh path:plugins/docker-compose"
    #     "ohmyzsh/ohmyzsh path:plugins/kubectl"
    #     "ohmyzsh/ohmyzsh path:plugins/helm"
    #     "ohmyzsh/ohmyzsh path:plugins/minikube"
    #     "ohmyzsh/ohmyzsh path:plugins/terraform"
    #     "ohmyzsh/ohmyzsh path:plugins/ansible"
    #     "ohmyzsh/ohmyzsh path:plugins/cloudfoundry"
    #     "ohmyzsh/ohmyzsh path:plugins/codeclimate"
    #     "ohmyzsh/ohmyzsh path:plugins/gcloud"
    #     "ohmyzsh/ohmyzsh path:plugins/kops"
    #     "ohmyzsh/ohmyzsh path:plugins/kubectx"
    #     "ohmyzsh/ohmyzsh path:plugins/salt"
    #     
    #     # Databases
    #     "ohmyzsh/ohmyzsh path:plugins/postgres"
    #     "ohmyzsh/ohmyzsh path:plugins/redis-cli"
    #     "ohmyzsh/ohmyzsh path:plugins/mysql-macports"
    #     
    #     # Build Tools
    #     "ohmyzsh/ohmyzsh path:plugins/ant"
    #     "ohmyzsh/ohmyzsh path:plugins/bower"
    #     "ohmyzsh/ohmyzsh path:plugins/debian"
    #     "ohmyzsh/ohmyzsh path:plugins/fabric"
    #     "ohmyzsh/ohmyzsh path:plugins/fastfile"
    #     "ohmyzsh/ohmyzsh path:plugins/gradle"
    #     "ohmyzsh/ohmyzsh path:plugins/macports"
    #     "ohmyzsh/ohmyzsh path:plugins/mercurial"
    #     "ohmyzsh/ohmyzsh path:plugins/ng"
    #     "ohmyzsh/ohmyzsh path:plugins/pass"
    #     "ohmyzsh/ohmyzsh path:plugins/pep8"
    #     "ohmyzsh/ohmyzsh path:plugins/per-directory-history"
    #     "ohmyzsh/ohmyzsh path:plugins/pow"
    #     "ohmyzsh/ohmyzsh path:plugins/powder"
    #     "ohmyzsh/ohmyzsh path:plugins/repo"
    #     "ohmyzsh/ohmyzsh path:plugins/rsync"
    #     "ohmyzsh/ohmyzsh path:plugins/sublime"
    #     "ohmyzsh/ohmyzsh path:plugins/svn"
    #     "ohmyzsh/ohmyzsh path:plugins/svn-fast-info"
    #     "ohmyzsh/ohmyzsh path:plugins/systemadmin"
    #     "ohmyzsh/ohmyzsh path:plugins/systemd"
    #     "ohmyzsh/ohmyzsh path:plugins/taskwarrior"
    #     "ohmyzsh/ohmyzsh path:plugins/terminitor"
    #     "ohmyzsh/ohmyzsh path:plugins/textastic"
    #     "ohmyzsh/ohmyzsh path:plugins/textmate"
    #     "ohmyzsh/ohmyzsh path:plugins/tmux"
    #     "ohmyzsh/ohmyzsh path:plugins/tmux-cssh"
    #     "ohmyzsh/ohmyzsh path:plugins/tmuxinator"
    #     "ohmyzsh/ohmyzsh path:plugins/torrent"
    #     "ohmyzsh/ohmyzsh path:plugins/ubuntu"
    #     "ohmyzsh/ohmyzsh path:plugins/ufw"
    #     "ohmyzsh/ohmyzsh path:plugins/universalarchive"
    #     "ohmyzsh/ohmyzsh path:plugins/vault"
    #     "ohmyzsh/ohmyzsh path:plugins/vi-mode"
    #     "ohmyzsh/ohmyzsh path:plugins/vim-interaction"
    #     "ohmyzsh/ohmyzsh path:plugins/virtualenv"
    #     "ohmyzsh/ohmyzsh path:plugins/vscode"
    #     "ohmyzsh/ohmyzsh path:plugins/vundle"
    #     "ohmyzsh/ohmyzsh path:plugins/wakeonlan"
    #     "ohmyzsh/ohmyzsh path:plugins/watson"
    #     "ohmyzsh/ohmyzsh path:plugins/wd"
    #     "ohmyzsh/ohmyzsh path:plugins/xcode"
    #     "ohmyzsh/ohmyzsh path:plugins/yum"
    #     "ohmyzsh/ohmyzsh path:plugins/zbell"
    #     "ohmyzsh/ohmyzsh path:plugins/zeus"
    #     "ohmyzsh/ohmyzsh path:plugins/zoxide"
    #     "ohmyzsh/ohmyzsh path:plugins/zsh-interactive-cd"
    #     
    #     # Custom completion plugins
    #     "local/aws-context path:${config.programs.zsh.dotDir}/plugins/aws-context"
    #     "local/aws-manager path:${config.programs.zsh.dotDir}/plugins/aws-manager"
    #     "local/ecr-manager path:${config.programs.zsh.dotDir}/plugins/ecr-manager"
    #     "local/ssh-setup path:${config.programs.zsh.dotDir}/plugins/ssh-setup"
    #   ];
    # };

    initContent = let
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 1: Powerlevel10k Instant Prompt
      # ══════════════════════════════════════════════════════════════════════
      p10kPrompt = lib.mkOrder 500 ''
        if [[ -r "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
        
        # Source Powerlevel10k configuration if it exists
        if [[ -r "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh" ]]; then
          source "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh"
        fi
      '';
      
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 2: Environment Setup and PATH Configuration
      # ══════════════════════════════════════════════════════════════════════
      environment = lib.mkOrder 1000 ''
        # PATH Configuration
        export PATH="$HOME/.rd/bin:$PATH"
      '';
    in
      lib.mkMerge [ p10kPrompt environment ];

    # Native Nix plugins (much faster than zplug)
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = ../p10k-config;
        file = ".p10k.zsh";
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    sessionVariables = {
      NIX_USER_CONFIG_PATH = "${config.xdg.configHome}/nix-config";
      ZSH_COMPDUMP = "${config.xdg.cacheHome}/zsh/.zcompdump-${hostname}";
      # POWERLEVEL9K_CONFIG_FILE = "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh"; # enable this when p10k merges mise config
    };


    shellAliases = {
      # General Nix aliases
      nix-update = "nix --extra-experimental-features 'nix-command flakes' flake update --flake .";
      nix-gc = "nix-store --gc";
      nix-clean = "nix-collect-garbage -d";
      
      # Mise aliases
      mise-reload = "mise_auto_activate";
      
      # AWS aliases
      aws-check = "check_aws_sso_tokens";
      
      # Config editing aliases
      nix-config = "nvim $NIX_USER_CONFIG_PATH";
    };
  };
}