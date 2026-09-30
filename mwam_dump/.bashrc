# .bashrc
# TODO: Move out to new configs

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# User specific environment
PATH="$HOME/.local/bin:/usr/local/bin/:$PATH"
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
. "$HOME/.cargo/env"
alias ls="exa"
alias ll="ls -alh"
alias lg="ls -alh --git"
eval "$(zoxide init bash)"

. ~/.fzf/completion.bash
. ~/.fzf/key-bindings.bash

# add aliases for pr

# Avoid duplicates
HISTCONTROL=ignoredups:erasedups:ignorespace
# When the shell exits, append to the history file instead of overwriting it
shopt -s histappend
# After each command, append to the history file and reread it
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

# Set the maximum number of lines contained in the history file
HISTFILESIZE=10000

# Set the maximum number of commands to remember in the command history
HISTSIZE=1000

# jump
alias j=z

alias pbcopy="xclip -i -selection c"
alias pbpaste="xclip -o -selection c"
export PATH="/snap/bin:${PATH}"

function jjq {
    jq -R -r "${1:-.} as \$line | try fromjson catch \$line"
}

function nanos_to_date {
        if [ $# -eq 0 ]
        then
                while read line; do date --iso-8601=seconds -d "@${line%???}"; done
        else
                date --iso-8601=seconds -d "@${1%???}";
        fi
}

function seconds_to_date {
        if [ $# -eq 0 ]
        then
                while read line; do date --iso-8601=seconds -d "@$line"; done
        else
                date --iso-8601=seconds -d "@$1";
        fi
}

alias gfixup='git branch --set-upstream-to=origin/$(git rev-parse --abbrev-ref HEAD) $(git rev-parse --abbrev-ref HEAD)'

alias gbranchcleanup='git branch --merged master | grep -vE "master|dev" | xargs git branch -d'
gprunesquashmergedfun() {
        git checkout -q $1 && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do mergeBase=$(git merge-base $1 $branch) && [[ $(git cherry $1 $(git commit-tree $(git rev-parse "$branch^{tree}") -p $mergeBase -m _)) == "-"* ]] && git branch -D $branch; done
}
alias gprunesquashmerged='git checkout -q master && git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch; do mergeBase=$(git merge-base master $branch) && [[ $(git cherry master $(git commit-tree $(git rev-parse "$branch^{tree}") -p $mergeBase -m _)) == "-"* ]] && git branch -D $branch; done'
alias cdr='cd $(git rev-parse --show-toplevel)'
alias kcat_timestamp_to_iso8601="jq -c '.ts |= (. / 1000 | todateiso8601)'"

alias clipTopic='topic-fzf | pbcopy'

yaml_sort () { yq -o json . | jq -S . | yq -o yaml -P . ; }
sem_diff () {
    FILENAME1=$1
    FILENAME2=${2:-$1}
    diff -y \
        <(cat $FILENAME1 | yaml_sort) \
        <(cat $FILENAME2 | yaml_sort )
}

cf() {
        cd $(fzf)
}


alias gumr='git fetch origin && git rebase origin/master'

fgck() {
    # Check if inside a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not inside a git repository."
        return 1
    fi

    local tags branches target branch="$1"

    # If direct branch/tag name provided, checkout directly
    if [[ -n "$branch" ]]; then
        git checkout "$branch"
        return
    fi

    # Get branches with formatting and sorting
    branches=$(
        git --no-pager branch --all --sort=-committerdate \
        --format='%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)' \
        | sed '/^$/d'
    )

    # Get tags with formatting
    tags=$(
        git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}'
    )

    # Combine and select with fzf
    target=$(
        (echo "$branches"; echo "$tags") |
        fzf --no-hscroll --no-multi -n 2 \
            --height 80% \
            --border \
            --ansi \
            --preview='git log --oneline --graph --decorate --color=always {2}' \
            --preview-window=right:60%
    )

    # Early return if no selection
    [[ -z "$target" ]] && return

    # Extract the branch name and remove 'origin/' prefix if it exists
    local branch_name=$(echo "$target" | awk '{print $2}' | sed 's#^origin/##')

    # Checkout selected branch/tag
    git checkout "$branch_name"
}

killtree() {
    local _pid=$1
    for _child in $(pgrep -P $_pid); do
        killtree $_child
    done
    kill -9 $_pid
}