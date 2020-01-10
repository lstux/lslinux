#!/bin/sh
GENTOO_MIRROR="${GENTOO_MIRROR:-http://ftp.free.fr/mirrors/ftp.gentoo.org}"
GENTOO_ARCH="${GENTOO_ARCH:-amd64}"
INSTALLDIR="${INSTALLDIR:-}"
VERBOSE="${VERBOSE:-0}"
FORCE=false

usage() {
  exec >&2
  printf "Usage : $(basename "${0}") [options] install_dir\n"
  printf "  Install a Gentoo uClibc-ng root to install_dir/gentoo-\${arch}-uclibc\n"
  printf "options :\n"
  printf "  -a arch : select architecture (defaults to ${GENTOO_ARCH})\n"
  printf "  -f      : force (re)installation\n"
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
  [ ${VERBOSE} -ge 2 ] || return 0
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
[ "$(id -un)" != "root" ] && error "this script should be run as root" 2
exec 5>/dev/null 6>/dev/null
[ ${VERBOSE} -ge 2 ] && exec 5>&1
[ ${VERBOSE} -ge 1 ] && exec 6>&2

if ! [ -d "${INSTALLDIR}" ]; then
  info "creating installation directory '${INSTALLDIR}'"
  install -v -d -m755 "${INSTALLDIR}" >&5 2>&6
fi

if [ -d "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/bin" ]; then
  ${FORCE} || { printf "gentoo stage3 seems already installed in ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc\n"; printf "remove directory or use -f option to (re)isntall\n"; exit 0; }
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
[ "${STAGE3_LINK}" = "${GENTOO_AUTOBUILDS}/" ] && error "failed to get latest stage3 archive link" 4
debug "found stage3 link : ${STAGE3_LINK}"

if [ -e "${INSTALLDIR}/$(basename "${STAGE3_LINK}")" ]; then
  info "stage3 archive seems already downloaded to ${INSTALLDIR}/$(basename "${STAGE3_LINK}")"
else
  info "fetching stage3 archive to ${INSTALLDIR}/"
  curl "${STAGE3_LINK}" -o "${INSTALLDIR}/$(basename "${STAGE3_LINK}")" || error "failed to fetch stage3 archive" 8
fi

info "extracting stage3 archive to ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/"
tar xjpf "${INSTALLDIR}/$(basename "${STAGE3_LINK}")" -C "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/"

[ -d "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/portage/repos.conf" ] || install -v -d -m755 "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/portage/repos.conf"
[ -e "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/portage/repos.conf/gentoo.conf" ] || \
  install -v -m644 "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/usr/share/portage/config/repos.conf" "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/portage/repos.conf/gentoo.conf"

#Get latest portage snapshot
if [ -e "${INSTALLDIR}/portage-latest.tar.xz" ]; then
  info "latest portage archive already downloaded to ${INSTALLDIR}/portage-latest.tar.xz"
else
  info "fetching latest portage snapshot"
  curl "${GENTOO_MIRROR}/snapshots/portage-latest.tar.xz" -o "${INSTALLDIR}/portage-latest.tar.xz" || error "failed to fetch latest portage snapshot" 16
fi

info "extracting latest portage to ${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos/gentoo"
[ -d "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos" ] || install -v -d -m755 "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos"
tar xJpf "${INSTALLDIR}/portage-latest.tar.xz" -C "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos" && \
  mv -v "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos/portage" "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/var/db/repos/gentoo"

diff /etc/resolv.conf "${INSTALLDIR}/etc/resolv.conf" >/dev/null 2>&1 && cp -v -L /etc/resolv.conf "${INSTALLDIR}/etc/resolv.conf"

install -v -d -m755 "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/"lslinux-build >&5 2>&6

echo -e "export PS1=\"gentoo-uClibc-ng \${PS1}\"" >> "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/bash/bashrc"
echo -e "alias ls=\"ls --color\"" >> "${INSTALLDIR}/gentoo-${GENTOO_ARCH}-uclibc/etc/bash/bashrc"
