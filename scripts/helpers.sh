#!/usr/bin/env bash

function get_tmux_option() {
  local option="${1}"
  local default_value="${2}"
  local option_value="$(tmux show-option -gqv "${option}")"
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
  [ $(uname) == "Darwin" ]
}

function is_linux(){
  [ $(uname -s) == "Linux" ]
}

function is_freebsd() {
    [ $(uname) == FreeBSD ]
}

function command_exists() {
  local command="${1}"
  type "${command}" >/dev/null 2>&1
}
