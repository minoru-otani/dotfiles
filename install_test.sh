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
    echo -e $"\nUsage: $(basename "$0") [-u] {symlink|git|homebrew}\n"
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

    # Brewfileから依存パッケージをインストール
    info "Installing dependencies from Brewfile"
    if [[ -f "Brewfile" ]]; then
        brew bundle --file=Brewfile
    else
        warning "Brewfile not found. Skipping dependency installation."
    fi

    # Brewfile.optionalを処理（存在する場合）
    info "Installing optional dependencies from Brewfile.optional"
    if [[ -f "Brewfile.optional" ]]; then
        read -rp "Install optional dependencies? [y/n]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            brew bundle --file=Brewfile.optional
            success "Installed optional dependencies."
        else
            info "Skipped optional dependencies."
        fi
    else
        warning "Brewfile.optional not found."
    fi

    # fzfをインストール
    echo -e
    info "Installing fzf"
    if [[ -d "$(brew --prefix)/opt/fzf" && -f "$HOME/.fzf.zsh" ]]; then
        info "fzf is already installed and configured... Skipping."
    else
        "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
        success "fzf installed successfully."
    fi
}

unset_homebrew() {
    # 逆順アンインストールの共通処理
    uninstall_from_brewfile() {
        local brewfile=$1
        if [[ -f "$brewfile" ]]; then
            info "Uninstalling dependencies from $brewfile in reverse order."

            # catの逆のtacコマンドでBrewfileを下から読む
            tac "$brewfile" | while read -r line; do
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

    # BrewfileとBrewfile.optionalを処理
    uninstall_from_brewfile "Brewfile"
    #uninstall_from_brewfile "Brewfile.optional"

    # fzfのアンインストール
    info "Checking for fzf installation"
    if [[ -d "$(brew --prefix)/opt/fzf" ]]; then
        info "Uninstalling fzf..."
        brew uninstall --force fzf
        success "fzf has been uninstalled."
    
        # .fzf.zshの削除
        fzf_zsh="$HOME/.fzf.zsh"
        if [[ -f "fzf_zsh" ]]; then
            info "Removing $fzf_zsh"
            rm -f "$fzf_zsh"
            success "Removed $fzf_zsh."
        else
            info "$fzf_zsh does not exist... Skipping."
        fi
    else
        info "fzf is not installed... Skipping."
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
            symlink|git|homebrew)
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
        *)
            show_usage
            ;;
    esac
}

main "$@"
