#!/bin/sh
CHROOTDIR=""
CHROOTSHELL="/bin/bash"
VERBOSE=0
VERBOSEOPT=""
CLEANONLY=false
KEEPMOUNTS=false

usage() {
  exec >&2
  [ -n "${1}" ] && printf "Error : ${1}\n"
  printf "Usage : $(basename "${0}") [options] chroot_dir\n"
  printf "  Mount proc/sys and dev before chrooting to chroot_dir\n"
  printf "  and umount when leaving\n"
  printf "options :\n"
  printf "  -s shell : specify shell to use in chroot (default: ${CHROOTSHELL})\n"
  printf "  -v       : be verbose\n"
  printf "  -h       : show this help message\n"
  exit 1
}

error() {
  printf "Error : ${1}\n" >&2
  [ ${2} -ge 0 ] 2>/dev/null && exit ${2}
  exit 255
}

checkmount() {
  local dir="${1}" type="${2}" dev="${3}" opts="${4}"
  if mountpoint -q "${CHROOTDIR}/${dir}"; then
    [ ${VERBOSE} -ge 1 ] && printf "${CHROOTDIR}/${dir} is already mounted\n"
    return 0
  fi
  [ ${VERBOSE} -ge 1 ] && { printf "Mounting ${CHROOTDIR}/${dir}, type ${type}"; [ -n "${opts}" ] && printf " ${opts}\n" || printf "\n"; }
  mount ${VERBOSEOPT} ${opts} -t "${type}" "${dev}" "${CHROOTDIR}/${dir}"
}

domounts() {
  local d
  for d in proc sys dev; do [ -d "${CHROOTDIR}/${d}" ] || error "${CHROOTDIR}/${d} does not exist, are you trying to chroot in a Linux tree?.." 2; done
  checkmount proc proc proc || return 1
  checkmount sys sysfs sys || return 1
  checkmount dev bind /dev "-o bind" || return 1
}

doumounts() {
  local d
  for d in dev sys proc; do
    if mountpoint -q "${CHROOTDIR}/${d}"; then
      [ ${VERBOSE} -ge 1 ] && printf "Umounting ${CHROOTDIR}/${d}\n"
      umount ${VERBOSEOPT} "${CHROOTDIR}/${d}"
    else
      [ ${VERBOSE} -ge 1 ] && printf "${CHROOTDIR}/${d} is not mounted\n"
    fi
  done
}

[ "$(id -un)" = "root" ] || error "this script must be run with root privileges" 1

while getopts s:cvkh opt; do case "${opt}" in
  s) CHROOTSHELL="${OPTARG}";;
  c) CLEANONLY=true;;
  v) VERBOSE=$(expr ${VERBOSE} + 1); VERBOSEOPT="-v";;
  k) KEEPMOUNTS=true;;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
CHROOTDIR="${1}"
[ -n "${CHROOTDIR}" ] || usage
[ -d "${CHROOTDIR}" ] || usage "'${CHROOTDIR}' : no such directory\n"

if ! ${CLEANONLY}; then
  domounts || error "failed to mount some filesystems" 3
  diff /etc/resolv.conf "${CHROOTDIR}/etc/resolv.conf" >/dev/null 2>&1 || cp ${VERBOSEOPT} -L /etc/resolv.conf "${CHROOTDIR}/etc/resolv.conf"
  chroot ${CHROOTDIR} ${CHROOTSHELL}
fi
if ${KEEPMOUNTS}; then
  [ ${VERBOSE} -ge 1 ] && printf -- "-k option given, keeping filesystems mounted\n"
else
  doumounts
fi
