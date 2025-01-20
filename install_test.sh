#!/usr/bin/env bash

DOTFILES="$(pwd)"
COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"

LOG_FILE="$DOTFILES/install.log"

title() {
    echo -e "\n${COLOR_PURPLE}$1${COLOR_NONE}"
    echo -e "${COLOR_GRAY}==============================${COLOR_NONE}\n"
}

error() {
    echo -e "${COLOR_RED}Error: ${COLOR_NONE}$1"
    # $0 プログラム名
    # $1 一つ目の引数の値
    # $2 それ移行...
    exit 1
}

warning() {
    echo -e "${COLOR_YELLOW}Warning: ${COLOR_NONE}$1"
}

info() {
    echo -e "${COLOR_BLUE}Info: ${COLOR_NONE}$1"
}

success() {
    echo -e "${COLOR_GREEN}$1${COLOR_NONE}"
}

log_action() {
    echo "$1" >> "$LOG_FILE"
}

show_usage() {
    echo -e $"\nUsage: $(basename "$0") [-u] {symlink|git|homebrew|defaults|shell|terminfo}\n"
    exit 1
}

get_linkables() {
  find -H "$DOTFILES" ! \( -path "${DOTFILES}/worktree" -prune \) -maxdepth 3 -name '*.symlink'
  # "" 挟まれた文字列を評価・展開されて文字列として返す
  # ! で否定する。-notでも良い。
  # \(\)とカッコで囲って先に優先的に評価させる。「優先的」に関しては、
  # https://www.putorius.net/linux-find-command.htmlの"Force precedence operator"を参照
}

# Gitの設定関数
setup_git() {
    defaultName=$(git config user.name)
    defaultEmail=$(git config user.email)
    defaultGithub=$(git config github.user)

    read -rp "Name [$defaultName]: " name
    read -rp "Email [$defaultEmail]: " email
    read -rp "Github username [$defaultGithub]: " github

    git config -f ~/.gitconfig-local user.name "${name:-$defaultName}"
    git config -f ~/.gitconfig-local user.email "${email:-$defaultEmail}"
    git config -f ~/.gitconfig-local github.user "${github:-$defaultGithub}"

    if [[ "$(uname)" == "Darwin" ]]; then
        git config --global credential.helper "osxkeychain"
        success "Configured Git credential.helper to use macOS Keychain (osxkeychain)."
    else
        read -rn 1 -p "Save user and password to an unencrypted file to avoid writing? [y/N]: " save
        echo
        if [[ $save =~ ^([Yy])$ ]]; then
            git config --global credential.helper "store"
            success "Configured Git credential.helper to store credentials in plaintext."
        else
            git config --global credential.helper "cache --timeout 3600"
            success "Configured Git credential.helper to cache credentials for 3600 seconds."
        fi
    fi

    success "Git configuration completed."
}

# Gitの設定削除
unset_git() {
    # ローカル設定の削除
    if [ -f ~/.gitconfig-local ]; then
        rm ~/.gitconfig-local
        success "Removed local Git configuration."
    else
        warning "No local Git configuration found."
    fi

    # グローバル認証情報のリセット
    git config --global --unset credential.helper
    success "Reset Git credential.helper."

    # グローバルユーザー設定のリセット
    if git config --global --get user.name &>/dev/null; then
        git config --global --remove-section user
        success "Cleared global Git user configuration."
    else
        warning "No global Git user configuration found."
    fi

    # 保存された認証情報の削除
    if [ -f ~/.git-credentials ]; then
        rm ~/.git-credentials
        success "Removed stored Git credentials."
    else
        warning "No stored Git credentials found."
    fi

    success "Git setup has been successfully removed"
}

# Symblic linkを作成
setup_symlinks() {
    for file in $(get_linkables); do
        target="$HOME/.$(basename "$file" '.symlink')"
        if [[ -e "$target" ]]; then
            if [[ -L "$target" ]]; then
                info "~${target#$HOME} is already a symbolic link... Skipping."
            else
                warning "~${target#$HOME} exists as a regular file."
                read -rp "Backup the file and replace with symbolic link? [y/n]: " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    backup="${target}.org"
                    mv -f "$target" "$backup"  # 通常のファイルを強制的にバックアップ
                    info "Moved ~${target#$HOME} to ~${backup#$HOME}."
                    ln -s "$file" "$target"  # シンボリックリンクを作成
                    success "Replaced ~${target#$HOME} with a symbolic link."
                else
                    info "Skipping ~${target#$HOME}."
                fi
            fi
        else
            info "Creating symlink for $file"
            ln -s "$file" "$target"
            success "Symlink created: ~${target#$HOME} -> $file"
        fi
    done

    echo -e
    info "Installing to ~/.config"
    if [[ ! -d "$HOME/.config" ]]; then
        info "Creating ~/.config"
        mkdir -p "$HOME/.config"
    fi

    config_files=$(find "$DOTFILES/config" -mindepth 1 -maxdepth 1 2>/dev/null)
    for config in $config_files; do
        target="$HOME/.config/$(basename "$config")"
        if [[ -e "$target" ]]; then
            info "~${target#$HOME} already exists... Skipping."
        else
            info "Creating symlink for $config"
            ln -s "$config" "$target"
            success "Symlink created: ~${target#$HOME} -> $config"
        fi
    done

    info "Creating OS dependent zshrc.local"
    target="${HOME}/.zshrc.local"

    if [[ "$(uname)" == "Darwin" ]]; then
        file="$DOTFILES/zsh/zshrc.local.mac"
    else
        file="$DOTFILES/zsh/zshrc.local.linux"
    fi

    if [[ -e "$target" ]]; then
        if [[ -L "$target" ]]; then
            info "~${target#$HOME} is already a symbolic link... Skipping."
        else
            warning "~${target#$HOME} exists as a regular file."
            read -rp "Backup the file and replace with symbolic link? [y/n]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                backup="${target}.org"
                mv -f "$target" "$backup"  # 通常のファイルを強制的にバックアップ
                info "Moved ~${target#$HOME} to ~${backup#$HOME}."
                ln -s "$file" "$target"  # シンボリックリンクを作成
                success "Replaced ~${target#$HOME} with a symbolic link."
            else
                info "Skipping ~${target#$HOME}."
            fi
        fi
    else
        info "Creating symlink for $target"
        ln -s "$file" "$target"
        success "Symlink created: ~${target#$HOME} -> $file"
    fi

    info "Creating .ssh directory"
    ssh_dir="${HOME}/.ssh"
    link_target="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/ssh_files"

    if [[ -L "$ssh_dir" && "$(readlink "$ssh_dir")" == "$link_target" ]]; then
        info "~${ssh_dir#$HOME} is already correctly linked... Skipping."
    elif [[ -e "$ssh_dir" ]]; then
        warning "~${ssh_dir#$HOME} exists but is not a symbolic link."
        read -rp "Backup and replace with symbolic link? [y/n]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            backup="${ssh_dir}.org"
            mv -f "$ssh_dir" "$backup"  # バックアップ
            info "Moved ~${ssh_dir#$HOME} to ~${backup#$HOME}."
            ln -s "$link_target" "$ssh_dir"  # シンボリックリンクを作成
            success "Replaced ~${ssh_dir#$HOME} with a symbolic link to $link_target."
        else
            info "Skipping ~${ssh_dir#$HOME}."
        fi
    else
        ln -s "$link_target" "$ssh_dir"
        success "Created symbolic link: ~${ssh_dir#$HOME} -> $link_target."
    fi
}

unset_symlinks() {
    for file in $(get_linkables); do
        target="$HOME/.$(basename "$file" '.symlink')"
        if [[ -L "$target" ]]; then
            backup="${target}.org"
            if [[ -e "$backup" ]]; then
                info "Restoring ~${backup#$HOME} to ~${target#$HOME}."
                mv -f "$backup" "$target"
                success "Restored ~${target#$HOME}."
            else
                info "Removing symlink ~${target#$HOME}."
                rm -f "$target"
                success "Removed ~${target#$HOME}."
            fi
        elif [[ -e "$target" ]]; then
            info "~${target#$HOME} is not a symlink... Skipping."
        else
            info "~${target#$HOME} dose not exist... Skipping."
        fi
    done

    echo -e
    info "Removing ~/.config symlinks"
    config_files=$(find "$DOTFILES/config" -mindepth 1 -maxdepth 1 2>/dev/null)
    for config in $config_files; do
        target="$HOME/.config/$(basename "$config")"
        if [[ -L "$target" ]]; then
            backup="${target}.org"
            if [[ -e "$backup" ]]; then
                info "Restoring ~${backup#$HOME} to ~${target#$HOME}."
                mv -f "$backup" "$target"
                success "Restored ~${target#$HOME}."
            else
                info "Removing symlink ~${target#$HOME}."
                rm -f "$target"
                success "Removed ~${target#$HOME}."
            fi
        elif [[ -e "$target" ]]; then
            info "~${target#$HOME} is not a symlink... Skipping."
        else
            info "~${target#$HOME} dose not exist... Skipping."
        fi
    done

    info "Removing OS dependent zshrc.local"
    target="${HOME}/.zshrc.local"
    if [[ -L "$target" ]]; then
        backup="${target}.org"
        if [[ -e "$backup" ]]; then
            info "Restoring ~${backup#$HOME} to ~${target#$HOME}."
            mv -f "$backup" "$target"
            success "Restored ~${target#$HOME}."
        else
            info "Removing symlink ~${target#$HOME}."
            rm -f "$target"
            success "Removed ~${target#$HOME}."
        fi
    elif [[ -e "$target" ]]; then
        info "~${target#$HOME} is not a symlink... Skipping."
    else
        info "~${target#$HOME} dose not exist... Skipping."
    fi

    info "Removing .ssh directory link"
    ssh_dir="${HOME}/.ssh"
    link_target="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/ssh_files"
    if [[ -L "$ssh_dir" ]]; then
        backup="${ssh_dir}.org"
        if [[ -e "$backup" ]]; then
            info "Restoring ~${backup#$HOME} to ~${ssh_dir#$HOME}."
            rm -f "$ssh_dir"
            mv "$backup" "$ssh_dir"
            success "Restored ~${ssh_dir#$HOME}."
        else
            info "Removing symlink ~${ssh_dir#$HOME}."
            rm -f "$ssh_dir"
            success "Removed ~${ssh_dir#$HOME}."
        fi
    elif [[ -e "$target" ]]; then
        info "~${target#$HOME} is not a symlink... Skipping."
    else
        info "~${target#$HOME} dose not exist... Skipping."
    fi
}

# Setup Homebrew
setup_homebrew() {
    # Homebrewのインストール
    if ! command -v brew &>/dev/null; then
        info "Homebrew not installed. Installing."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    else
        info "Homebrew is already installed."
    fi

    # Linux環境での設定
    if [[ "$(uname)" == "Linux" ]]; then
        if [[ -d ~/.linuxbrew ]]; then
            eval "$(~/.linuxbrew/bin/brew shellenv)"
        elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi

    # BrewfileとBrewfile.optionalのパスを設定
    platform_brewfile=""
    platform_brewfile_optional=""
    if [[ "$(uname)" == "Darwin" ]]; then
        platform_brewfile="Brewfile.mac"
        platform_brewfile_optional="Brewfile.optional.mac"
    elif [[ "$(uname)" == "Linux" ]]; then
        platform_brewfile="Brewfile.linux"
        platform_brewfile_optional="Brewfile.optional.linux"
    fi

    # Brewfileから依存パッケージをインストール
    if [[ -f "$platform_brewfile" ]]; then
        info "Installing dependencies from $platform_brewfile"
        brew bundle --file="$platform_brewfile"
    else
        warning "$platform_brewfile not found. Skipping dependency installation."
    fi

    # Brewfile.optionalを処理
    if [[ -f "$platform_brewfile_optional" ]]; then
        info "Installing optional dependencies from $platform_brewfile_optional"
        read -rp "Install optional dependencies? [y/n]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            brew bundle --file="$platform_brewfile_optional"
            success "Installed optional dependencies."
        else
            info "Skipped optional dependencies."
        fi
    else
        warning "$platform_brewfile_optional not found."
    fi

    # fzfを設定
    echo -e
    info "Configuring fzf"
    if ! [[ -d "$(brew --prefix)/opt/fzf" ]]; then
        warning "fzf is not installed. Skipping configuration."
    else
        fzf_zsh="$HOME/.fzf.zsh"
        if [[ -f "$fzf_zsh" ]]; then
            info "$fzf_zsh already exists. Skipping configuration."
        else
            "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
            success "fzf configured successfully."
        fi
    fi
}

unset_homebrew() {
    # BrewfileとBrewfile.optionalのアンインストール共通処理
    uninstall_from_brewfile() {
        local brewfile=$1
        if [[ -f "$brewfile" ]]; then
            info "Uninstalling dependencies from $brewfile in reverse order."

            # ファイルの内容を逆順で処理
            tail -r "$brewfile" | while read -r line; do
                # コメント行や空行をスキップ
                [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

                # `brew` または `cask` のみを処理
                if [[ "$line" =~ ^brew ]]; then
                    package=$(echo "$line" | awk '{print $2}')
                    info "Uninstalling package: $package"
                    brew uninstall --force "$package"
                    success "Uninstalled $package"
                elif [[ "$line" =~ ^cask ]]; then
                    app=$(echo "$line" | awk '{print $2}')
                    info "Uninstalling cask: $app"
                    brew uninstall --cask --force "$app"
                    success "Uninstalled $app"
                fi
            done
        else
            warning "$brewfile not found. Skipping."
        fi
    }

    # BrewfileとBrewfile.optionalのパスを設定
    platform_brewfile=""
    platform_brewfile_optional=""
    if [[ "$(uname)" == "Darwin" ]]; then
        platform_brewfile="Brewfile.mac"
        platform_brewfile_optional="Brewfile.optional.mac"
    elif [[ "$(uname)" == "Linux" ]]; then
        platform_brewfile="Brewfile.linux"
        platform_brewfile_optional="Brewfile.optional.linux"
    fi

    # Brewfile.optionalの処理
    uninstall_from_brewfile "$platform_brewfile_optional"

    # Brewfileの処理
    uninstall_from_brewfile "$platform_brewfile"

    # fzfの設定ファイルを削除
    info "Checking for fzf configuration"
    fzf_zsh="$HOME/.fzf.zsh"
    if [[ -f "$fzf_zsh" ]]; then
        info "Removing $fzf_zsh"
        rm -f "$fzf_zsh"
        success "Removed $fzf_zsh."
    else
        info "$fzf_zsh does not exist... Skipping."
    fi
}

# Setup system preferences
setup_defaults() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Finder: set default view as \"list\""
        #Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
        defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
        echo "Finder: enable showing all file extensions"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        echo "Finder: show hidden files by default"
        defaults write com.apple.Finder AppleShowAllFiles -bool false
        # Set Terminal.app to use UTF-8 encoding exclusively (Terminal.appでUTF-8を使用)
        echo "Terminal: only use UTF-8"
        defaults write com.apple.terminal StringEncodings -array 4
        # Expand save dialog by default (保存ダイアログをデフォルトで拡張)
        echo "Finder: expand save dialog by default"
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
        echo "Finder: show the ~/Library folder"
        chflags nohidden ~/Library
        echo "Disable dictation shortcut"
        defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 1
        echo "Enable subpixel font rendering on non-Apple LCDs"
        defaults write NSGlobalDomain AppleFontSmoothing -int 2
        echo "Use current directory as default search scope in Finder"
        defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
        echo "Finder: Show Path bar"
        defaults write com.apple.finder ShowPathbar -bool true
        echo "Finder: Show Status bar"
        defaults write com.apple.finder ShowStatusBar -bool true
        echo "Disable press-and-hold for keys in favor of key repeat"
        defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
        echo "Set a blazingly fast keyboard repeat rate"
        defaults write NSGlobalDomain KeyRepeat -int 2
        echo "Set a shorter Delay until key repeat"
        defaults write NSGlobalDomain InitialKeyRepeat -int 15
        echo "Enable tap to click (Trackpad)"
        defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
        defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
        echo "Enable Safari’s debug menu"
        defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
        echo "Finder: Show fullpath on title bar"
        defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
        echo "Disable RichText in TextEdit"
        defaults write com.apple.TextEdit RichText -int 0
        echo "Disable Quarantine for unknown app"
        defaults write com.apple.LaunchServices LSQuarantine -bool false
        echo "Disable crash report"
        defaults write com.apple.CrashReporter DialogType -string "none"
        echo "Disable auto open download file"
        defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
        echo "Enable text selection on quick look"
        defaults write com.apple.finder QLEnableTextSelection -bool true
        echo "Disable generate DS_Store file on external storage"
        defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
        echo "Disable automatically rearrange Spaces based on most recent use"
        defaults write com.apple.dock mru-spaces -bool false
        echo "Enable Put display to Sleep in hot corner -bottom-left"
        defaults write com.apple.dock wvous-bl-corner -int 10
        defaults write com.apple.dock wvous-bl-modifer -int 0
        echo "Set the icon size of Dock items to 36 pixels"
        defaults write com.apple.dock tilesize -int 36
        echo "Enable Automatically hide & show menubar"
        defaults write -g _HIHideMenuBar -bool true
        echo "Enable Automatically hide & show dock"
        defaults write com.apple.dock autohide -bool true
        echo "Disable recent apps in dock"
        defaults write com.apple.dock recent-apps -bool false
        echo "Enable three finger drag"
        defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
        defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
        echo "Disable desktop switching animation"
        defaults write com.apple.dock expose-animation-duration -float 0.1
        # Shortcut
        # https://apple.stackexchange.com/questions/201816/how-do-i-change-mission-control-shortcuts-from-the-command-line
        # https://apple.stackexchange.com/questions/344494/how-to-disable-default-mission-control-shortcuts-in-terminal
        #
        #echo "Keyboard shortcut Misshon Control: Move left/right a space ctrl+alt+<-/->"
        #defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 79 "{
        #  enabled = 1; value = { parameters = (65535, 123, 11272192); type = standard; };
        #}"
        #defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 80 "{
        #  enabled = 1; value = { parameters = (65535, 123, 11403264); type = standard; };
        #}"
        #defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 81 "{
        #  enabled = 1; value = { parameters = (65535, 124, 11272192); type = standard; };
        #}"
        #defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 82 "{
        #  enabled = 1; value = { parameters = (65535, 124, 11403264); type = standard; };
        #}"
        for app in Safari Finder Dock Mail SystemUIServer; do killall "$app" >/dev/null 2>&1; done
    else
        warning "macOS not detected. Skipping."
    fi
}

unset_defaults() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Reset Finder’s default view mode to system default"
        defaults delete com.apple.finder FXPreferredViewStyle
        echo "Reset file extension visibility setting to system default"
        defaults delete NSGlobalDomain AppleShowAllExtensions
        echo "Reset hidden files visibility in Finder to system default"
        defaults delete com.apple.Finder AppleShowAllFiles
        echo "Reset Terminal.app encoding settings to system default"
        defaults delete com.apple.terminal StringEncodings
        echo "Reset save dialog expansion setting to system default"
        defaults delete NSGlobalDomain NSNavPanelExpandedStateForSaveMode
        echo "Hide the ~/Library folder in Finder"
        chflags hidden ~/Library
        echo "Reset dictation shortcut to system default"
        defaults delete com.apple.HIToolbox AppleDictationAutoEnable
        echo "Reset subpixel font rendering setting to system default"
        defaults delete NSGlobalDomain AppleFontSmoothing
        echo "Reset Finder's default search scope to system default"
        defaults delete com.apple.finder FXDefaultSearchScope
        echo "Finder: Reset Path bar visibility to system default"
        defaults delete com.apple.finder ShowPathbar
        echo "Finder: Reset Status bar visibility to system default"
        defaults delete com.apple.finder ShowStatusBar
        echo "Reset press-and-hold for keys to system default"
        defaults delete NSGlobalDomain ApplePressAndHoldEnabled
        echo "Reset keyboard repeat rate to system default"
        defaults delete NSGlobalDomain KeyRepeat
        echo "Reset initial key repeat delay to system default"
        defaults delete NSGlobalDomain InitialKeyRepeat
        echo "Reset tap to click setting to system default"
        defaults delete com.apple.AppleMultitouchTrackpad Clicking
        defaults delete com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking
        echo "Reset Safari debug menu visibility to system default"
        defaults delete com.apple.Safari IncludeInternalDebugMenu
        echo "Reset fullpath visibility on title bar to system default"
        defaults delete com.apple.finder _FXShowPosixPathInTitle
        echo "Reset TextEdit to use RichText by default"
        defaults delete com.apple.TextEdit RichText
        echo "Reset Quarantine setting for unknown apps to system default"
        defaults delete com.apple.LaunchServices LSQuarantine
        echo "Reset crash report dialog to system default"
        defaults delete com.apple.CrashReporter DialogType
        echo "Reset Safari auto-open downloads setting to system default"
        defaults delete com.apple.Safari AutoOpenSafeDownloads
        echo "Reset text selection on Quick Look to system default"
        defaults delete com.apple.finder QLEnableTextSelection
        echo "Reset DS_Store generation setting to system default"
        defaults delete com.apple.desktopservices DSDontWriteNetworkStores
        echo "Reset Spaces auto-rearrange setting to system default"
        defaults delete com.apple.dock mru-spaces
        echo "Reset hot corner bottom-left action to system default"
        defaults delete com.apple.dock wvous-bl-corner
        defaults delete com.apple.dock wvous-bl-modifer
        echo "Reset Dock item icon size to system default"
        defaults delete com.apple.dock tilesize
        echo "Reset menubar auto-hide setting to system default"
        defaults delete -g _HIHideMenuBar
        echo "Reset Dock auto-hide setting to system default"
        defaults delete com.apple.dock autohide
        echo "Reset recent apps in Dock visibility to system default"
        defaults delete com.apple.dock recent-apps
        echo "Reset three-finger drag setting to system default"
        defaults delete com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag
        defaults delete com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag
        echo "Reset desktop switching animation speed to system default"
        defaults delete com.apple.dock expose-animation-duration
        #
        for app in Safari Finder Dock Mail SystemUIServer; do killall "$app" >/dev/null 2>&1; done
    else
        warning "macOS not detected. Skipping."
    fi
}

setup_shell() {
    [[ -n "$(command -v brew)" ]] && zsh_path="$(brew --prefix)/bin/zsh" || zsh_path="$(which zsh)"
    if [[ "$(uname)" == "Darwin" ]]; then
      if ! grep "$zsh_path" /etc/shells; then
          info "adding $zsh_path to /etc/shells"
          echo "$zsh_path" | sudo tee -a /etc/shells
      fi

      if [[ "$SHELL" != "$zsh_path" ]]; then
          chsh -s "$zsh_path"
          info "default shell changed to $zsh_path"
      fi
    else
      if [[ "$SHELL" != "$zsh_path" ]]; then
          info "default shell changed to $zsh_path"
          cat <<_EOT_>> $HOME/.bash_profile
if [ -x "$zsh_path" ]; then
  export SHELL=$zsh_path
  exec $SHELL -l
fi
_EOT_
      fi
    fi
}

unset_shell() {
    # Brewのzshパスを確認
    local zsh_path
    [[ -n "$(command -v brew)" ]] && zsh_path="$(brew --prefix)/bin/zsh" || zsh_path="$(which zsh)"

    if [[ "$(uname)" == "Darwin" ]]; then
        # /etc/shellsからzshのパスを削除
        if grep -Fxq "$zsh_path" /etc/shells; then
            info "Removing $zsh_path from /etc/shells"
            escaped_path=$(printf '%s\n' "$zsh_path" | sed 's:/:\\/:g')  # スラッシュをエスケープ
            sudo sed -i '' "/$escaped_path/d" /etc/shells
            success "$zsh_path removed from /etc/shells."
        else
            info "$zsh_path is not in /etc/shells... Skipping."
        fi

        # デフォルトシェルをシステムのデフォルトに戻す
        default_shell="$(dscl . -read /Users/$(whoami) UserShell | awk '{print $2}')"
        if [[ "$SHELL" == "$zsh_path" ]]; then
            chsh -s "$default_shell"
            success "Default shell reverted to $default_shell."
        else
            info "Default shell is not $zsh_path... Skipping."
        fi
    else
        # Linux: .bash_profileから設定を削除
        local bash_profile="$HOME/.bash_profile"
        if [[ -f "$bash_profile" ]]; then
            if grep -q "export SHELL=$zsh_path" "$bash_profile"; then
                info "Removing zsh configuration from $bash_profile"
                sed -i "/export SHELL=$zsh_path/d" "$bash_profile"
                sed -i "/exec \\$SHELL -l/d" "$bash_profile"
                success "Removed zsh configuration from $bash_profile."
            else
                info "No zsh configuration found in $bash_profile... Skipping."
            fi
        else
            info "$bash_profile does not exist... Skipping."
        fi
    fi
}

setup_terminfo() {
    # tmux.terminfo の登録
    info "Adding tmux.terminfo"
    if tic -x "$DOTFILES/resources/tmux.terminfo"; then
        success "Added tmux.terminfo."
    else
        warning "Failed to add tmux.terminfo."
    fi

    # xterm-256color-italic.terminfo の登録
    info "Adding xterm-256color-italic.terminfo"
    if tic -x "$DOTFILES/resources/xterm-256color-italic.terminfo"; then
        success "Added xterm-256color-italic.terminfo."
    else
        warning "Failed to add xterm-256color-italic.terminfo."
    fi

}

unset_terminfo() {
    terminfo_dir="$HOME/.terminfo"

    if [[ -d "$terminfo_dir" ]]; then
        read -rp "Are you sure you want to remove the entire ~/.terminfo directory? [y/n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$terminfo_dir"
            success "~/.terminfo directory has been removed."
        else
            info "Operation cancelled. ~/.terminfo directory remains unchanged."
        fi
    else
        info "~/.terminfo directory does not exist... Skipping."
    fi
}

# 引数を解析し、install または uninstall を判断する
main() {
    # 引数がない場合はヘルプを表示
    if [ $# -lt 1 ]; then
        show_usage
    fi

    # オプションの初期化
    local undo=false
    local command

    # 引数解析
    while [ $# -gt 0 ]; do
        case "$1" in
            -u)
                undo=true
                shift
                ;;
            symlink|git|homebrew|defaults|shell|terminfo)
                command="$1"
                shift
                ;;
            *)
                show_usage
                ;;
        esac
    done

    # コマンドが指定されていない場合はヘルプを表示
    if [ -z "$command" ]; then
        show_usage
    fi

    # コマンド実行
    case "$command" in
        symlink)
            if [ "$undo" = true ]; then
                title "Removing symlinks"
                unset_symlinks
            else
                title "Creating symlinks"
                setup_symlinks
            fi
            ;;
        git)
            if [ "$undo" = true ]; then
                title "Removing Git setup"
                unset_git
            else
                title "Setting up Git"
                setup_git
            fi
            ;;
        homebrew)
            if [ "$undo" = true ]; then
                title "Removing Homebrew setup"
                unset_homebrew
            else
                title "Setting up Homebrew"
                setup_homebrew
            fi
            ;;
        defaults)
            if [ "$undo" = true ]; then
                title "Removing system preferences setup"
                unset_defaults
            else
                title "Setting up system preferences"
                setup_defaults
            fi
            ;;
        shell)
            if [ "$undo" = true ]; then
                title "Removing shell configuration"
                unset_shell
            else
                title "Configuring shell"
                setup_shell
            fi
            ;;
        terminfo)
            if [ "$undo" = true ]; then
                title "Removing terminfo configuration"
                unset_terminfo
            else
                title "Configuring terminfo"
                setup_terminfo
            fi
            ;;
        *)
            show_usage
            ;;
    esac
}

main "$@"
