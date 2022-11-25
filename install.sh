#!/usr/bin/env bash

DOTFILES="$(pwd)"
COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"

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

get_linkables() {
  find -H "$DOTFILES" ! \( -path "${DOTFILES}/worktree" -prune \) -maxdepth 3 -name '*.symlink'
  # "" 挟まれた文字列を評価・展開されて文字列として返す
  # ! で否定する。-notでも良い。
  # \(\)とカッコで囲って先に優先的に評価させる。「優先的」に関しては、
  # https://www.putorius.net/linux-find-command.htmlの"Force precedence operator"を参照
}

backup() {
    BACKUP_DIR=$HOME/dotfiles-backup

    echo "Creating backup directory at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    for file in $(get_linkables); do
        filename=".$(basename "$file" '.symlink')"
        target="$HOME/$filename"
        if [ -f "$target" ]; then
            echo "backing up $filename"
            cp "$target" "$BACKUP_DIR"
        else
            warning "$filename does not exist at this location or is a symlink"
        fi
    done

    for filename in "$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc"; do
        # ! 終了ステータスを反転させる
        if [ ! -L "$filename" ]; then
            echo "backing up $filename"
            cp -rf "$filename" "$BACKUP_DIR"
        else
            warning "$filename does not exist at this location or is a symlink"
        fi
    done
}


setup_symlinks() {
    title "Creating symlinks"

    for file in $(get_linkables) ; do
        # $() コマンド置換。括弧で囲んだ文字列はコマンドとして実行され、標準出力が文字列として返す
        target="$HOME/.$(basename "$file" '.symlink')"
        # basenameでパス付きファイル名を取り出し、.symlinkという接尾辞を取り除く
        if [[ -e "$target" ]]; then
            info "~${target#$HOME} already exists... Skipping."
            # ${name#pattern} nameの先頭がpatternにマッチした場合、マッチした部分を削除した状態で文字列を返す
        else
            info "Creating symlink for $file"
            ln -s "$file" "$target"
        fi
    done

    echo -e
    info "installing to ~/.config"
    if [[ ! -d "$HOME/.config" ]]; then
        info "Creating ~/.config"
        mkdir -p "$HOME/.config"
    fi

    config_files=$(find "$DOTFILES/config" -mindepth 1 -maxdepth 1 2>/dev/null)
    for config in $config_files; do
        target="$HOME/.config/$(basename "$config")"
        if [[ -e "$target" ]]; then
            # ${parameter#word} wordに一致する前方の文字を削除
            info "~${target#$HOME} already exists... Skipping."
        else
            info "Creating symlink for $config"
            ln -s "$config" "$target"
        fi
    done

    if [[ "$(uname)" == "Darwin" ]]; then
      target="${HOME}/.zshrc.local"
      if [[ -e "$target" ]]; then
        info "~${target#$HOME} already exists... Skipping."
      else
        info "Creating symlink for $target"
        ln -s "$DOTFILES/zsh/zshrc.local.mac" "$target"
      fi
    else
      if [[ -e "$target" ]]; then
        info "~${target#$HOME} already exists... Skipping."
      else
        info "Creating symlink for $target"
        ln -s "$DOTFILES/zsh/zshrc.local.linux" "$target"
      fi
    fi
}

setup_git() {
    title "Setting up Git"

    defaultName=$(git config user.name)
    defaultEmail=$(git config user.email)
    defaultGithub=$(git config github.user)

    read -rp "Name [$defaultName] " name
    read -rp "Email [$defaultEmail] " email
    read -rp "Github username [$defaultGithub] " github

    git config -f ~/.gitconfig-local user.name "${name:-$defaultName}"
    git config -f ~/.gitconfig-local user.email "${email:-$defaultEmail}"
    git config -f ~/.gitconfig-local github.user "${github:-$defaultGithub}"

    if [[ "$(uname)" == "Darwin" ]]; then
        git config --global credential.helper "osxkeychain"
    else
        read -rn 1 -p "Save user and password to an unencrypted file to avoid writing? [y/N] " save
        if [[ $save =~ ^([Yy])$ ]]; then
            git config --global credential.helper "store"
        else
            git config --global credential.helper "cache --timeout 3600"
        fi
    fi
}

setup_homebrew() {
    title "Setting up Homebrew"

    if test ! "$(command -v brew)"; then
        info "Homebrew not installed. Installing."
        # Run as a login shell (non-interactive) so that the script doesn't pause for user input
        #curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi

    if [ "$(uname)" == "Linux" ]; then
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        #bashは汚染したくないので、何も加えない。
        #test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.bash_profile
    fi

    # install brew dependencies from Brewfile
    brew bundle

    # install fzf
    echo -e
    info "Installing fzf"
    "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

setup_shell() {
    title "Configuring shell"

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

function setup_terminfo() {
    title "Configuring terminfo"

    info "adding tmux.terminfo"
    tic -x "$DOTFILES/resources/tmux.terminfo"

    info "adding xterm-256color-italic.terminfo"
    tic -x "$DOTFILES/resources/xterm-256color-italic.terminfo"
}

setup_macos() {
    title "Configuring macOS"
    if [[ "$(uname)" == "Darwin" ]]; then
        #Finder
        echo "Finder: set default view as list"
        #Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
        defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
        echo "Finder: show all filename extensions"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        echo "show hidden files by default"
        defaults write com.apple.Finder AppleShowAllFiles -bool false
        echo "only use UTF-8 in Terminal.app"
        defaults write com.apple.terminal StringEncodings -array 4
        echo "expand save dialog by default"
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
        echo "show the ~/Library folder in Finder"
        chflags nohidden ~/Library
        #Preferences
        echo "Disable dictation shortcut"
        defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 1
        #echo "Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)"
        #defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
        echo "Enable subpixel font rendering on non-Apple LCDs"
        defaults write NSGlobalDomain AppleFontSmoothing -int 2
        echo "Use current directory as default search scope in Finder"
        defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
        echo "Show Path bar in Finder"
        defaults write com.apple.finder ShowPathbar -bool true
        echo "Show Status bar in Finder"
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
        echo "Kill affected applications"
        # See; https://ottan.jp/posts/2016/07/system-preferences-terminal-defaults-mission-control/
        echo "Show fullpath on title bar in Finder"
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
        # Dock & Menu bar
        echo "Set the icon size of Dock items to 36 pixels"
        defaults write com.apple.dock tilesize -int 36
        echo "Enable Automatically hide & show menubar"
        defaults write -g _HIHideMenuBar -bool true
        echo "Enable Automatically hide & show dock"
        defaults write com.apple.dock autohide -bool true
        # Trackpad
        echo "Enable three finger drag"
        defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
        defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
        echo "Disable desktop switching animation"
        defaults write com.apple.dock expose-animation-duration -float 0.1
        # Shortcut
        # https://apple.stackexchange.com/questions/201816/how-do-i-change-mission-control-shortcuts-from-the-command-line
        # https://apple.stackexchange.com/questions/344494/how-to-disable-default-mission-control-shortcuts-in-terminal
        echo "Keyboard shortcut Misshon Control: Move left/right a space ctrl+alt+<-/->"
        defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 79 "{
          enabled = 1; value = { parameters = (65535, 123, 11272192); type = standard; };
        }"
        defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 80 "{
          enabled = 1; value = { parameters = (65535, 123, 11403264); type = standard; };
        }"
        defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 81 "{
          enabled = 1; value = { parameters = (65535, 124, 11272192); type = standard; };
        }"
        defaults write ~/Library/Preferences/com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 82 "{
          enabled = 1; value = { parameters = (65535, 124, 11403264); type = standard; };
        }"

        for app in Safari Finder Dock Mail SystemUIServer; do killall "$app" >/dev/null 2>&1; done
    else
        warning "macOS not detected. Skipping."
    fi
}

case "$1" in
    backup)
        backup
        ;;
    link)
        setup_symlinks
        ;;
    git)
        setup_git
        ;;
    homebrew)
        setup_homebrew
        ;;
    shell)
        setup_shell
        ;;
    terminfo)
        setup_terminfo
        ;;
    macos)
        setup_macos
        ;;
    mac)
        setup_symlinks
        setup_terminfo
        setup_homebrew
        setup_shell
        setup_git
        setup_macos
        ;;
    linux)
      setup_symlinks
      setup_terminfo
      setup_homebrew
      setup_shell
      setup_git
      ;;
    *)
        echo -e $"\nUsage: $(basename "$0") {backup|link|git|homebrew|shell|terminfo|mac|linux}\n"
        exit 1
        ;;
esac

echo -e
success "Done."
