#!/bin/sh
PKG_NAME=
PKG_VERSION=
PKG_REVISION=
PKG_SRCLINK=

CONFFILES="/etc/lsbuild.conf ~/.lsbuild.conf ./lsbuild.conf"
for conf in ${CONFFILES}; do [ -e "${conf}" ] && source "${conf}"; done

LSL_BASEDIR="${LSL_BASEDIR:-/var/lsbuild}"
#Directory to store source packages
LSL_SRCDIR="${LSL_SRCDIR:-${LSL_BASEDIR}/sources}"
#Directory to store lsl compiled packages
LSL_PKGDIR="${LSL_PKGDIR:-${LSL_BASEDIR}/dist}"
#Directory to build packages (where to extract sources)
LSL_BUILDDIR="${LSL_BUILDDIR:-${LSL_BASEDIR}/build}"
#Directory to install packages
LSL_DESTDIR="${LSL_DESTDIR:-${LSL_BASEDIR}/install}"
# Directory to store build logs
LSL_LOGSDIR="${LSL_LOGSDIR:-${LSL_BASEDIR}/logs}"

CFLAGS="${CFLAGS:-"-O2 -pipe"}"
CXXFLAGS="${CXXFLAGS:-${CFLAGS}}"
CONFIGOPTS="${CONFIGOPTS:-"--prefix=/usr --disable-nls"}"
NBCPU="$(egrep "^processor" /proc/cpuinfo | wc -l)"
MAKEOPTS="${MAKEOPTS:-"-j$((${NBCPU} + 1))"}"

#Verbosity level [0-2]
VERBOSE=${VERBOSE:-0}
#Debug mode
DEBUG=${DEBUG:-false}
#check/install build dependencies
NODEPS=false



#Start time and functions to display elapsed time
START_TIME="$(date +%s%N)"
elapsed() {
  local nanodiff="$(($(date +%s%N) - ${START_TIME}))" div="1000000"
  [ "${1}" = "-s" ] && div="1000000000"
  echo $((${nanodiff} / ${div}))
}
millis()  { elapsed; }
seconds() { elapsed -s; }



usage() {
  exec >&2
  [ -n "${1}" ] && printf "${red}Error${nrm} : ${1}\n"
  printf "Usage : $(basename "${0}") [options] buildscript\n"
  printf "  Build LSL package from sources\n"
  printf "options :\n"
  printf "  -nodeps : don't check/install build dependencies"
  printf "  -d      : enable debug mode (verbose++ and confirm at each step)\n"
  printf "  -v      : increase verbosity level\n"
  printf "  -h      : display this help message\n"
  exit 1
}

message() { printf "${grn}*${nrm} $1\n"; }
info()    { [ ${VERBOSE} -ge 1 ] || return 0; printf "${ylw}*${nrm} ${1}\n"; }
debug()   { [ ${VERBOSE} -ge 2 ] || return 0; printf "${ylw}dbg${nrm} ${1}\n"; }
error()   { printf "${red}Error${nrm} : ${1}\n" >&2; [ "${2}" -gt 0 ] 2>/dev/null && exit ${2}; [ ${2} -eq 0 ] 2>/dev/null && return 0; exit 255; }
warning() { [ ${VERBOSE} -ge 1 ] || return 0; printf "${ylw}Warning${nrm} : ${1}\n"; }

yesno() {
  local prompt="${1}" default="${2}" d="" choices="(${grn}y${nrm}/${red}n${nrm}/${ylw}c${nrm})" c
  case "${default}" in
    y|Y|yes|Yes)       choices="([${grn}y${nrm}]/${red}n${nrm}/${ylw}c${nrm})"; d=0;;
    n|N|no|No)         choices="(${grn}y${nrm}/[${red}n${nrm}]/${ylw}c${nrm})"; d=1;;
    c|C|cancel|Cancel) choices="(${grn}y${nrm}/${red}n${nrm}/[${ylw}c${nrm}])"; d=2;;
  esac
  while true; do
    printf "${grn}>${nrm} ${prompt} ${choices} " >&2; read c
    case "${c}" in
      y|Y|yes|Yes)       return 0;;
      n|N|no|No)         return 1;;
      c|C|cancel|Cancel) return 2;;
      '')                [ -n "${d}" ] && return ${d};;
    esac
    printf "${red}**${nrm} Please answer with 'y' (yes), 'n' (no) or 'c' (cancel)..."; sleep 2; printf "\n";;
  done
}

conf_check() {
  local dname dir
  for dname in LSL_BASEDIR LSL_SRCDIR LSL_PKGDIR LSL_BUILDDIR LSL_DESTDIR LSL_LOGSDIR; do
    eval dir=\"\${${dname}}\"
    [ -d "${dir}" ] && continue
    yesno "${dname} directory '${d}' does not exist, create it?" y || error "can't continue without an existing ${dname} directory" 2
    install -d -m755 "${dir}" || error "failed to create ${dname} directory" 2
  done

  if ! [ ${VERBOSE} -ge 0 ] 2>/dev/null; then
    warning "bad value for VERBOSE configuration, should be a positive integer. Defaulting to 0."
    VERBOSE=0
  fi

  if ! [ "${DEBUG}" = "true" -o "${DEBUG}" = "false" ]; then
    warning "bad value for DEBUG configuration, should be 'false' or 'true'. Defaulting to 'false'."
    DEBUG=false
  fi
}

bdeps_check() {
  ${NODEPS} && return 0
}

parse_opts() {
  OPTIND=0
  while getopts n:dvh opt; do case "${opt}" in
    n) case "${OPTARG}" in
         odeps) NODEPS=true;;
         *)     usage;;
       esac;;
    d) DEBUG=true; VERBOSE=2;;
    v) VERBOSE="$(expr ${VERBOSE} + 1)";;
    *) usage;;
  esac; done
}

step() {
  local steplabel="${1}"; shift
  yesno "${steplabel}" y
  case "$?" in
    2) printf "${red}Aborting${nrm}" >&2; exit 255;;
    1) return 1;;
  esac
}

doconf() {
  if [ -e "${LSL_BUILDDIR}/${SRCDIRNAME}/Makefile" ]; then
    debug "looks like sources are already configured, remove Makefile to (re)configure"
  else
    cd "${LSL_BUILDDIR}/${SRCDIRNAME}" && ./configure ${CONFIGOPTS}
  fi
}

dobuild() {
  make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" ${MAKEOPTS}    
}

doinst() {
  make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" DESTDIR="${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}" install
}

parse_opts "$@"; shift $(expr ${OPTIND} - 1)
BUILDSCRIPT="$(realpath "${1}")"
[ -n "${BUILDSCRIPT}" ] || usage
[ -e "${BUILDSCRIPT}" ] || usage "'${BUILDSCRIPT}', no such file"
shift
parse_opts "$@"; shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] && usage "unhandled argument(s) '$*'"
conf_check

BSCRIPT="$(basename "${BUILDSCRIPT}" | sed 's/\.\(sh\|lsl\|lsb\)$//')"
#PKG_NAME="$(echo "${BSCRIPT}" | awk -F"_" '{print $1}')"
#PKG_VERSION="$(echo "${BSCRIPT}" | awk -F"_" '{print $2}')"
#PKG_REVISION="$(echo "${BSCRIPT}" | awk -F"_" '{print $3}')"
PKG_NAME="$(echo "${BSCRIPT}" | sed 's/^\(.\+\)_.\+_[0-9]\+$/\1/')"
PKG_VERSION="$(echo "${BSCRIPT}" | sed 's/^.\+_\(.\+\)_[0-9]\+$/\1/')"
PKG_REVISION="$(echo "${BSCRIPT}" | sed 's/^.\+_.\+_\([0-9]\+\)$/\1/')"

PKG_SRCLINK="$(sed -n "s/^[# ]*SRCLINK=[\"']\?\([^\"']\+\)[\"']\? *\$/\1/p" "${BUILDSCRIPT}")"
PKG_SRCLINK="$(echo "${PKG_SRCLINK}" | sed -e "s/{{pkgname}}/${PKG_NAME}/" -e "s/{{version}}/${PKG_VERSION}/" -e "s/{{revision}}/${PKG_REVISION}/")"


### Download source package to LSL_SRCDIR
PKG_LOCALARCH="${LSL_SRCDIR}/$(basename "${PKG_SRCLINK}")"
if ! [ -e "${PKG_LOCALARCH}" ]; then
  curl -o "${PKG_LOCALARCH}" "${PKG_SRCLINK}" || error "failed to download sources archive from '${PKG_SRCLINK}'" 2
else
  debug "Sources archive already available : ${PKG_LOCALARCH}"
fi

### Extract source package to LSL_BUILDDIR
SRCDIRNAME="${SRCDIRNAME:-${PKG_NAME}-${PKG_VERSION}}"
if ! [ -d "${LSL_BUILDDIR}/${SRCDIRNAME}" ]; then
  case "${PKG_LOCALARCH}" in
    *.tar.gz|*.tgz)   tar xzf "${PKG_LOCALARCH}" -C "${LSL_BUILDDIR}";;
    *.tar.bz2|*.tbz2) tar xjf "${PKG_LOCALARCH}" -C "${LSL_BUILDDIR}";;
    *.tar.xz|*.txz)   tar xJf "${PKG_LOCALARCH}" -C "${LSL_BUILDDIR}";;
    *.zip|*.ZIP)      unzip "${PKG_LOCALARCH}" -d "${LSL_BUILDDIR}";;
    *)                error "unhandled archive format '$(basename "${PKG_LOCALARCH}")'" 3
  esac
else
  debug "Sources already available in '${LSL_BUILDDIR}/${SRCDIRNAME}', remove folder to extract again"
fi

### Apply patches if any

### Configure sources

### Build sources

### Install to LSL_DESTDIR

