# ~/.zshrc - Arch Linux / Hyprland

setopt promptsubst
# --- Path ---
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# --- Word behavior ---
WORDCHARS=${WORDCHARS//\/}
PROMPT_EOL_MARK=""

# --- Completion ---
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify

# --- Prompt ---
VIRTUAL_ENV_DISABLE_PROMPT=1

#PS1='%F{93}%B%n %F{52}%~%b%f %F{46}❯%f '
#PROMPT=$'%F{93}┌──${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{93}%n@%m%b%F{93})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{93}]\n└─%B%(#.%F{red}#.%F{93}$)%b%F{reset} '
#PROMPT=$'%F{46}┌─${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}[%B%F{93}%(6~.%-1~/…/%4~.%5~)%b%F{46}]\n└─%(#.%F{red}#.%F{46}❯)%b%F{reset} '
PROMPT=$'%F{46}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}%F{93}[%B%(6~.%-1~/…/%4~.%5~)%b]%F{46}\n%(#.%F{red}#.%F{46} ❯)%b%F{reset} '

# Terminal title
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;%n@%m: %~\a'
    ;;
esac

# Newline before prompt (except first)
precmd() {
    print -Pnr -- "$TERM_TITLE"
    if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
        _NEW_LINE_BEFORE_PROMPT=1
    else
        print ""
    fi
}

# --- Colors for ls, less, man ---
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:"
fi

export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;33m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'
export LESS_TERMCAP_ue=$'\E[0m'

TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# --- Aliases ---
alias history="history 0"
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'
alias as='/home/ashep/bin/sshserver'
alias fuz='nvim $(fzf --preview="cat {}")'
alias fuzm='nvim $(fzf -m --preview="cat {}")'
alias ssha='eval $(ssh-agent) && ssh-add /home/ashep/.ssh/ansible'
alias py='python3'
alias dolphin='dolphin -stylesheet ~/.config/stylesheet.qss'
alias portfolio='. /home/ashep/.config/wbstat/env && wbstat'

# --- Plugins ---
# Syntax highlighting
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
    ZSH_HIGHLIGHT_STYLES[default]=none
    ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
    ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=red,bold
    ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
    ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[path]=bold
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[command-substitution]=none
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[process-substitution]=none
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[assign]=none
    ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
    ZSH_HIGHLIGHT_STYLES[named-fd]=none
    ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
    ZSH_HIGHLIGHT_STYLES[arg0]=fg=46
    ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
    ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
    ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
    ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
    ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
    ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
fi

# Autosuggestions
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#242'
fi

# --- Word selection widgets ---
autoload -Uz select-word-style
select-word-style bash

MARK_SET=0

function extend-selection-backward-word() {
  if [[ $MARK_SET -eq 0 ]]; then
    zle set-mark-command
    MARK_SET=1
  fi
  zle backward-word
}
zle -N extend-selection-backward-word

function extend-selection-forward-word() {
  if [[ $MARK_SET -eq 0 ]]; then
    zle set-mark-command
    MARK_SET=1
  fi
  zle forward-word
}
zle -N extend-selection-forward-word

function reset-selection-mark-flag() {
  MARK_SET=0
  zle .accept-line
}
zle -N reset-selection-mark-flag

function cancel-region() {
  MARK_SET=0
  REGION_ACTIVE=""
  zle exchange-point-and-mark
}
zle -N cancel-region

bindkey '^[[1;6D' extend-selection-backward-word   # Ctrl+Shift+←
bindkey '^[[1;6C' extend-selection-forward-word    # Ctrl+Shift+→
bindkey '^M' reset-selection-mark-flag             # Enter resets mark
bindkey '\e' cancel-region                         # Escape clears mark
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
# --- fzf ---
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- OpenClaw ---
# source "/home/ashep/.openclaw/completions/openclaw.zsh"

export LS_COLORS='di=1;38;5;93:ln=36:ex=32:*.tar=31:*.zip=31:*.jpg=35:ex=1;38;5;46:*.png=35:*.3mf=38;5;208:*.stl=38;5;209:*.py=38;5;220'
