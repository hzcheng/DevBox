__devbox_git_branch() {
    local branch
    branch=$(git -C . rev-parse --abbrev-ref HEAD 2>/dev/null) || return
    printf ' (%s)' "$branch"
}
if [ -n "$BASH_VERSION" ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;33m\]$(__devbox_git_branch)\[\033[00m\]\n\$ '
fi
