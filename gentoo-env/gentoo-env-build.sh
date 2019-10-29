#!/bin/sh
GENTOO_MIRROR="${GENTOO_MIRROR:-http://ftp.free.fr/mirrors/ftp.gentoo.org}"
GENTOO_ARCH="${GENTOO_ARCH:-amd64}"
INSTALLDIR="${INSTALLDIR:-}"
VERBOSE="${VERBOSE:-0}"
FORCE=false

usage() {
  exec >&2
  printf "Usage : $(basename "${0}") [options] install_dir\n"
  printf "options :\n"
  printf "  -a arch : select architecture (defaults to ${GENTOO_ARCH})\n"
  printf "  -f      : force (re)installation"
  printf "  -v      : increase verbosity level\n"
  printf "  -h      : display this help message\n"
  exit 1
}

error() {
  printf "[ERROR] ${1}\n" >&2
  [ ${2} -ge 0 ] 2>/dev/null && exit ${2}
}

info() {
  [ ${VERBOSE} -ge 1 ] || return 0
  printf "[INFOS] $@\n"
}

debug() {
  [ ${VERBOSE} --ge 2 ] || return 0
  printf "[DEBUG] $@\n"
}


while getopts a:vfh opt; do case "${opt}" in
  a) GENTOO_ARCH="${OPTARG}";;
  v) VERBOSE="$(expr ${VERBOSE} + 1)";;
  f) FORCE=true;;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] && INSTALLDIR="${1}"


[ -n "${INSTALLDIR}" ] || usage 
[ "$(id -un)" != "root" ] && error "this script should be run as root"
[ ${VERBOSE} -ge 2 ] && exec 5>&1
[ ${VERBOSE} -ge 1 ] && exec 6>&2

if ! [ -d "${INSTALLDIR}" ]; then
  info "creating installation directory '${INSTALLDIR}'"
  install -v -d -m755 "${INSTALLDIR}" >&5 2>&6
fi

if [ -d "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc" ]; then
  ${FORCE} || { printf "gentoo stage3 seems already installed in ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc"; printf "remove directory or use -f option to (re)isntall"; exit 0; }
  info "forcing (re)installation as ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc already exists"
else
  info "creating directory ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc"
  install -v -d -m755 "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc" >&5 2>&6
fi

#Get name of latest uClibc stage3
info "getting latest stage3 link for ${GENTOO_ARCH}"
GENTOO_AUTOBUILDS="${GENTOO_MIRROR}/releases/${GENTOO_ARCH}/autobuilds"
debug "fetching stage3 list from ${GENTOO_AUTOBUILDS}/latest-stage3.txt"
STAGE3_LINK="${GENTOO_AUTOBUILDS}/$(curl -s "${GENTOO_AUTOBUILDS}/latest-stage3.txt" | awk "/stage3-${GENTOO_ARCH}-uclibc-vanilla/{print \$1}")"
[ "${STAGE3_LINK}" = "${GENTOO_AUTOBUILDS}/" ] && error "failed to get latest stage3 archive link"
debug "found stage3 link : ${STAGE3_LINK}"

if [ -e "${INSTALL_DIR}/$(basename "${STAGE3_LINK}")" ]; then
  info "stage3 archive seems already downloaded to ${INSTALL_DIR}/$(basename "${STAGE3_LINK}")"
else
  info "fetching stage3 archive to ${INSTALL_DIR}/"
  curl "${STAGE3_LINK}" -o "${INSTALL_DIR}/$(basename "${STAGE3_LINK}")" || error "failed to fetch stage3 archive"
fi


