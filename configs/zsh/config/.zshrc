# ============================================================
#
#    ███████╗███████╗██╗  ██╗██████╗  ██████╗
#    ╚══███╔╝██╔════╝██║  ██║██╔══██╗██╔════╝
#      ███╔╝ ███████╗███████║██████╔╝██║     
#     ███╔╝  ╚════██║██╔══██║██╔══██╗██║     
# ██╗███████╗███████║██║  ██║██║  ██║╚██████╗
# ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝
#
#  Project  : YAY Installer
#  Purpose  : Install package manager.
#  Author   : nebolsinvasili
#  Repo     : https://github.com/nebolsinvasili/dotfiles.git
#
#  License  : GPL-3.0
#  Created  : 2021
#  Updated  : 2025-03-24
#
# ============================================================

# =========================== VARS ===========================
export PATH="$HOME/.local/bin:$HOME/.bin:$PATH"
export EDITOR="nvim"
export VISUAL="${EDITOR}"
export GIT_EDITOR="${EDITOR}"

export BROWSER='firefox'
export HISTORY_IGNORE="(ls|cd|pwd|exit|sudo reboot|history|cd -|cd ..)"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

export DOTFILES="$HOME/dotfiles"

if [ -d "$HOME/.local/bin" ] ;
  then PATH="$HOME/.local/bin:$PATH"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add Oh-My-ZSH plugins with snippets
#zinit snippet OMZL::git.zsh
#zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::colored-man-pages
#zinit snippet OMZP::colorize
#zinit snippet OMZP::pyenv
#zinit snippet OMZP::poetry-env
#zinit snippet OMZP::docker
#zinit snippet OMZP::docker-compose
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# History
HISTFILE=~/.config/zsh/zhistory
HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTDUP=erase
HIST_STAMPS="yyyy-mm-dd"
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups


# # Completion styling
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
# zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# zstyle ':completion:*' menu no
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
# zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
#
# # Shell integrations
# eval "$(fzf --zsh)"
# eval "$(zoxide init --cmd cd zsh)"

# --- НАСТРОЙКИ АВТОДОПОЛНЕНИЯ (ZSTYLE) ---
# Регистронезависимое автодополнение (apple -> Apple)
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Цвета для списка автодополнения из системных настроек LS_COLORS
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Отключение стандартного меню Zsh для корректной работы fzf-tab
zstyle ':completion:*' menu no


# --- ИНТЕГРАЦИЯ FZF-TAB И ПРЕВЬЮ ---
# Настройка отображения превью для cd и zoxide
# Если установлен eza — используется он, иначе — стандартный ls
zstyle ':fzf-tab:complete:cd:*' fzf-preview '
  if command -v eza &>/dev/null; then
    eza -1 --icons --color=always "$realpath"
  else
    ls -1 --color=always "$realpath"
  fi
'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview '
  if command -v eza &>/dev/null; then
    eza -1 --icons --color=always "$realpath"
  else
    ls -1 --color=always "$realpath"
  fi
'

# Превью для ЛЮБЫХ команд (показывает содержимое файлов через bat или папок через eza)
zstyle ':fzf-tab:complete:*' fzf-preview '
  if [ -d "$realpath" ]; then
    command -v eza &>/dev/null && eza -1 --icons --color=always "$realpath" || ls -1 --color=always "$realpath"
  elif [ -f "$realpath" ]; then
    command -v bat &>/dev/null && bat --style=numbers --color=always --line-range :50 "$realpath" || head -n 50 "$realpath"
  fi
'

# Переключение фокуса на окно превью по нажатию '/'
zstyle ':fzf-tab:*' switch-group '/'


# --- ШЕЛЛ-ИНТЕГРАЦИИ И ОПТИМИЗАЦИЯ ПЕРЕМЕННЫХ ---
# Настройка fzf: использовать fd для поиска (игнорирует .git, ищет скрытые файлы)
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Инициализация fzf
eval "$(fzf --zsh)"

# Инициализация zoxide (заменяет cd)
eval "$(zoxide init --cmd cd zsh)"


source "$XDG_CONFIG_HOME/zsh/aliases.zsh"
source "$XDG_CONFIG_HOME/zsh/functions.zsh"
source "$XDG_CONFIG_HOME/zsh/prompt-bash.zsh"
# ------ PYENV ------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
# ------ PYENV ------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
# ------ PYENV ------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
# ------ PYENV ------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

. "$HOME/.local/share/../bin/env"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/nebolsinvasili/.lmstudio/bin"
# End of LM Studio CLI section

