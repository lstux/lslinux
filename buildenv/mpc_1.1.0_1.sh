#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/mpc/mpc-{{version}}.tar.gz
HOMEPAGE=http://www.multiprecision.org/mpc/
DESCRIPTION="library for the arithmetic of complex numbers with arbitrarily high precision and correct rounding"
BUILD-DEPENDS="mpfr-dev gmp-dev"
DEPENDS=""
DEVPKG=true
DOCPKG=true

doconf
dobuild
doinstall
