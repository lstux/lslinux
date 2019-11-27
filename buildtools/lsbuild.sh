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

#Default gcc-c[++] options
CFLAGS="${CFLAGS:-"-O2 -pipe"}"
CXXFLAGS="${CXXFLAGS:-${CFLAGS}}"
#Default options for configure script
CONFIGOPTS="${CONFIGOPTS:-"--prefix=/usr"}"
#Default options for make
NBCPU="$(egrep "^processor" /proc/cpuinfo | wc -l)"
MAKEOPTS="${MAKEOPTS:-"-j$((${NBCPU} + 1))"}"
#If binaries should be stripped and how (none|debug|unneeded|all)
STRIPMODE=unneeded

## split to doc package
DOCPKG=${DOCPKG:-false}
DOCPKG_PATTERNS="${DOCPKG_PATTERNS:-*/man/* */info/* */doc/* readme}"
## split to dev package
DEVPKG=${DEVPKG:-false}
DEVPKG_PATTERNS="${DEVPKG_PATTERNS:-*/pkgconfig *.h *.a *.la}"
## split to lib package
LIBPKG=${LIBPKG:-false}
LIBPKG_PATTERNS="${LIBPKG_PATTERNS:-*.so.*}"

#Verbosity level [0-2]
VERBOSE=${VERBOSE:-0}
#Debug mode
DEBUG=${DEBUG:-false}
#Shell used in debug mode
SHELL="${SHELL:-/bin/sh}"

#remove build directory on build success
CLEANBUILD="${CLEANBUILD:-true}"

#check/install build dependencies
NODEPS=false
#Step to resume
RESUME=0


#Define colors
red='\e[1;31m'; grn='\e[1;32m'; ylw='\e[1;33m'; blu='\e[1;34m'
mgt='\e[1;35m'; cyn='\e[1;36m'; wht='\e[1;37m'; nrm='\e[0m'


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
  printf "  -nodeps : don't check/install build dependencies\n"
  printf "  -r num  : resume build at specified step number\n"
  printf "  -s mode : strip binaries with --strip-mode (none|debug|[unneeded]|all)\n"
  printf "  -k      : keep build directory\n"
  printf "  -d      : enable debug mode (verbose++ and confirm at each step)\n"
  printf "  -v      : increase verbosity level\n"
  printf "  -h      : display this help message\n"
  exit 1
}


msg_common() {
  local lvl="${1}" pfx="${2}" msg="${3}" l
  if [ -n "${3}" ]; then
    [ ${VERBOSE} -ge ${lvl} ] || return 0
    printf "${pfx} ${msg}\n"
  else
    if [ ${VERBOSE} -lt ${lvl} ]; then cat > /dev/null
    else while read l; do
      printf "${pfx} ${l}\n"
    done; fi
  fi
}
message() { msg_common 0 "${grn}*${nrm}" "${1}"; }
info()    { msg_common 1 "${ylw}*${nrm}" "${1}"; }
debug()   { msg_common 2 "${ylw}dbg${nrm}" "${1}"; }
error()   { printf "${red}Error${nrm} : ${1}\n" >&2; [ "${2}" -gt 0 ] 2>/dev/null && exit ${2}; [ ${2} -eq 0 ] 2>/dev/null && return 0; exit 255; }
warning() { msg_common 1 "${ylw}Warning${nrm} : " "${1}" >&2; }

yesno() {
  local prompt="${1}" default="${2}" d="" choices="(${grn}y${nrm}/${ylw}n${nrm}/${cyn}s${nrm}/${red}c${nrm})" c
  case "${default}" in
    y|Y|yes|Yes)       choices="([${grn}y${nrm}]/${ylw}n${nrm}/${cyn}s${nrm}/${red}c${nrm})"; d=0;;
    n|N|no|No)         choices="(${grn}y${nrm}/[${ylw}n${nrm}]/${cyn}s${nrm}/${red}c${nrm})"; d=1;;
    c|C|cancel|Cancel) choices="(${grn}y${nrm}/${ylw}n${nrm}/${cyn}s${nrm}/[${red}c${nrm}])"; d=2;;
  esac
  while true; do
    printf "${grn}>${nrm} ${prompt} ${choices} " >&2; read c
    case "${c}" in
      y|Y|yes|Yes)       return 0;;
      n|N|no|No)         return 1;;
      c|C|cancel|Cancel) return 2;;
      s|S|shell|Shell)   printf "Running shell in '$(pwd)' :\n"; ${SHELL}; continue;;
      '')                [ -n "${d}" ] && return ${d};;
    esac
    printf "${red}**${nrm} Please answer with 'y' (yes), 'n' (no), 's' (run a shell and ask again), or 'c' (cancel)..."; sleep 2; printf "\n"
  done
}

conf_check() {
  local dname dir
  for dname in LSL_BASEDIR LSL_SRCDIR LSL_PKGDIR LSL_BUILDDIR LSL_DESTDIR LSL_LOGSDIR; do
    eval dir=\"\${${dname}}\"
    [ -d "${dir}" ] && continue
    yesno "${dname} directory '${dir}' does not exist, create it?" y || error "can't continue without an existing ${dname} directory" 2
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

parse_opts() {
  OPTIND=0
  while getopts n:r:s:kdvh opt; do case "${opt}" in
    n) case "${OPTARG}" in
         odeps) NODEPS=true;;
         *)     usage;;
       esac;;
    r) [ ${OPTARG} -gt 0 ] 2>/dev/null || usage "bad resume number, should be integer >= 0"; RESUME="${OPTARG}";;
    s) case "${OPTARG}" in
         none|debug|unneeded|all) STRIPMODE="${OPTARG}";;
         *)                       usage "bad strip mode '${OPTARG}', should be one of none, debug, unneeded or all";;
       esac;;
    k) CLEANBUILD=false;;
    d) DEBUG=true; VERBOSE=2;;
    v) VERBOSE="$(expr ${VERBOSE} + 1)";;
    *) usage;;
  esac; done
}

STEPCOUNT=0
step() {
  local steplabel="${1}"; shift
  STEPCOUNT=$((STEPCOUNT + 1))
  if ${DEBUG} && [ ${STEPCOUNT} -ge ${RESUME} ]; then
    yesno "${STEPCOUNT} ${steplabel}" y
    case "$?" in
      2) printf "${red}Aborting${nrm}\n" >&2; exit 255;;
      1) return 1;;
    esac
  else
    printf "${grn}>${nrm} ${STEPCOUNT} ${steplabel}\n"
    [ ${RESUME} -ne 0 -a ${STEPCOUNT} -lt ${RESUME} ] && return 1
  fi
  return 0
}

bdeps_check() {
  local deps="${1}"
  step "checking build dependencies" || return 1
  ${NODEPS} && return 0
}

sources_download() {
  local link="${1}" dest="${2}"
  step "downloading sources to '${dest}'" || return 1
  if ! [ -e "${dest}" ]; then
    curl -o "${dest}" "${link}" || error "failed to download sources archive from '${link}'" 2
  else
    debug "Sources archive already available : ${dest}"
  fi
}

sources_extract() {
  local archive="${1}" srcdir="${2}" extractdir
  step "extracting sources to '${srcdir}'" || return 1
  if ! [ -d "${srcdir}" ]; then
    extractdir="$(dirname "${srcdir}")"
    case "${archive}" in
      *.tar.gz|*.tgz)   tar xvzf "${archive}" -C "${extractdir}";;
      *.tar.bz2|*.tbz2) tar xvjf "${archive}" -C "${extractdir}";;
      *.tar.xz|*.txz)   tar xvJf "${archive}" -C "${extractdir}";;
      *.zip|*.ZIP)      unzip "${archive}" -d "${extractdir}";;
      *)                error "unhandled archive format '$(basename "${archive}")'" 3
    esac
    [ $? -eq 0 ] || error "failed to extract sources archive" 3
  else
    debug "Sources already available in '${srcdir}', remove folder to extract again"
  fi
}

dokconf_set() {
  local config="${LSL_BUILDDIR}/${SRCDIRNAME}/.config" kv="${1}" key val
  key="${kv%%=*}"
  val="${kv##*=}"
  [ "${val}" != "${kv}" ] && val="\"${val}\"" || val="y"
  if egrep -q "^${key}=" "${config}"; then
    sed -i "s@^${key}=.*@${key}=${val}@" "${config}"
  else
    sed -i "s@^# ${key} is not set@${key}=${val}@" "${config}"
  fi
}

dokconf_unset() {
  local config="${LSL_BUILDDIR}/${SRCDIRNAME}/.config" key="${1}"
  sed -i "s/^${key}=.*/# ${key} is not set/" "${config}"
}

dokconf() {
  local config="${LSL_BUILDDIR}/${SRCDIRNAME}/.config"
  if [ -e "${1}" ]; then
    install -v "${1}" "${config}" && make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" oldconfig
  else
    make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" "${1}"
  fi
  shift
  local action=set k
  for k in "$@"; do case "${k}" in
    set|unset) action="${k}";;
    *)         eval dokconf_${action} \"${k}\";;
esac; done
}

doconf() {
  step "configuring sources" || return 1
  case "${1}" in
    "") cd "${LSL_BUILDDIR}/${SRCDIRNAME}" && ./configure ${CONFIGOPTS};;
    -*) cd "${LSL_BUILDDIR}/${SRCDIRNAME}" && ./configure "$@";;
    *)  dokconf "$@";;
  esac
  [ $? -eq 0 ] || error "configuration failed"
}

dobuild() {
  step "building sources" || return 1
  make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" ${MAKEOPTS} || error "build failed"
}

doinstall() {
  step "installing" || return 1
  local destdir="DESTDIR"
  OPTIND=0; while getopts d: opt; do case "${opt}" in
    d) destdir="${OPTARG}"
  esac; done
  make -C "${LSL_BUILDDIR}/${SRCDIRNAME}" ${destdir}="${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}" install || error "installation failed"
}

groupcheck() {
  local groupinfos="${1}"
  [ -n "${groupinfos}" ] || return 0
  local gname="${groupinfos%%:*}" gid="${groupinfos##*:}"
  [ -n "${gname}" -a -n "${gid}" ] || error "bad ADDGROUP format, should be ADDGROUP=\"groupname:gid\"" 7
  step "adding group '${gname}' with gid ${gid}" || return 1
  if egrep -q "^${gname}:" /etc/group; then
    local lgid="$(awk -F":" "/^${gname}:/{print \$3}" /etc/group)"
    if [ "${lgid}" != "${gid}" ]; then warning "group '${gname}' already present but with gid ${lgid} instead of ${gid}"
    else info "group '${gname}' already present"; fi
    return 0
  fi
  local lgname="$(awk -F":" "/:x:${gid}:/{print \$1}" /etc/group)"
  [ -n "${lgname}" ] && error "GID ${gid} is already used by group '${lgname}'" 7
  groupadd -g${gid} ${gname} || error "failed to add group '${gname}' (gid=${gid})" 7
}

usercheck() {
  local userinfos="${1}" uname uid ugroup uhome ushell
  [ -n "${userinfos}" ] || return 0
  uname="$(echo "${userinfos}" | awk -F":" '{print $1}')"
  uid="$(echo "${userinfos}" | awk -F":" '{print $2}')"
  ugroup="$(echo "${userinfos}" | awk -F":" '{print $3}')"
  [ -n "${uname}" -a -n "${uid}" -a -n "${ugroup}" ] || error "badd ADDUSER format, should be ADDUSER=\"username:uid:primarygroup[:homedir=/home/username[:shell=/sbin/nologin]]\"" 8
  uhome="$(echo "${userinfos}" | awk -F":" '{print $4}')"; [ -n "${uhome}" ] || uhome="/home/${uname}"
  ushell="$(echo "${userinfos}" | awk -F":" '{print $5}')"; [ -n "${ushell}"] || ushell="/sbin/nologin"
  step "adding user '${uname}' with uid ${uid} (group ${ugroup}, homedir ${uhome}, login shell ${lshell}" || return 1
  if egrep -q "^${uname}:" /etc/passwd; then
    local luid lgroup lhome lshell
    luid="$(awk -F":" "/^${uname}:/{print \$3}" /etc/passwd)"
    lgroup="$(awk -F":" "/^${uname}:/{print \$4}" /etc/passwd)"; lgroup="$(awk -F":" "/:x:${lgroup}:/{print \$1}" /etc/group)"
    lhome="$(awk -F":" "/^${uname}:/{print \$6}" /etc/passwd)"
    lshell="$(awk -F":" "/^${uname}:/{print \$7}" /etc/passwd)"
    if [ "${luid}" = "${uid}" -a "${lgroup}" = "${ugroup}" -a "${uhome}" = "${lhome}" -a "${lshell}" = "${ushell}" ]; then
      info "user '${uname}' already present"
    else
      local warn_details="";
      [ "${luid}" != "${uid}" ] && warn_details="${warn_details}uid=${luid} instead of ${uid}, "
      [ "${lgroup}" != "${ugroup}" ] && warn_details="${warn_details}group=${lgroup} instead of ${ugroup}, "
      [ "${lhome}" != "${uhome}" ] && warn_details="${warn_details}home=${lhome} instead of ${uhome}, "
      [ "${lshell}" != "${ushell}" ] && warn_details="${warn_details}shell=${lshell} instead of ${ushell}, "
      warn_details="$(echo "${warn_details}" | sed 's/, $//')"
      warning "user '${uname}' already present but with ${warn_details}"
    fi
    return 0
  fi
  local luname="$(awk -F":" "\$3==${uid} {print \$1}" /etc/passwd)"
  [ -n "${luname}" ] && error "UID ${uid} is already used by user '${luname}'" 8
  useradd -c "added by $(basename "${0}")" -r -d "${uhome}" -g "${ugroup}" -s "${ushell}" -u "${uid}" "${uname}" || error "failed to add user '${uname}' (uid=${uid})" 8
}

binstrip() {
  local bindir="${1}" f binsize stripsize stripopts
  step "stripping binaries in '${bindir}'" || return 1
  case "${STRIPMODE}" in
    none)               return 0;;
    debug|unneeded|all) stripopts="--strip-${STRIPMODE}";;
    *)                  error "bad STRIPMODE '${STRIPMODE}', supported values are none, debug, unneeded or all";;
  esac
  if [ ${VERBOSE} -ge 1 ]; then
    binsize="$(du -s "${bindir}" | awk '{print $1}')"
    info "${bindir} size : ${binsize}Kbytes"
  fi
  find "${bindir}" -type f -executable | while read f; do
    case "$(file "${f}")" in
      *"not stripped"*) info "${f} stripping"; strip ${stripopts} "${f}";;
      *"stripped"*)     info "${f} already stripped";;
      *)                debug "${f} not strippable";;
    esac
  done
  if [ ${VERBOSE} -ge 1 ]; then
    stripsize="$(du -s "${bindir}" | awk '{print $1}')"
    info "${bindir} size after stripping : ${stripsize}Kbytes"
    info "  gained $((${binsize} - ${stripsize}))Kbytes"
  fi
  return 0
}

mancompress() {
  local bindir="${1}" f binsize compsize
  step "compressing man/info pages" || return 1
  if [ ${VERBOSE} -ge 1 ]; then
    binsize="$(du -s "${bindir}" | awk '{print $1}')"
    info "${bindir} size : ${binsize}Kbytes"
  fi
  find "${bindir}" -type f -a \( -wholename "*/info/*" -o -wholename "*/man/*" -o -iname readme \) | while read f; do
    case "${f}" in
      *.gz|*.bz2) info "${f} already compressed";;
      *)          info "${f} compressing"; bzip2 -9 "${f}";;
    esac
  done
  if [ ${VERBOSE} -ge 1 ]; then
    compsize="$(du -s "${bindir}" | awk '{print $1}')"
    info "${bindir} size after compressing : ${compsize}Kbytes"
    info "  gained $((${binsize} - ${compsize}))Kbytes"
  fi
  return 0
}

pkgsplit_mktree() {
  local srcdir="${1}" dstdir="${2}" f="${3}"
  [ -d "${dstdir}" ] || install -v -d -m755 "${dstdir}" || return 1
  [ -d "${dstdir}/$(dirname "${f}")" ] || pkgsplit_mktree "${srcdir}" "${dstdir}" "$(dirname "${f}")"
  install -v -d $(stat --format "-m%a -o%U -g%G" "${srcdir}/${f}") "${dstdir}/${f}"
}

pkgsplit_rmvoiddirs() {
  local dir="$(dirname "${1}")"
  [ -n "$(ls "${dir}")" ] && return 0
  rmdir "${dir}" || return 1
  pkgsplit_rmvoiddirs "${dir}"
}

pkgsplit() {
  local opt desc="" deps=""
  OPTIND=0; while getopts d:D: opt; do case "${opt}" in
    d) desc="${OPTARG}";;
    D) deps="${OPTARG}";;
  esac; done
  shift $((${OPTIND} - 1))
  local sub="${1}" patterns="${2}" findopts="" p f
  local bindir="${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}"
  local dstdir="${LSL_DESTDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}"
  step "splitting to $(basename "${dstdir}")"
  [ -n "${desc}" ] || desc="${PKG_NAME} ${sub} subpackage"
  for p in ${patterns}; do
    echo "${p}" | grep -q "/" && findopts="${findopts}-ipath '${p}' -o " \
                              || findopts="${findopts}-iname '${p}' -o "
  done
  findopts="$(echo "${findopts}" | sed 's/ -o $//')"
  eval find \"${bindir}\" ${findopts} | sed "s@^${bindir}/\?@@" | while read f; do
    fdir="$(dirname "${f}")"
    [ -d "${dstdir}/${fdir}" ] || pkgsplit_mktree "${bindir}" "${dstdir}" "${fdir}" || return 1
    mv -v "${bindir}/${f}" "${dstdir}/${f}" || return 2
    pkgsplit_rmvoiddirs "${bindir}/${f}"
  done
  eval ${sub}_DESCRIPTION=\"${desc}\"
  eval ${sub}_DEPENDS=\"${deps}\"
  SUBPACKAGES="${SUBPACKAGES} ${sub}"
}

libdeps() {
  local bindir="${1}" l
  find "${bindir}" -type f -executable -exec ldd {} \; 2>/dev/null | \
    sed -n -e '/linux-vdso.so/d' -e '/ld64-uClibc.so/d' -e '/libc.so/d' -e 's/\t\(.\+\) =>.*/\1/p' | \
    sort -u | { while read l; do printf "$(basename "${l}") "; done; printf "\n"; } | sed "s/ \$//"
}



parse_opts "$@"; shift $(expr ${OPTIND} - 1)
BUILDSCRIPT="$(realpath "${1}" 2>/dev/null)"
[ -n "${BUILDSCRIPT}" ] || usage
[ -e "${BUILDSCRIPT}" ] || usage "'${BUILDSCRIPT}', no such file"
shift
parse_opts "$@"; shift $(expr ${OPTIND} - 1)
[ -n "${1}" ] && usage "unhandled argument(s) '$*'"
conf_check

BSCRIPT="$(basename "${BUILDSCRIPT}" | sed 's/\.\(sh\|lsl\|lsb\)$//')"
PKG_NAME="$(echo "${BSCRIPT}" | sed 's/^\(.\+\)_.\+_[0-9]\+$/\1/')"
PKG_VERSION="$(echo "${BSCRIPT}" | sed 's/^.\+_\(.\+\)_[0-9]\+$/\1/')"
PKG_REVISION="$(echo "${BSCRIPT}" | sed 's/^.\+_.\+_\([0-9]\+\)$/\1/')"

export PS1="${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION} \[\033[01;31m\]\u@\h \[\033[01;34m\]\w #\[\033[00m\] "
LOGSFILE="${LSL_LOGSDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}.log"

PKG_SRCLINK="$(sed -n "s/^[# ]*SRCLINK=[\"']\?\([^\"']\+\)[\"']\? *\$/\1/p" "${BUILDSCRIPT}")"
PKG_SRCLINK="$(echo "${PKG_SRCLINK}" | sed -e "s/{{pkgname}}/${PKG_NAME}/g" -e "s/{{version}}/${PKG_VERSION}/g" -e "s/{{revision}}/${PKG_REVISION}/g")"

if egrep -q "^SRCDIR=" "${BUILDSCRIPT}"; then
  SRCDIRNAME="$(sed -n "s/^[# ]*SRCDIR=[\"']\?\([^\"']\+\)[\"']\? *\$/\1/p" "${BUILDSCRIPT}")"
  SRCDIRNAME="$(echo "${SRCDIRNAME}" | sed -e "s/{{pkgname}}/${PKG_NAME}/g" -e "s/{{version}}/${PKG_VERSION}/g" -e "s/{{revision}}/${PKG_REVISION}/g")"
else
  SRCDIRNAME="${PKG_NAME}-${PKG_VERSION}}"
fi
SOURCESDIR="${LSL_BUILDDIR}/${SRCDIRNAME}"
INSTALLDIR="${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}"

### Check for build dependencies
PKG_BUILDDEPS="$(sed -n "s/^[# ]*BUILD_DEPENDS=[\"']\?\([^\"']\+\)[\"']\? *\$/\1/p" "${BUILDSCRIPT}")"
bdeps_check ${PKG_BUILDDEPS}

### Download source package to LSL_SRCDIR
PKG_LOCALARCH="${LSL_SRCDIR}/$(basename "${PKG_SRCLINK}")"
sources_download "${PKG_SRCLINK}" "${PKG_LOCALARCH}"

### Extract source package to LSL_BUILDDIR
sources_extract "${PKG_LOCALARCH}" "${SOURCESDIR}"

### Source ${BUILDSCRIPT} which should take care of configuring/building/installing with helper functions
source "${BUILDSCRIPT}"

### Create user/group if needed
groupcheck "${ADDGROUP}"
usercheck "${ADDUSER}"

### Install files from ${ADDFILES}

### Strip binaries
binstrip "${INSTALLDIR}"

### Compress man/info files
mancompress "${INSTALLDIR}"

### Split package
SUBPACKAGES=""
if ${DOCPKG}; then
  pkgsplit -d "${PKG_NAME} documentation" doc "${DOCPKG_PATTERNS}"
fi
if ${DEVPKG}; then
  pkgsplit -d "${PKG_NAME} developpement files" -D "$(${LIBPKG} && echo "${PKG_NAME}-lib" || echo "${PKG_NAME}")" dev "${DEVPKG_PATTERNS}"
fi
if ${LIBPKG}; then
  pkgsplit -d "${PKG_NAME} libraries" -D "${PKG_NAME}" lib "${LIBPKG_PATTERNS}"
fi

### for each package/subpackage, generate pkginfos and create archive
for sub in ${SUBPACKAGES}; do
  eval subdescription=\"\${${sub}_DESCRIPTION}\"
  eval subdepends=\"\${${sub}_DEPENDS}\"
  step "creating ${PKG_NAME}-${sub} subpackage" || continue
  {
    cd "${LSL_DESTDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}" && tar cvjf - ./*
    cat << EOF

### LSL PACKAGE INFOS ###
NAME=${PKG_NAME}-${sub}
VERSION=${PKG_VERSION}
REVISION=${PKG_REVISION}
DESCRIPTION="${subdescription}"
DEPENDS="${subdepends}"
DYNDEPS="$(libdeps "${LSL_DESTDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}")"
HOMEPAGE="${HOMEPAGE}"
SRCLINK="$( echo "${SRCLINK}" | sed -e "s/{{pkgname}}/${PKG_NAME}/g" -e "s/{{version}}/${PKG_VERSION}/g" -e "s/{{revision}}/${PKG_REVISION}/g")"
SIZE="$(du -sk "${LSL_DESTDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}" | awk '{print $1}')"
EOF
  } > "${LSL_PKGDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}.tbz2"
done

step "creating ${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION} package" && {
  {
    cd "${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}" && tar cvjf - ./*
    cat << EOF

### LSL PACKAGE INFOS ###
NAME=${PKG_NAME}
VERSION=${PKG_VERSION}
REVISION=${PKG_REVISION}
DESCRIPTION="${DESCRIPTION}"
DEPENDS="${DEPENDS}"
DYNDEPS="$(libdeps "${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}")"
HOMEPAGE="${HOMEPAGE}"
SRCLINK="$( echo "${SRCLINK}" | sed -e "s/{{pkgname}}/${PKG_NAME}/g" -e "s/{{version}}/${PKG_VERSION}/g" -e "s/{{revision}}/${PKG_REVISION}/g")"
SIZE="$(du -sk "${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}" | awk '{print $1}')"
EOF
  } > "${LSL_PKGDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}.tbz2"
}


### Remove installdirs and builddir if requested
for sub in ${SUBPACKAGES}; do rm -rf "${LSL_DESTDIR}/${PKG_NAME}-${sub}-${PKG_VERSION}-${PKG_REVISION}"; done
rm -rf "${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}"
${CLEANBUILD} && rm -rf "${LSL_BUILDDIR}/${SRCDIRNAME}"
