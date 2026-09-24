#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${CURRENT_DIR}/scripts/helpers.sh"

# Longer placeholders must come first: each pattern ends in "}", so
# "#{wifi_dbm}" cannot match inside "#{wifi_dbm_label}", but keeping the more
# specific names ahead of the general one makes that independent of the
# trailing brace.
placeholders=(
  "\#{wifi_dbm_status}"
  "\#{wifi_dbm_label}"
  "\#{wifi_dbm}"
)

commands=(
  "#($CURRENT_DIR/scripts/dbm.sh status)"
  "#($CURRENT_DIR/scripts/dbm.sh label)"
  "#($CURRENT_DIR/scripts/dbm.sh)"
)

function do_interpolation() {
  local all_interpolated="${1}"
  for ((i=0; i<${#commands[@]}; i++)); do
    all_interpolated=${all_interpolated//${placeholders[$i]}/${commands[$i]}}
  done
  echo "${all_interpolated}"
}

function update_tmux_option() {
  local option="${1}"
  local option_value="$(get_tmux_option "${option}")"
  local new_option_value="$(do_interpolation "${option_value}")"
  set_tmux_option "${option}" "${new_option_value}"
}

function main() {
  update_tmux_option "status-right"
  update_tmux_option "status-left"

  # Warm the cache at load time: the first call compiles the CoreWLAN helper
  # and primes a reading, so the status bar has a real value to show on its
  # first refresh rather than a placeholder.
  "${CURRENT_DIR}/scripts/dbm.sh" </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null
}

main "${@}"
