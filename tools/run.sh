#!/usr/bin/env bash
#
# Run jekyll serve and then launch the site
#
# Usage: bash /path/to/run.sh [options]
# Options:
#   -H, --host [HOST]     Host to bind to (default: 127.0.0.1)
#   -p, --production      Run Jekyll in 'production' mode
#   -h, --help            Print this help information

set -euo pipefail

prod=false
host="127.0.0.1"
cmd_args=("-l")

help() {
  printf '%s\n\n' "Usage:"
  printf '  %s\n\n' "bash /path/to/run.sh [options]"
  printf 'Options:\n'
  printf '  %-22s %s\n' "-H, --host [HOST]" "Host to bind to (default: ${host})."
  printf '  %-22s %s\n' "-p, --production" "Run Jekyll in 'production' mode."
  printf '  %-22s %s\n' "-h, --help" "Print this help information."
}

# Simple parsing that supports long and short options.
while (($#)); do
  opt="$1"
  case "$opt" in
    -H|--host)
      if [ $# -lt 2 ]; then
        printf 'Error: %s requires an argument\n\n' "$opt" >&2
        help
        exit 2
      fi
      # if next starts with -, treat as missing arg
      if [[ "$2" == -* ]]; then
        printf 'Error: missing host value for %s\n\n' "$opt" >&2
        help
        exit 2
      fi
      host="$2"
      shift 2
      ;;
    -p|--production)
      prod=true
      shift
      ;;
    -h|--help)
      help
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n\n' "$opt" >&2
      help
      exit 2
      ;;
  esac
done

# Build command parts
# Use "bundle exec jekyll serve" for jekyll 3/4; short alias 's' expanded to serve
cmd=("bundle" "exec" "jekyll" "serve")
# add flags
cmd+=("${cmd_args[@]}")
cmd+=("-H" "$host")

if $prod; then
  # Prepend env var in the exec so $JEKYLL_ENV is set for the launched process
  env_prefix=("JEKYLL_ENV=production")
else
  env_prefix=()
fi

# If running inside Docker, prefer --force_polling
if [ -r /proc/1/cgroup ] && grep -q docker /proc/1/cgroup 2>/dev/null; then
  cmd+=("--force_polling")
fi

# Optional: check for bundle and jekyll
if ! command -v bundle >/dev/null 2>&1; then
  printf 'Warning: "bundle" not found in PATH. Is Bundler installed?\n' >&2
fi

printf '\n> %s\n\n' "${env_prefix[*]} ${cmd[*]}"

# Replace the shell with the jekyll process so signals are forwarded and exit status propagated
if [ "${#env_prefix[@]}" -gt 0 ]; then
  # Use env to set the variable for exec
  exec env "${env_prefix[@]}" "${cmd[@]}"
else
  exec "${cmd[@]}"
fi