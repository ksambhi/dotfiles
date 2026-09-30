# Convert Unix timestamps in seconds, milliseconds, microseconds, or
# nanoseconds to ISO 8601. The unit is inferred from the digit count.
#
# Usage:
#   unix_to_date 1759330800
#   unix_to_date 1759330800000
#   printf '%s\n' 1759330800 1759330800000 | unix_to_date
# By an LLM
unix_to_date() {
  local timestamp
  local epoch
  local digits

  if ! command -v gdate >/dev/null 2>&1; then
    print -u2 -- "unix_to_date: gdate is not installed or not on PATH"
    return 1
  fi

  _unix_to_date_one() {
    timestamp="$1"

    if [[ "$timestamp" != <-> ]]; then
      print -u2 -- "unix_to_date: invalid timestamp: $timestamp"
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
        epoch="${timestamp[1,-4]}.${timestamp[-3,-1]}"
        ;;

      14|15|16)
        # Microseconds
        epoch="${timestamp[1,-7]}.${timestamp[-6,-1]}"
        ;;

      17|18|19)
        # Nanoseconds
        epoch="${timestamp[1,-10]}.${timestamp[-9,-1]}"
        ;;

      *)
        print -u2 -- \
          "unix_to_date: cannot infer unit from ${digits}-digit timestamp: $timestamp"
        return 1
        ;;
    esac

    command gdate --iso-8601=seconds --date="@$epoch"
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

  unfunction _unix_to_date_one
}


# Convert Unix timestamps in seconds to ISO 8601.
#
# Usage:
#   seconds_to_date 1609459200
#   printf '%s\n' 1609459200 1609459201 | seconds_to_date
seconds_to_date() {
  local timestamp

  if (( $# > 0 )); then
    for timestamp in "$@"; do
      if [[ "$timestamp" != <-> ]]; then
        print -u2 -- "Invalid timestamp in seconds: $timestamp"
        continue
      fi

      command gdate --iso-8601=seconds --date="@$timestamp"
    done
  else
    while IFS= read -r timestamp; do
      if [[ "$timestamp" != <-> ]]; then
        print -u2 -- "Invalid timestamp in seconds: $timestamp"
        continue
      fi

      command gdate --iso-8601=seconds --date="@$timestamp"
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
    print -u2 -- "cdr: not inside a Git repository"
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
    print -u2 -- "cf: fzf is not installed or not on PATH"
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

  if [[ -z "$pid" || "$pid" != <-> ]]; then
    print -u2 -- "Usage: killtree <PID>"
    return 2
  fi

  if (( pid <= 1 )); then
    print -u2 -- "killtree: refusing to terminate PID $pid"
    return 2
  fi

  if (( pid == $$ )); then
    print -u2 -- "killtree: refusing to terminate the current shell"
    return 2
  fi

  # Terminate children before their parent.
  for child in ${(f)"$(command pgrep -P "$pid" 2>/dev/null)"}; do
    [[ -n "$child" ]] && killtree "$child"
  done

  # The process may have exited while its children were being terminated.
  command kill -0 "$pid" 2>/dev/null || return 0

  command kill -TERM "$pid" 2>/dev/null || return 1

  # Wait for approximately two seconds.
  for attempt in {1..20}; do
    command kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done

  print -u2 -- "killtree: PID $pid did not exit after SIGTERM; sending SIGKILL"
  command kill -KILL "$pid" 2>/dev/null
}