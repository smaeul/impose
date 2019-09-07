#!/bin/sh -eu
#
# Copyright © 2019 Samuel Holland <samuel@sholland.org>
# SPDX-License-Identifier: 0BSD
#
# Library functions for use in impose.sh and hook scripts
#
# Dependencies:
#  - POSIX sh + local
#

# echo [WORD...]
echo() {
   printf '%s\n' "$*"
}

# log LEVEL WORD...
log() {
   local level
   local prefix
   local suffix

   level=$1
   shift
   if test "$COLOR" -gt 0; then
      case "$level" in
         2) prefix="\033[1;31m" ;;
         3) prefix="\033[1;31m" ;;
         4) prefix="\033[1;33m" ;;
         5) prefix="\033[1;1m"  ;;
         7) prefix="\033[0;34m" ;;
         ?) prefix= ;;
      esac
      suffix="\033[m"
   else
      prefix=
      suffix=
   fi
   if test "$level" -lt 6 || test "$((level-VERBOSE))" -lt 6; then
      printf '%b%s: %s%b\n' "$prefix" "${0##*/}" "$*" "$suffix" >&2
   fi
}

# die/error/warn/notice/info/debug WORD...
die()    { log 2 "$@"; exit 1; }
error()  { log 3 "$@"; }
warn()   { log 4 "$@"; }
notice() { log 5 "$@"; }
info()   { log 6 "$@"; }
debug()  { log 7 "$@"; }

# let VARIABLE := COMMAND [ARG...]
let() {
   local ret
   local val
   local var

   var=$1
   shift 2
   debug "let: running: $@"
   val=$("$@")
   ret=$?
   debug "let: setting '${var}' to '${val}' and returning ${ret}"
   eval "$var"'="$val"'
   return "$ret"
}

noact() {
   if test "$NO_ACTION" -gt 0; then
      info "skipping: $@"
   else
      info "running: $@"
      "$@"
   fi
}
