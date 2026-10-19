# Convert Unix timestamps in seconds, milliseconds, microseconds, or
# nanoseconds to ISO 8601. The unit is inferred from the digit count.
#
# Usage:
#   unix_to_date 1759330800
#   unix_to_date 1759330800000
#   printf '%s\n' 1759330800 1759330800000 | unix_to_date
unix_to_date() {
  local timestamp
  local epoch
  local date_cmd

  if command -v gdate >/dev/null 2>&1; then
    date_cmd="gdate"
  elif command -v date >/dev/null 2>&1; then
    date_cmd="date"
  else
    echo "unix_to_date: no date command available" >&2
    return 1
  fi

  _unix_to_date_one() {
    local timestamp="$1"
    local digits

    if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
      echo "unix_to_date: invalid timestamp: $timestamp" >&2
      return 1
    fi

    digits=${#timestamp}

    case "$digits" in
      1|2|3|4|5|6|7|8|9|10)
        # Seconds
        epoch="$timestamp"
        ;;

      11|12|13)
        # Milliseconds
        epoch="${timestamp:0:-3}.${timestamp: -3}"
        ;;

      14|15|16)
        # Microseconds
        epoch="${timestamp:0:-6}.${timestamp: -6}"
        ;;

      17|18|19)
        # Nanoseconds
        epoch="${timestamp:0:-9}.${timestamp: -9}"
        ;;

      *)
        echo "unix_to_date: cannot infer unit from ${digits}-digit timestamp: $timestamp" >&2
        return 1
        ;;
    esac

    "$date_cmd" --iso-8601=seconds --date="@$epoch"
  }

  if (( $# > 0 )); then
    for timestamp in "$@"; do
      _unix_to_date_one "$timestamp"
    done
  else
    while IFS= read -r timestamp; do
      [[ -n "$timestamp" ]] && _unix_to_date_one "$timestamp"
    done
  fi

  unset -f _unix_to_date_one
}


# Convert Unix timestamps in seconds to ISO 8601.
#
# Usage:
#   seconds_to_date 1609459200
#   printf '%s\n' 1609459200 1609459201 | seconds_to_date
seconds_to_date() {
  local timestamp
  local date_cmd

  if command -v gdate >/dev/null 2>&1; then
    date_cmd="gdate"
  else
    date_cmd="date"
  fi

  if (( $# > 0 )); then
    for timestamp in "$@"; do
      if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
        echo "Invalid timestamp in seconds: $timestamp" >&2
        continue
      fi

      "$date_cmd" --iso-8601=seconds --date="@$timestamp"
    done
  else
    while IFS= read -r timestamp; do
      if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
        echo "Invalid timestamp in seconds: $timestamp" >&2
        continue
      fi

      "$date_cmd" --iso-8601=seconds --date="@$timestamp"
    done
  fi
}


# Change to the root directory of the current Git repository.
#
# Usage:
#   cdr
cdr() {
  local root

  root="$(command git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "cdr: not inside a Git repository" >&2
    return 1
  }

  builtin cd -- "$root"
}


# Interactively select a directory beneath the current directory and enter it.
#
# This selects directories only and excludes .git internals.
#
# Usage:
#   cf
cf() {
  local directory

  if ! command -v fzf >/dev/null 2>&1; then
    echo "cf: fzf is not installed or not on PATH" >&2
    return 1
  fi

  directory="$(
    command find . \
      -type d \
      -not -path '*/.git' \
      -not -path '*/.git/*' \
      2>/dev/null |
      command fzf \
        --height='80%' \
        --reverse \
        --prompt='Directory> '
  )" || return

  [[ -n "$directory" ]] || return
  builtin cd -- "$directory"
}


# Terminate a process tree, children first.
#
# Sends SIGTERM first and gives each process approximately two seconds to
# exit. It sends SIGKILL only if a process remains alive.
#
# Usage:
#   killtree <PID>
killtree() {
  local pid="$1"
  local child
  local attempt

  if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]]; then
    echo "Usage: killtree <PID>" >&2
    return 2
  fi

  if (( pid <= 1 )); then
    echo "killtree: refusing to terminate PID $pid" >&2
    return 2
  fi

  if (( pid == $$ )); then
    echo "killtree: refusing to terminate the current shell" >&2
    return 2
  fi

  # Terminate children before their parent.
  while IFS= read -r child; do
    [[ -n "$child" ]] && killtree "$child"
  done < <(command pgrep -P "$pid" 2>/dev/null)

  # The process may have exited while its children were being terminated.
  command kill -0 "$pid" 2>/dev/null || return 0

  command kill -TERM "$pid" 2>/dev/null || return 1

  # Wait for approximately two seconds.
  for attempt in {1..20}; do
    command kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done

  echo "killtree: PID $pid did not exit after SIGTERM; sending SIGKILL" >&2
  command kill -KILL "$pid" 2>/dev/null
}


# Interactively pick a branch or tag (via fzf, with a log preview) and check
# it out. Pass a name directly to skip the picker.
#
# Usage:
#   fgck
#   fgck some-branch
fgck() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fgck: fzf is not installed or not on PATH" >&2
    return 1
  fi

  if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "fgck: not inside a git repository" >&2
    return 1
  fi

  local branch="$1"
  if [[ -n "$branch" ]]; then
    command git checkout "$branch"
    return
  fi

  local branches tags target branch_name

  branches="$(
    command git --no-pager branch --all --sort=-committerdate \
      --format='%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)' |
      sed '/^$/d'
  )"

  tags="$(command git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}')"

  target="$(
    { printf '%s\n' "$branches"; printf '%s\n' "$tags"; } |
      command fzf --no-hscroll --no-multi -n 2 \
        --height 80% \
        --border \
        --ansi \
        --preview='git log --oneline --graph --decorate --color=always {2}' \
        --preview-window=right:60%
  )"

  [[ -z "$target" ]] && return

  branch_name="$(printf '%s' "$target" | awk '{print $2}' | sed 's#^origin/##')"
  command git checkout "$branch_name"
}
