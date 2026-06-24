# ==============================================================================
#  ~/.bashrc - Interactive Bash Configuration (Modern Theme)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Guard Clauses & Shell Options
# ------------------------------------------------------------------------------
# Exit early if the shell is not running interactively
case $- in
    *i*) ;;
      *) return;;
esac

shopt -s histappend     # Append to the history file, don't overwrite it
shopt -s checkwinsize   # Update LINES and COLUMNS after each command
# shopt -s globstar     # Uncomment for recursive globbing (e.g., ls **)

# ------------------------------------------------------------------------------
# 2. Enhanced History Settings
# ------------------------------------------------------------------------------
HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:erasedups

# ------------------------------------------------------------------------------
# 3. Environment Variables & Diagnostics
# ------------------------------------------------------------------------------
# Identify the chroot environment (primarily for Debian/Ubuntu systems)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Enable colored GCC warnings
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# ------------------------------------------------------------------------------
# 4. Modern Prompt Theme (With Git Integration)
# ------------------------------------------------------------------------------
# Color Definitions (256-color palette)
RESET="\[\e[0m\]"
BLUE="\[\e[38;5;39m\]"
CYAN="\[\e[38;5;51m\]"
GREEN="\[\e[38;5;82m\]"
YELLOW="\[\e[38;5;220m\]"
PURPLE="\[\e[38;5;141m\]"
RED="\[\e[38;5;196m\]"
GRAY="\[\e[38;5;245m\]"

# Git branch parser helper function
parse_git_branch() {
    git branch 2>/dev/null | sed -n '/\* /s///p'
}

# Constructing the two-line modern prompt
PS1="${BLUE}╭─${GREEN}\u${GRAY}@${CYAN}\h ${YELLOW}\w"
PS1+='$(git_branch=$(parse_git_branch); if [ -n "$git_branch" ]; then printf " '"${PURPLE}"'[%s]" "$git_branch"; fi)'
PS1+="\n${BLUE}╰─❯ ${RESET}"

# Set the window title for xterm/rxvt terminals
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
esac

# ------------------------------------------------------------------------------
# 5. Core Aliases & Color Support
# ------------------------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    
    # Core command colors
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Advanced File Listing
alias ll='ls -lah --color=auto'
alias la='ls -A'
alias l='ls -CF'

# Directory Navigation Shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# System Shortcuts
alias c='clear'
alias h='history'

# Git Productivity Shortcuts
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Load custom external aliases if the file exists
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ------------------------------------------------------------------------------
# 6. Programmable Completion
# ------------------------------------------------------------------------------
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ------------------------------------------------------------------------------
# 7. System Information Fetch
# ------------------------------------------------------------------------------
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi