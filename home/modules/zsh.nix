{
  config,
  lib,
  pkgs,
  ...
}: {
  # Zsh configuration
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh"; # make sure xdg.enable = true; in home config for this to work.
    history = {
      path = "${config.programs.zsh.dotDir}/.zsh_history";
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

    # Oh My Zsh configuration - minimal and working plugins only
    oh-my-zsh = {
      enable = true;
      plugins = [
        # Core utilities (verified to exist)
        "aliases"
        "colored-man-pages"
        "command-not-found"
        "copypath"
        "copyfile"
        "dirhistory"
        "extract"
        "history"
        "jsontools"
        "urltools"
        "web-search"
        "z"
        
        # Version managers (verified to exist)
        "nvm"
        "pyenv"
        "rbenv"
        "rvm"
        
        # Languages & Frameworks (verified to exist)
        "node"
        "npm"
        "yarn"
        "composer"
        "pip"
        "rust"
        "golang"
        "ruby"
        "rails"
        "rake"
        "gem"
        "bundler"
        "coffee"
        "cake"
        "capistrano"
        "celery"
        "ember-cli"
        "gulp"
        "grunt"
        "heroku"
        "jira"
        "laravel"
        "laravel5"
        "lein"
        "mix"
        "mvn"
        "perl"
        "phing"
        "pipenv"
        "poetry"
        "react-native"
        "scala"
        "sbt"
        "spring"
        "symfony"
        "symfony2"
        "thor"
        "vagrant"
        "vagrant-prompt"
        "wp-cli"
        "yii"
        "yii2"
        
        # Cloud & DevOps (verified to exist)
        "aws"
        "azure"
        "docker"
        "docker-compose"
        "kubectl"
        "helm"
        "minikube"
        "terraform"
        "ansible"
        "cloudfoundry"
        "codeclimate"
        "gcloud"
        "kops"
        "kubectx"
        "salt"
        
        # Databases (verified to exist)
        "postgres"
        "redis-cli"
        "mysql-macports"
        
        # Build Tools (verified to exist)
        "ant"
        "bower"
        "debian"
        "fabric"
        "fastfile"
        "gradle"
        "macports"
        "mercurial"
        "ng"
        "pass"
        "pep8"
        "per-directory-history"
        "pow"
        "powder"
        "repo"
        "rsync"
        "sublime"
        "svn"
        "svn-fast-info"
        "systemadmin"
        "systemd"
        "taskwarrior"
        "terminitor"
        "textastic"
        "textmate"
        "tmux"
        "tmux-cssh"
        "tmuxinator"
        "torrent"
        "ubuntu"
        "ufw"
        "universalarchive"
        "vault"
        "vi-mode"
        "vim-interaction"
        "virtualenv"
        "vscode"
        "vundle"
        "wakeonlan"
        "watson"
        "wd"
        "xcode"
        "yum"
        "zbell"
        "zeus"
        "zoxide"
        "zsh-interactive-cd"
      ];
    };

    initContent = let
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 1: Powerlevel10k Instant Prompt
      # ══════════════════════════════════════════════════════════════════════
      p10kPrompt = lib.mkOrder 500 ''
        if [[ -r "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "${config.xdg.cacheHome}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
        
        # enable this when p10k merges mise config 
        # # Source Powerlevel10k configuration if it exists
        # if [[ -r "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh" ]]; then
        #   source "${config.programs.zsh.dotDir}/p10k-config/.p10k.zsh"
        # fi
      '';
      
      # ══════════════════════════════════════════════════════════════════════
      # SECTION 2: Environment Setup, Hooks, and Functions
      # ══════════════════════════════════════════════════════════════════════
      functions = lib.mkOrder 1000 ''
        # ──────────────────────────────────────────────────────────────────
        # PATH Configuration
        # ──────────────────────────────────────────────────────────────────
        export PATH="$HOME/.rd/bin:$PATH"
        
        # ──────────────────────────────────────────────────────────────────
        # AWS SSO Token Check
        # ──────────────────────────────────────────────────────────────────
        check_aws_sso_tokens() {
          # Only check if AWS CLI is available
          if ! command -v aws >/dev/null 2>&1; then
            return 0
          fi
          
          local P10K_INITIALIZATION_COMPLETE=false
          if [[ -n "$POWERLEVEL9K_INSTANT_PROMPT_THEME_STYLED" ]]; then
            P10K_INITIALIZATION_COMPLETE=true
          fi
          
          local aws_cache_dir="$HOME/.aws/sso/cache"
          local current_time=$(date +%s)
          local valid_tokens=0
          
          if [[ -d "$aws_cache_dir" ]]; then
            for cache_file in "$aws_cache_dir"/*.json; do
              if [[ -f "$cache_file" ]]; then
                local expires_at=$(jq -r '.expiresAt' "$cache_file" 2>/dev/null)
                if [[ -n "$expires_at" && "$expires_at" != "null" ]]; then
                  local expires_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo "0")
                  if [[ $current_time -lt $expires_time ]]; then
                    valid_tokens=$((valid_tokens + 1))
                  fi
                fi
              fi
            done
          fi
          
          if [[ $valid_tokens -eq 0 && "$P10K_INITIALIZATION_COMPLETE" == true ]]; then
            echo "  ⚠ AWS SSO tokens expired or not found. Run 'aws sso login' for each session."
          fi
        }
        add-zsh-hook precmd check_aws_sso_tokens
        
        # ──────────────────────────────────────────────────────────────────
        # Mise Auto-activation and Installation
        # ──────────────────────────────────────────────────────────────────
        mise_precmd() {
          # Skip first run to avoid p10k instant prompt interference
          if [[ -z "$POWERLEVEL9K_INSTANT_PROMPT_THEME_STYLED" ]]; then
            return 0
          fi
          
          # Install missing tools and display if installed
          if mise ls --current --json 2>/dev/null | grep -q '"installed": false'; then
            echo "» Installing missing tools..."
            mise install
          fi
        }
        add-zsh-hook precmd mise_precmd
      '';

      # ══════════════════════════════════════════════════════════════════════
      # SECTION 3: Shell Utilities and Dev Tools
      # ══════════════════════════════════════════════════════════════════════
      shellUtils = lib.mkOrder 2000 ''
        # Source the shell utilities
        if [[ -f "${config.xdg.configHome}/zsh/shell-utils.sh" ]]; then
          source "${config.xdg.configHome}/zsh/shell-utils.sh"
        fi
        
        # Source the dev tools
        if [[ -f "${config.xdg.configHome}/zsh/dev-tools.sh" ]]; then
          source "${config.xdg.configHome}/zsh/dev-tools.sh"
        fi
      '';
    in
      lib.mkMerge [ p10kPrompt functions shellUtils ];

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