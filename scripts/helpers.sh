#!/usr/bin/env bash

function get_tmux_option() {
  local option="${1}"
  local default_value="${2}"
  local option_value="$(tmux show-option -gqv "${option}" 2>/dev/null)"
  if [ -z "${option_value}" ]; then
    echo "${default_value}"
  else
    echo "${option_value}"
  fi
}

function set_tmux_option() {
  local option="${1}"
  local value="${2}"
  tmux set-option -gq "${option}" "${value}"
}

function is_osx() {
  [ "$(uname)" = "Darwin" ]
}

function is_linux(){
  [ "$(uname -s)" = "Linux" ]
}

function is_freebsd() {
  [ "$(uname)" = "FreeBSD" ]
}

function command_exists() {
  local command="${1}"
  type "${command}" >/dev/null 2>&1
}

# Every "@wifi_dbm_*" option in one tmux round-trip. Asking per option costs a
# round-trip each, which was enough to make a job miss its status-line draw and
# only appear a refresh later; the plugin reads up to a dozen of them.
WIFI_DBM_OPTS=""
WIFI_DBM_OPTS_LOADED=""

function load_wifi_dbm_options() {
  [ -n "${WIFI_DBM_OPTS_LOADED}" ] && return 0
  WIFI_DBM_OPTS_LOADED=1
  WIFI_DBM_OPTS="$(tmux show-options -g 2>/dev/null | grep '^@wifi_dbm_')"
}

# Like get_tmux_option, but served from the single dump above.
function get_wifi_dbm_option() {
  local option="${1}"
  local default_value="${2}"
  local option_value

  load_wifi_dbm_options
  option_value="$(printf '%s\n' "${WIFI_DBM_OPTS}" | sed -n "s/^${option} //p" | head -1)"
  # show-options quotes values containing spaces.
  option_value="${option_value#\"}"
  option_value="${option_value%\"}"

  if [ -z "${option_value}" ]; then
    printf '%s' "${default_value}"
  else
    printf '%s' "${option_value}"
  fi
}

# Per-user scratch space for the compiled CoreWLAN helper and the cached
# fallback reading.
function cache_dir() {
  echo "${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-wifi-dbm"
}
