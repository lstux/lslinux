#!/bin/sh
BINDIR="${1}"
VERBOSE="${VERBOSE:-0}"

if ! [ -d "${BINDIR}" ]; then
  exec >&2
  printf "Usage : $(basename "${0}") bindir\n"
  printf "  Find executable files in bindir, and strip them if not already\n"
  exit 1
fi

find "${BINDIR}" -type f -executable | while read f; do
  case "$(file "${f}")" in
    *"not stripped"*) printf "Stripping ${f}\n"; strip --strip-unneeded "${f}";;
    *"stripped"*)     [ ${VERBOSE} -ge 1 ] && printf "Already stripped ${f}\n";;
    *)                [ ${VERBOSE} -ge 2 ] && printf "Not strippable ${f}\n";;
  esac
done
