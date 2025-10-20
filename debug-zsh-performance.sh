#!/bin/zsh

# Zsh Startup Performance Debug Script
echo "🔍 Analyzing Zsh startup performance..."

# Function to time a command
time_command() {
    local name="$1"
    local command="$2"
    echo -n "⏱️  $name: "
    local start_time=$(date +%s.%N)
    eval "$command" >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    printf "%.3fs\n" "$duration"
}

echo ""
echo "📊 Component Loading Times:"
echo "=========================="

# Test individual components
time_command "Oh My Zsh Core" "source /nix/store/jnllgakhrinik1gn3dkvbab8lasllbk5-oh-my-zsh-2025-09-27/share/oh-my-zsh/oh-my-zsh.sh"
time_command "Powerlevel10k Config" "source ~/.config/zsh/p10k-config/.p10k.zsh"
time_command "Zsh Autosuggestions" "source /nix/store/nk22gl93k4j04b7h3as62bnga9sddxsj-zsh-autosuggestions-0.7.1/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
time_command "Zsh Syntax Highlighting" "source /nix/store/5sz7nq1fa9xm5qmr4bykqcf9cz9b9gkf-zsh-syntax-highlighting-0.8.0/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
time_command "FZF Tab" "source /Users/chintan.joshi/.config/zsh/plugins/fzf-tab/share/fzf-tab/fzf-tab.plugin.zsh"
time_command "Mise Activation" "eval \"\$(/nix/store/kx6g8lbssjsgkzfvgc5qn1wli2n5dps3-mise-2025.9.10/bin/mise activate zsh)\""
time_command "Direnv Hook" "eval \"\$(/nix/store/gbv43vz3npy7khzf9pf3wi56h2g3v4zc-direnv-2.37.1/bin/direnv hook zsh)\""
time_command "Zoxide Init" "eval \"\$(/nix/store/5b2imcwqjd62i8r3xzwvrzxak016vybk-zoxide-0.9.8/bin/zoxide init zsh)\""

echo ""
echo "🔍 Checking for Common Issues:"
echo "=============================="

# Check gitstatus
if [[ -f ~/.config/zsh/plugins/powerlevel10k/share/zsh-powerlevel10k/gitstatus/gitstatus.plugin.zsh ]]; then
    echo "✅ Gitstatus plugin found"
else
    echo "❌ Gitstatus plugin missing"
fi

# Check plugin count
plugin_count=$(echo "aliases colored-man-pages command-not-found copypath copyfile dirhistory extract history jsontools urltools web-search z nvm pyenv rbenv rvm node npm yarn composer pip rust golang ruby rails rake gem bundler coffee cake capistrano celery ember-cli gulp grunt heroku jira laravel laravel5 lein mix mvn perl phing pipenv poetry react-native scala sbt spring symfony symfony2 thor vagrant vagrant-prompt wp-cli yii yii2 aws azure docker docker-compose kubectl helm minikube terraform ansible cloudfoundry codeclimate gcloud kops kubectx salt postgres redis-cli mysql-macports ant bower debian fabric fastfile gradle macports mercurial ng pass pep8 per-directory-history pow powder repo rsync sublime svn svn-fast-info systemadmin systemd taskwarrior terminitor textastic textmate tmux tmux-cssh tmuxinator torrent ubuntu ufw universalarchive vault vi-mode vim-interaction virtualenv vscode vundle wakeonlan watson wd xcode yum zbell zeus zoxide zsh-interactive-cd aws-context aws-manager ecr-manager ssh-setup" | wc -w)
echo "📦 Oh My Zsh plugins: $plugin_count (this is A LOT!)"

# Check completion system
if [[ -f ~/.config/zsh/.zcompdump ]]; then
    echo "✅ Completion dump exists"
    echo "📏 Completion dump size: $(ls -lh ~/.config/zsh/.zcompdump | awk '{print $5}')"
else
    echo "❌ No completion dump found"
fi

echo ""
echo "💡 Recommendations:"
echo "==================="
echo "1. Reduce Oh My Zsh plugins from $plugin_count to ~20 essential ones"
echo "2. Fix gitstatus initialization"
echo "3. Consider using zsh defer for heavy plugins"
echo "4. Enable instant prompt for faster startup"


