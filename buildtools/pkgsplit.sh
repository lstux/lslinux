#!/bin/sh
VERBOSE=${VERBOSE:-0}

DEVPKG=false
DEVPATTERNS="'*.h' '*.a' '*.la'"
LIBPKG=false
LIBPATTERNS="*.so.* *.so"
DOCPKG=false
DOCPATTERNS="*/man/* */info/* README"

BINSTRIP=false
STRIPMODE="unneeded"
DOCCOMPRESS=false
COMPRESSOR="xz"
COMPRESSION_LEVEL="9"

INSTALLDIR=

usage() {
  exec >&2
  [ -n "${1}" ] && printf "Error : ${1}\n"
  printf "Usage : $(basename "${0}") [options] installdir\n"
  printf "  Split installdir into [dev|lib|doc] packages and/or\n"
  printf "  strip binaries and/or compress docfiles"
  printf "options :\n"
  printf "  -dev     : split into dev package (${DEVPATTERNS})\n"
  printf "  -lib     : split into lib package (${LIBPATTERNS})\n"
  printf "  -doc     : split into doc package (${DOCPATTERNS})\n"
  printf "  -s       : strip unneeded symbols from binaries\n"
  printf "  -S       : strip all symbols from binaries\n"
  printf "  -D       : strip debug symbols only from binaries"
  printf "  -c       : compress docs\n"
  printf "  -C tool  : use tool to compress docs {gzip|bzip2|[xz]}\n"
  printf "  -0 .. -9 : specify compression level (default is ${COMPRESSION_LEVEL})\n"
  printf "  -v       : increase verbosity level\n"
  printf "  -h       : display this help message\n"
  exit 0
}


msg() { printf "[MSG] ${1}\n"; }
msg_stream() { sed 's/^/[MSG] /'; }
nfo() { [ ${VERBOSE} -ge 1 ] || return 0; printf "[NFO] ${1}\n" >&2; }
nfo_stream() { if [ ${VERBOSE} -ge 1 ]; then sed 's/^/[NFO] /' >&2; else cat >/dev/null; fi; }
dbg() { [ ${VERBOSE} -ge 2 ] || return 0; printf "[DBG] ${1}\n" >&2; }
dbg_stream() { if [ ${VERBOSE} -ge 2 ]; then sed 's/^/[DBG] /' >&2; else cat >/dev/null; fi; }
err() { printf "[ERR] ${1}\n" >&2; [ ${2} -ge 1 ] 2>/dev/null && exit ${2}; [ "${2}" = "0" ] && return 0; exit 255; }


# Create INSTALLDIR-ext/d and subdirectories with same permissions than INSTALLDIR/d
dirinst() {
  local d="${1}" ext="${2}" dn="$(dirname "${1}")"
  [ -d "${INSTALLDIR}-${ext}/${dn}" ] || dirinst "${dn}" "${ext}" || return 1
  install -v $(stat -c "-m%a -o%U -g%G" "${INSTALLDIR}/${d}") "${INSTALLDIR}-${ext}/${dn}"
}

# Move file from INSTALLDIR to INSTALLDIR-ext, creating subdirectories with same permissions has original
filemove() {
  local f="${1}" ext="${2}" dn="$(dirname "${1}")"
  [ -d "${INSTALLDIR}-${ext}/${dn}" ] || dirinst "${dn}" "${ext}" || return 1
  mv -v "${f}" "${INSTALLDIR}-${ext}/${f}"
}


while getopts d:l:sSDcC0123456789vh opt do; case "${opt}" in
  d) case "${OPTARG}" in
       "ev") DEVPKG=true;;
       "oc") DOCPKG=true;;
       *)    usage;;
     esac;;
  l) case "${OPTARG}" in
       "ib") LIBPKG=true;;
       *)    usage;;
     esac;;
  s) BINSTRIP=true; STRIPMODE="unneeded";;
  S) BINSTRIP=true; STRIPMODE="all";;
  D) BINSTRIP=true; STRIPMODE="debug";;
  c) DOCCOMPRESS=true;;
  C) case "${OPTARG}" in
       gzip|bzip2|xz) COMPRESSOR="${OPTARG}";;
       *)             usage "only gzip, bzip2 and xz compressors are supported";;
     esac;;
  [0-9]) COMPRESSION_LEVEL="${OPTARG}";;
  v) VERBOSE=$(expr ${VERBOSE} + 1);;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
INSTALLDIR="${1}"
[ -n "${INSTALLDIR}" ] || usage
[ -d "${INSTALLDIR}" ] || usage "'${INSTALLDIR}', no such directory\n"
#Remove eventual leading / from INSTALLDIR
INSTALLDIR="$(echo "${INSTALLDIR}" | sed 's/\/$//')"

${BINSTRIP} || ${DOCCOMPRESS} || ${DEVPKG} || ${LIBPKG} || ${DOCPKG} || usage "at least one of -dev, -lib, -doc, -s or -c option is required"
TOTALSIZE="$(du -s "${INSTALLDIR}" | awk '{print $1}')"

if ${BINSTRIP}; then
  msg "Stripping binaries"
  find "${INSTALLDIR}" -type f -executable | while read f; do
    case "$(file "${f}")" in
      *"not stripped") nfo "  stripping ${f}"; strip --strip-${STRIPMODE} "${f}";;
      *" stripped")    dbg "  already stripped ${f}";;
      *)               dbg "  unstrippable executable ${f}";;
    esac
  done
  BINSIZE="$(du -s "${INSTALLDIR}" | awk '{print $1}')"
  msg "  gained $(expr ${TOTALSIZE} - ${BINSIZE})Kbytes"
  TOTALSIZE="${BINSIZE}"
fi

if ${DOCCOMPRESS}; then
  msg "Compressing doc files (${COMPRESSOR} -${COMPRESSION_LEVEL})"
  find "${INSTALLDIR}" -type f \( -path "*/man/*" -o -path "*/info/*" -o -iname "readme" \) \( ! -iname "*.gz" ! -iname "*.bz2" ! -iname "*.xz" \) | while read f; do
    case "$(file "${f}")" in
      *"compressed data"*) dbg "  already compressed ${f}";;
      *)                   nfo "  compressing ${f}"; ${COMPRESSOR} -${COMPRESSION_LEVEL} "${f}";;
    esac
  done
  BINSIZE="$(du -s "${INSTALLDIR}" | awk '{print $1}')"
  msg "  gained $(expr ${TOTALSIZE} - ${BINSIZE})Kbytes"
  TOTALSIZE="${BINSIZE}"
fi

if ${DEVPKG}; then
  msg "Splitting developpement files to '${INSTALLDIR}-dev'"
  eval find \"${INSTALLDIR}\" $(for p in ${DEVPATTERNS}; do printf " -name '${p}' -o"; done | sed 's/ -o$//') | \
    sed "s@${INSTALLDIR}/@@" | while read f; do filemove "${f}" "dev"; done | nfo_stream
  msg "  size : $(du -s "${INSTALLDIR}-dev" | awk '{print $1}')/${BINSIZE}Kbytes"
fi

if ${LIBPKG}; then
  msg "Splitting libraries files to '${INSTALLDIR}-lib'"
  eval find \"${INSTALLDIR}\" $(for p in ${LIBPATTERNS}; do printf " -name '${p}' -o"; done | sed 's/ -o$//') | \
    sed "s@${INSTALLDIR}/@@" | while read f; do filemove "${f}" "lib"; done | nfo_stream
  msg "  size : $(du -s "${INSTALLDIR}-lib" | awk '{print $1}')/${BINSIZE}Kbytes"
fi

if ${DOCPKG}; then
  msg "Splitting documentation files to '${INSTALLDIR}-doc'"
  eval find \"${INSTALLDIR}\" $(for p in ${DOCPATTERNS}; do printf " -name '${p}' -o"; done | sed 's/ -o$//') | \
    sed "s@${INSTALLDIR}/@@" | while read f; do filemove "${f}" "doc"; done | nfo_stream
  msg "  size : $(du -s "${INSTALLDIR}-doc" | awk '{print $1}')/${BINSIZE}Kbytes"
fi
