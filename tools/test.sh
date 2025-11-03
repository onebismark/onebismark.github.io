#!/usr/bin/env bash
#
# Build and test the site content
#
# Requirement: html-proofer, jekyll
#
# Usage: See help information

set -eu

SITE_DIR="_site"
_config="_config.yml"
_baseurl=""

help() {
  echo "Build and test the site content"
  echo
  echo "Usage:"
  echo
  echo "   bash $0 [options]"
  echo
  echo "Options:"
  echo '     -c, --config   "<config_a[,config_b[...]]>"    Specify config file(s)'
  echo "     -h, --help               Print this information."
}

read_baseurl() {
  # If multiple configs, split and search from last to first (later configs override earlier)
  if [[ "$_config" == *","* ]]; then
    local oldIFS="$IFS"
    IFS=","
    read -ra config_array <<<"$_config"
    IFS="$oldIFS"

    # reverse loop the config files
    for ((i = ${#config_array[@]} - 1; i >= 0; i--)); do
      cfg="${config_array[i]}"
      cfg="${cfg#"${cfg%%[![:space:]]*}"}"  # trim leading whitespace
      cfg="${cfg%"${cfg##*[![:space:]]}"}"  # trim trailing whitespace

      if [[ ! -r "$cfg" ]]; then
        echo "Error: config file '$cfg' does not exist or is not readable" >&2
        exit 2
      fi

      # allow optional leading whitespace before 'baseurl:'
      _tmp_baseurl="$(grep -E '^[[:space:]]*baseurl:' "$cfg" || true | sed -n "s/.*: *//p" | sed "s/['\"]//g;s/#.*//" | tr -d '\r')"

      if [[ -n "$_tmp_baseurl" ]]; then
        _baseurl="$_tmp_baseurl"
        break
      fi
    done
  else
    if [[ ! -r "$_config" ]]; then
      echo "Error: config file '$_config' does not exist or is not readable" >&2
      exit 2
    fi
    _baseurl="$(grep -E '^[[:space:]]*baseurl:' "$_config" || true | sed -n "s/.*: *//p" | sed "s/['\"]//g;s/#.*//" | tr -d '\r')"
  fi

  # Normalize baseurl:
  # - Empty or "/" becomes empty string (site at root)
  # - Ensure it begins with a single leading slash and has no trailing slash
  if [[ -z "$_baseurl" || "$_baseurl" == "/" ]]; then
    _baseurl=""
  else
    # ensure leading slash
    if [[ "${_baseurl:0:1}" != "/" ]]; then
      _baseurl="/$_baseurl"
    fi
    # remove trailing slash if any
    _baseurl="${_baseurl%/}"
  fi
}

main() {
  # clean up
  if [[ -d "$SITE_DIR" ]]; then
    rm -rf "$SITE_DIR"
  fi

  read_baseurl

  DEST="$SITE_DIR$_baseurl"

  # ensure destination directory's parent exists
  mkdir -p "$SITE_DIR"

  # build
  JEKYLL_ENV=production bundle exec jekyll b -d "$DEST" -c "$_config"

  # test
  # Run htmlproofer against the built destination (or the root _site so checks include baseurl subdir)
  bundle exec htmlproofer "$SITE_DIR" \
    --disable-external \
    --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
}

# Simple argument parsing with checks
while (($#)); do
  opt="$1"
  case $opt in
  -c | --config)
    if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
      echo "Error: missing value for $1" >&2
      help
      exit 1
    fi
    _config="$2"
    shift 2
    ;;
  -h | --help)
    help
    exit 0
    ;;
  *)
    # unknown option
    help
    exit 1
    ;;
  esac
done

main