#!/bin/sh
SEARCHDIR="."

usage() {
  exec >&2
  printf "Usage : $(basename "${0}") [options] symbol\n"
  printf "  find in which library specified symbol is defined\n"
  printf "options :\n"
  printf "  -d dir : search in specified dir instead of current dir\n"
  printf "  -h     : show this help message\n"
  exit 1
}

while getopts d:h opt; do case "${opt}" in
  d) SEARCHDIR="${OPTARG}";;
  *) usage;;
esac; done
shift $(expr ${OPTIND} - 1)
SYMBOL="${1}"
[ -n "${SYMBOL}" ] || usage

for lib in $(find "${SEARCHDIR}" -name "*.a"); do
  echo ${lib};
  nm ${lib} | grep my_symbol | grep -v " U "
done
