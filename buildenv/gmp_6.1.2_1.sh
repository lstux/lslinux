#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/gmp/gmp-{{version}}.tar.xz
HOMEPAGE=https://gmplib.org
DESCRIPTION="library for arbitrary precision arithmetic"
DEVPKG=true
DOCPKG=true

doconf
dobuild
doinstall
