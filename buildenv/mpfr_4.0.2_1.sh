#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/mpfr/mpfr-{{version}}.tar.xz
HOMEPAGE=https://www.mpfr.org
DESCRIPTION="library for multiple-precision floating-point computations with correct rounding"
BUILD-DEPENDS="gmp-dev"
DEPENDS="gmp"
DEVPKG=true
DOCPKG=true

doconf
dobuild
doinstall
