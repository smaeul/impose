#!/bin/sh -eu
#
# Copyright © 2019 Samuel Holland <samuel@sholland.org>
# SPDX-License-Identifier: 0BSD
#
# Main impose script
#
# Dependencies:
#  - POSIX sh + local
#  - hostname(1)
#

# Display messages in color when this is a positive integer
COLOR=1
# Software identifier
IMPOSE=${0##*/}
# Library script path
LIB=$PWD/lib.sh
# Do not perform any action when this is a positive integer
NO_ACTION=0
# The root of the destination directory hierarchy
ROOT=
# Module selected on the command line
USER_MODULE=
# Print verbose messages when this is a positive integer
VERBOSE=0
# Software version
VERSION=0.1

. "$LIB"

# version
version() {
   printf '%s version %s\n' "$IMPOSE" "$VERSION" >&2
}

# usage
usage() {
   version
   printf 'usage: %s [-CVchnv] [-R ROOT] [-m MODULE] [HOST...]\n' "$0" >&2
}

# config_parse FILE
config_parse() {
   xargs < "$1"
}

# host_get_config HOST...
host_get_config() {
   local file
   local name

   for name; do
      test -n "$name" || continue
      for file in "hosts/${name}" "hosts/${name%%.*}"; do
         debug "host_get_config: trying '${file}'"
         test -f "$file" || continue
         echo "$file"
         return 0
      done
   done
   debug "host_get_config: trying 'hosts/default'"
   test -f "hosts/default" && echo "hosts/default"
}

# host_get_self
host_get_self() {
   hostname -f 2>/dev/null || hostname 2>/dev/null || :
}

# host_impose_modules HOST MODULE...
host_impose_modules() {
   die STUB host_impose_modules
}

# impose_modules MODULE...
impose_modules() {
   if test "$(id -u)" -ne 0 && test "$NO_ACTION" -le 0; then
      die "Must be running as root to modify the local machine. Try '-n'"
   fi
   for MODULE; do
      (
         MODSRC=${PWD}/modules/${MODULE}
         export IMPOSE MODSRC MODULE NO_ACTION ROOT VERBOSE
         umask 0577
         test -d "$MODSRC" || die "Module '${MODULE}' does not exist"
         notice "Imposing module '${MODULE}'"
         if test -x "${MODSRC}/pre"; then
            debug "${MODULE}: Running pre-apply script"
            "${MODSRC}/pre"
         fi
         if test -f "${MODSRC}/directories"; then
            while read path perms user group; do
               test -n "$path"  || continue
               test -z "$perms" && perms=0755
               test -z "$user"  && user=root
               test -z "$group" && group=$user
               debug "${MODULE}: Updating directory '${path}'"
               dest=$ROOT$path
               if ! test -d "$dest"; then
                  test -e "$dest" && noact rm -f "$dest"
                  noact mkdir "$dest"
               fi
               noact chown "${user}:${group}" "$dest"
               noact chmod "$perms" "$dest"
            done < "${MODSRC}/directories"
         fi
         if test -f "${MODSRC}/files"; then
            while read path perms user group; do
               test -n "$path"  || continue
               test -z "$perms" && perms=0644
               test -z "$user"  && user=root
               test -z "$group" && group=$user
               debug "${MODULE}: Updating file '${path}'"
               src=$MODSRC$path
               dest=$ROOT$path
               if test -f "$dest" && cmp -s "$src" "$dest"; then
                  tmp=$dest
               else
                  test -d "$dest" && noact rmdir "$dest"
                  tmp=${dest%/*}/..impose.$$.${dest##*/}
               fi
               noact cp -P "$src" "$tmp"
               noact chown -h "${user}:${group}" "$tmp"
               test -h "$src" || noact chmod "$perms" "$tmp"
               test "$tmp" != "$dest" && noact mv "$tmp" "$dest"
            done < "${MODSRC}/files"
         fi
         if test -x "${MODSRC}/post"; then
            debug "${MODULE}: Running post-apply script"
            "${MODSRC}/post"
         fi
      ) || {
         warn "Failed to impose module '${MODULE}'"
         break
      }
   done
}

# main [ARG...]
main() {
   test -t 2 || COLOR=0
   while getopts :CR:Vchm:nv OPTION; do
      case "$OPTION" in
         C) COLOR=0 ;;
         R) ROOT=$OPTARG ;;
         V) version; return 0 ;;
         c) COLOR=1 ;;
         h) usage; return 0 ;;
         m) USER_MODULE=$OPTARG ;;
         n) NO_ACTION=$((NO_ACTION+1)) ;;
         v) VERBOSE=$((VERBOSE+1)) ;;
         :) usage; die "Missing argument to -${OPTARG}" ;;
         ?) usage; die "Bad option: -${OPTARG}" ;;
      esac
   done
   shift $((OPTIND-1))

   if test -n "$ROOT" && test "$ROOT" = "${ROOT#/}"; then
      die "The argument to -R must be an absolute path"
   fi

   if test "$#" -gt 0; then
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
         if let CONFIG := host_get_config "$(host_get_self)"; then
            if ! let MODULES := config_parse "$CONFIG"; then
               warn "Bad configuration format in '${CONFIG}'"
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
