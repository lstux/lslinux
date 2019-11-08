#!/bin/sh
VERBOSE=0
CONFDIR=
CONFIG=
ACTION=

usage() {
  exec >&2
  local name="$(basename "${0}")"
  printf "Usage : ${name} {dir|config} get key [key2 ...]\n"
  printf "        ${name} {dir|config} set key[=value] [key2[=value2] ...]\n"
  printf "        ${name} {dir|config} unset key [key2 ...]\n"
  printf "  Edit 'kernel style' config file\n"
  printf "  You may use a combination of set/unset like this :\n"
  printf "        ${name} {dir|config} set key key2=val2 unset key3 key4 set key5 ...\n"
  printf "options :\n"
  printf "  -g type : generate initial config with make typeconfig first\n"
  printf "  -v      : increase verbosity level\n"
  printf "  -h      : display this help message\n"
  exit 1
}

kconfig_getraw() {
  local conf="${1}" key="${2}"
  sed -n -e "s/^${key}=\"\?\([^\"]\+\)\"\?$/\1/p" "${conf}"
}

kconfig_get() {
  local conf="${1}" key="${2}" val
  val="$(kconfig_getraw "${conf}" "${key}")"
  if [ -z "${val}" ]; then
    printf "${key} is unset\n"
    return 1
  fi
  if [ "${val}" = "y" ]; then
    printf "${key} is set\n"
  else
    printf "${key} is set to '${val}'\n"
  fi
  return 0
}

kconfig_unset() {
  local conf="${1}" key="${2}" pval
  pval="$(kconfig_getraw "${conf}" "${key}")"
  if [ -n "${pval}" ]; then
    [ ${VERBOSE} -ge 1 ] && { printf "${key} => unset"; [ ${VERBOSE} -ge 2 ] && printf " (was '${pval}')"; printf "\n"; }
    sed -i "s/^${key}=.*/# ${key} is not set/" "${conf}"
  else
    [ ${VERBOSE} -ge 2 ] && printf "${key} already unset\n"
  fi
}

kconfig_set() {
  local conf="${1}" keyval="${2}" key val pval
  key="${keyval%%=*}"
  val="${keyval##*=}"
  pval="$(kconfig_getraw "${conf}" "${key}")"
  if [ -z "${pval}" ]; then
    [ ${VERBOSE} -ge 1 ] && { printf "${key} => setting"; [ -n "${val}" ] && printf " to '${val}'"; printf "\n"; }
    [ "${val}" != "${keyval}" ] && val="\"${val}\"" || val="y"
    sed -i "s@^# ${key} is not set@${key}=${val}@" "${conf}"
  elif [ "${pval}" = "y" -a "${val}" = "${keyval}" ] || [ "${pval}" = "${val}" ]; then
    [ ${VERBOSE} -ge 2 ] && { printf "${key} already set"; [ "${val}" != "${keyval}" ] && printf " to '${val}'"; printf "\n"; }
  else
    [ ${VERBOSE} -ge 1 ] && { printf "${key} updating to '${val}'"; [ ${VERBOSE} -ge 2 ] && printf " (was '${pval}')"; printf "\n"; }
    [ "${val}" != "${keyval}" ] && val="\"${val}\"" || val="y"
    sed -i "s@^${key}=.*@${key}=${val}@" "${conf}"
  fi
}


while getopts g:vh opt; do case "${opt}" in
  g) CONFINIT="${OPTARG}config";;
  v) VERBOSE=$(expr ${VERBOSE} + 1);;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
if [ -d "${1}" ]; then
  CONFDIR="$(readlink -m "${1}")"; CONFIG="${CONFDIR}/.config"
else if [ -e "${1}" ]; then
  CONFIG="$(readlink -m "${1}")"; CONFDIR="$(dirname "${CONFIG}")"
else usage; fi; fi
shift
case "${1}" in
  get|set|unset) true;;
  *)             usage;;
esac

if [ -n "${CONFINIT}" ]; then
  make -C "${CONFDIR}" ${CONFINIT} || exit 2
fi
for k in "$@"; do case "${k}" in
  get|set|unset) ACTION="${k}";;
  *)             eval kconfig_${ACTION} \"${CONFIG}\" \"${k}\";;
esac; done
