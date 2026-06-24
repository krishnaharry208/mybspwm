# Git aliases
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate'
alias gb='git branch'
alias gsw='git switch'

# Commit with message
gcm() {
    git commit -m "$*"
}

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias ll='ls -lah'
