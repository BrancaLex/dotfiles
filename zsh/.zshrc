# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
#

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting web-search gh docker history copypath extract archlinux fzf copyfile copybuffer dirhistory kitty sudo tmux  zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
export EDITOR='lv'
# fi
#
export XCURSOR_THEME=Breeze
export XCURSOR_SIZE=24
export TERMINAL=ghostty

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#source /opt/ros/jazzy/setup.zsh
#source /home/alessandro-biagio-branca/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# Alias per il cambio layout tastiera
alias it='setxkbmap it && echo "Layout impostato: ITALIANO"'
alias us='setxkbmap us && echo "Layout impostato: AMERICANO"'
alias v='nvim'
alias black='xset dpms force off'
alias matlab='/usr/local/MATLAB/R2025b/bin/matlab -desktop'
alias l='eza -la --icons'
alias t='tmux'
alias nvcp='nvim "$(kitten choose_files)"'
alias cl='clear'
alias lv='NVIM_APPNAME=lazyvim nvim'
alias ml='/home/ale/.local/bin/matlab'
alias db='distrobox'
export PATH="$HOME/.local/bin:$PATH"

# Avvia Redshift in background per Reggio Emilia
# Avvia Redshift solo se non è già in esecuzione
if ! pgrep -x "redshift" > /dev/null; then
    (redshift -l 44.70:10.63 &> /dev/null &)
fi

eval "$(oh-my-posh init zsh --config '/home/ale/Documents/Themes/OMP/pywal.omp.json')"


bindkey -v


export KEYTIMEOUT=1


function zle-keymap-select {
  VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]% %{$reset_color%}"
  RPROMPT="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/} $EPSSTR"
  zle reset-prompt
}
zle -N zle-keymap-select

fastfetch

# Migliora contrasto evidenziatore di sintassi
# Forza l'uso dei colori 'bright' della palette
ZSH_HIGHLIGHT_STYLES[command]='fg=color12,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=color13,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=color14'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=color11,bold'
export VISUAL='nvim'

# Start gnome-keyring-daemon
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(gnome-keyring-daemon --start --components=secrets)
    export GNOME_KEYRING_CONTROL
    export GNOME_KEYRING_PID
    export GPG_AGENT_INFO
    export SSH_AUTH_SOCK
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# opencode
export PATH=/home/ale/.opencode/bin:$PATH

# bun completions
[ -s "/home/ale/.bun/_bun" ] && source "/home/ale/.bun/_bun"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export NVD_BACKEND=direct
# Profilo GPU dal MUX (vedi gpu-profile.sh / config.fish).
if [[ -x ~/.config/hypr/scripts/gpu-profile.sh ]]; then
	while IFS='=' read -r k v; do export "$k=$v"; done < <(~/.config/hypr/scripts/gpu-profile.sh env)
else
	export LIBVA_DRIVER_NAME=radeonsi VDPAU_DRIVER=radeonsi
fi
# NON reintrodurre MESA_LOADER_DRIVER_OVERRIDE=radeonsi: se zsh torna a essere la login
# shell, Hyprland eredita la variabile e il blit multi-GPU verso l'HDMI sulla dGPU
# fallisce (monitor esterno nero). Stessa motivazione documentata in config.fish.
export WOKWI_CLI_TOKEN=wok_1oILPdXlQysKbvDFAwnMMjhWboELo3oM928fbeee


eval "$(zoxide init zsh)"


# ESP-IDF environment (v6.0.1)
alias get_idf='. /home/ale/.espressif/v6.0.1/esp-idf/export.sh'


# Added by Antigravity CLI installer
export PATH="/home/ale/.local/bin:$PATH"
