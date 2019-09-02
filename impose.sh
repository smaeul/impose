#!/bin/sh -eu
#
# Copyright © 2019 Samuel Holland <samuel@sholland.org>
# SPDX-License-Identifier: 0BSD
#
# Dependencies
#  - POSIX sh + local
#  - hostname(1)
#

# Module selected on the command line
USER_MODULE=
# Print verbose messages when this is a positive integer
VERBOSE=0
# Software version
VERSION=0.1

# echo [WORD...]
echo() {
   printf '%s\n' "$*"
}

# msg [WORD...]
msg() {
   printf '%s: %s\n' "${0##*/}" "$*" >&2
}

# usage
usage() {
   printf '%s version %s\n' "${0##*/}" "$VERSION" >&2
   printf 'usage: %s [-v] [-m MODULE] [HOST...]\n' "$0" >&2
}

# debug [WORD...]
debug() {
   if test "$VERBOSE" -gt "0"; then
      msg "$@"
   fi
}

# die [WORD...]
die() {
   msg "$@"
   exit 1
}

# warn [WORD...]
warn() {
   msg "$@"
}

# let VARIABLE := COMMAND [ARG...]
let() {
   local ret
   local val
   local var
   var=$1
   shift 2
   debug let: running "$@"
   val=$("$@")
   ret=$?
   debug let: setting "$var" to "'$val'" and returning "$ret"
   eval "$var"'="$val"'
   return "$ret"
}

# config_parse FILE
config_parse() {
   cat "$1"
}

# host_get_config HOST...
host_get_config() {
   local file
   local name
   for name; do
      for file in "hosts/${name}" "hosts/${name%%.*}"; do
         debug host_get_config: trying "$file"
         if test -f "$file"; then
            echo "$file"
            return 0
         fi
      done
   done
   if test -f "hosts/default"; then
      echo "hosts/default"
      return 0
   fi
   return 1
}

# host_get_local_names
host_get_local_names() {
   hostname -f 2>/dev/null || hostname 2>/dev/null || :
   echo localhost
}

# host_impose_modules HOST MODULE...
host_impose_modules() {
   die STUB host_impose_modules
}

# impose_modules MODULE...
impose_modules() {
   die STUB impose_modules
   for MODULE; do
      export MODULE
   done
}

# main [ARG...]
main() {
   export IMPOSE=$VERSION

   while getopts :hm:v OPTION; do
      case "$OPTION" in
         h) usage; exit 0 ;;
         m) USER_MODULE=$OPTARG ;;
         v) VERBOSE=$((VERBOSE+1)) ;;
         ?) usage; die "Bad option: -${OPTARG}" ;;
         :) usage; die "Missing argument to -${OPTARG}" ;;
      esac
   done
   shift $((OPTIND-1))

   if test "$#" -gt "0"; then
      for HOST; do
         if test -n "$USER_MODULE"; then
            MODULES=$USER_MODULE
         else
            if ! let CONFIG := host_get_config "$HOST"; then
               warn "Skipping ${HOST}: No configuration found"
               continue
            fi
            if ! let MODULES := config_parse "$CONFIG"; then
               warn "Skipping ${HOST}: Bad configuration format"
               continue
            fi
         fi
         if test "${HOST%%.*}" = "localhost"; then
            impose_modules "$MODULES"
         else
            host_impose_modules "$HOST" "$MODULES"
         fi
      done
   else
      if test -n "$USER_MODULE"; then
         impose_modules "$USER_MODULE"
      else
         if let CONFIG := host_get_config $(host_get_local_names); then
            if ! let MODULES := config_parse "$CONFIG"; then
               warn "Bad configuration format in ${CONFIG}"
               continue
            fi
            impose_modules "$MODULES"
         else
            die "No configuration found for the local machine"
         fi
      fi
   fi
}

main "$@"
