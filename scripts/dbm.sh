#!/usr/bin/env bash
#
# Prints the current Wi-Fi signal strength, for use as a tmux status-bar
# interpolation. Exits quietly (printing OFFLINE_TEXT) whenever no reading is
# available, so the status bar never shows an error.
#
# Usage: dbm.sh [dbm|label|status]
#   dbm     (default)  -62
#   label              Good
#   status             -62 [Good]
#   color              #[fg=yellow]

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${CURRENT_DIR}/helpers.sh"

MODE="${1:-dbm}"

OFFLINE_TEXT="$(get_wifi_dbm_option "@wifi_dbm_offline_text" "--")"
# How long a system_profiler reading stays usable. That call takes several
# seconds, so it is only ever refreshed in the background.
FALLBACK_TTL=15

CACHE_DIR="$(cache_dir)"
SWIFT_SRC="${CURRENT_DIR}/wifi_dbm.swift"
SWIFT_BIN="${CACHE_DIR}/wifi_dbm"
BUILD_LOCK="${CACHE_DIR}/build.lock"
VALUE_CACHE="${CACHE_DIR}/value"
VALUE_LOCK="${CACHE_DIR}/value.lock"

function file_age() {
  local file="${1}"
  local mtime
  # -f %m is BSD/macOS stat; -c %Y is GNU stat.
  mtime="$(stat -f %m "${file}" 2>/dev/null || stat -c %Y "${file}" 2>/dev/null)"
  [ -n "${mtime}" ] || return 1
  echo "$(( $(date +%s) - mtime ))"
}

# Runs "${@}" detached, at most once at a time. mkdir is atomic, so it doubles
# as the lock; a lock older than 5 minutes is assumed stale and reclaimed.
function run_once_in_background() {
  local lock="${1}"
  shift

  if [ -d "${lock}" ]; then
    local age
    age="$(file_age "${lock}")"
    if [ -z "${age}" ] || [ "${age}" -lt 300 ]; then
      return 0
    fi
    rmdir "${lock}" 2>/dev/null
  fi

  mkdir "${lock}" 2>/dev/null || return 0
  # Every descriptor must be closed off: this function is called from inside a
  # command substitution, which blocks until the last writer to its pipe exits.
  ( "${@}"; rmdir "${lock}" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null
}

function build_swift_helper() {
  local tmp_bin="${SWIFT_BIN}.$$"
  if swiftc -O "${SWIFT_SRC}" -o "${tmp_bin}" 2>/dev/null; then
    mv -f "${tmp_bin}" "${SWIFT_BIN}"
  else
    rm -f "${tmp_bin}"
  fi
}

# Apple removed this binary in macOS 14.4; still worth trying on older systems.
function read_legacy_airport() {
  local airport
  airport="$(ls /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport 2>/dev/null)"
  [ -x "${airport}" ] || return 1
  "${airport}" -I 2>/dev/null | awk '/agrCtlRSSI/ { print $2; found = 1 } END { exit !found }'
}

function refresh_fallback_cache() {
  local value
  value="$(system_profiler SPAirPortDataType 2>/dev/null | awk '
    /Current Network Information:/ { current = 1 }
    /Other Local Wi-Fi Networks:/  { current = 0 }
    # "Signal / Noise: -68 dBm / -96 dBm" -- $4 is the signal figure.
    current && /Signal \/ Noise:/  { print $4; found = 1; exit }
    END { exit !found }
  ')"
  [ -n "${value}" ] || return 1
  printf '%s\n' "${value}" > "${VALUE_CACHE}.$$" && mv -f "${VALUE_CACHE}.$$" "${VALUE_CACHE}"
}

# Serves the last system_profiler reading, refreshing it in the background once
# it goes stale. Returns a stale value in preference to nothing at all.
function read_cached_fallback() {
  local age=""
  [ -f "${VALUE_CACHE}" ] && age="$(file_age "${VALUE_CACHE}")"

  if [ -z "${age}" ] || [ "${age}" -ge "${FALLBACK_TTL}" ]; then
    run_once_in_background "${VALUE_LOCK}" refresh_fallback_cache
  fi

  [ -f "${VALUE_CACHE}" ] || return 1
  cat "${VALUE_CACHE}"
}

function read_osx() {
  # Fast path: the compiled CoreWLAN helper, which returns in ~10ms.
  if [ -x "${SWIFT_BIN}" ] && [ "${SWIFT_BIN}" -nt "${SWIFT_SRC}" ]; then
    "${SWIFT_BIN}" && return 0
    # Ran but reported no link — the radio is off or unassociated.
    return 1
  fi

  # Compiling takes a few seconds, so do it out of band and answer from a
  # slower source until the binary lands.
  if command_exists swiftc; then
    mkdir -p "${CACHE_DIR}"
    run_once_in_background "${BUILD_LOCK}" build_swift_helper
  fi

  read_legacy_airport && return 0

  mkdir -p "${CACHE_DIR}"
  read_cached_fallback
}

# Maps a reading onto one of five bands. The cut-offs follow the usual Wi-Fi
# reference points: -67 dBm is the floor for reliable streaming and VoIP, and
# below about -75 dBm a link only carries light traffic.
function band_for() {
  local dbm="${1}"

  local t_excellent t_good t_fair t_weak
  t_excellent="$(get_wifi_dbm_option "@wifi_dbm_threshold_excellent" "-50")"
  t_good="$(get_wifi_dbm_option "@wifi_dbm_threshold_good" "-60")"
  t_fair="$(get_wifi_dbm_option "@wifi_dbm_threshold_fair" "-67")"
  t_weak="$(get_wifi_dbm_option "@wifi_dbm_threshold_weak" "-75")"

  if [ "${dbm}" -ge "${t_excellent}" ]; then
    printf 'excellent'
  elif [ "${dbm}" -ge "${t_good}" ]; then
    printf 'good'
  elif [ "${dbm}" -ge "${t_fair}" ]; then
    printf 'fair'
  elif [ "${dbm}" -ge "${t_weak}" ]; then
    printf 'weak'
  else
    printf 'poor'
  fi
}

function label_for() {
  local band="${1}"
  case "${band}" in
    excellent) get_wifi_dbm_option "@wifi_dbm_label_excellent" "Excellent" ;;
    good)      get_wifi_dbm_option "@wifi_dbm_label_good"      "Good" ;;
    fair)      get_wifi_dbm_option "@wifi_dbm_label_fair"      "Fair" ;;
    weak)      get_wifi_dbm_option "@wifi_dbm_label_weak"      "Weak" ;;
    *)         get_wifi_dbm_option "@wifi_dbm_label_poor"      "Poor" ;;
  esac
}

# Emits a tmux style directive, e.g. "#[fg=yellow]", the same shape tmux-cpu
# and tmux-battery use so it composes with an existing status line.
function color_for() {
  local band="${1}"
  local color
  case "${band}" in
    excellent) color="$(get_wifi_dbm_option "@wifi_dbm_color_excellent" "green")" ;;
    good)      color="$(get_wifi_dbm_option "@wifi_dbm_color_good"      "green")" ;;
    fair)      color="$(get_wifi_dbm_option "@wifi_dbm_color_fair"      "yellow")" ;;
    weak)      color="$(get_wifi_dbm_option "@wifi_dbm_color_weak"      "colour208")" ;;
    offline)   color="$(get_wifi_dbm_option "@wifi_dbm_color_offline"   "colour244")" ;;
    *)         color="$(get_wifi_dbm_option "@wifi_dbm_color_poor"      "red")" ;;
  esac
  printf '#[fg=%s]' "${color}"
}

function read_dbm() {
  if is_osx; then
    read_osx
  else
    return 1
  fi
}

function offline_output() {
  if [ "${MODE}" = "color" ]; then
    color_for "offline"
  else
    printf '%s' "${OFFLINE_TEXT}"
  fi
}

function main() {
  local dbm
  if ! dbm="$(read_dbm)"; then
    offline_output
    return 0
  fi

  # Normalise to a bare signed integer; sources pad or suffix differently.
  dbm="$(printf '%s' "${dbm}" | tr -dc '\-0-9')"
  if [ -z "${dbm}" ] || [ "${dbm}" = "-" ]; then
    offline_output
    return 0
  fi

  # One band lookup feeds every mode.
  local band
  band="$(band_for "${dbm}")"

  case "${MODE}" in
    label)  label_for "${band}" ;;
    color)  color_for "${band}" ;;
    status) printf '%s [%s]' "${dbm}" "$(label_for "${band}")" ;;
    *)      printf '%s' "${dbm}" ;;
  esac
}

main "${@}"
