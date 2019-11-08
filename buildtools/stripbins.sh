#!/bin/sh
VERBOSE="${VERBOSE:-0}"
STRIP_MODE="unneeded"

usage() {
  exec >&2
  printf "Usage : $(basename "${0}") [options] bindir\n"
  printf "  Find executable files in bindir, and strip them if not already\n"
  printf "  It will strip all unneeded symbols unless -d or -a option is given\n"
  printf "options :\n"
  printf "  -a : strip all symbols\n"
  printf "  -d : strip debug symbols only\n"
  printf "  -v : increase verbosity level\n"
  printf "  -h : display this help message\n"
  exit 1
}

while getopts advh opt; do case "${opt}" in
  a) STRIP_MODE="all";;
  d) STRIP_MODE="debug";;
  v) VERBOSE="$(expr ${VERBOSE} + 1)";;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
BINDIR="${1}"
[ -d "${BINDIR}" ] || usage

[ ${VERBOSE} -ge 1 ] && BINSIZE="$(du -s "${BINDIR}" | awk '{print $1}')"
find "${BINDIR}" -type f -executable | while read f; do
  case "$(file "${f}")" in
    *"not stripped"*) printf "Stripping ${f}\n"; strip --strip-${STRIP_MODE} "${f}";;
    *"stripped"*)     [ ${VERBOSE} -ge 1 ] && printf "Already stripped ${f}\n";;
    *)                [ ${VERBOSE} -ge 2 ] && printf "Not strippable ${f}\n";;
  esac
done
if [ ${VERBOSE} -ge 1 ]; then
  FINALBINSIZE="$(du -s "${BINDIR}" | awk '{print $1}')"
  GAINEDSIZE="$(expr ${BINSIZE} - ${FINALBINSIZE})"
  printf "Gained ${GAINEDSIZE}Kbytes with stripping\n"
fi