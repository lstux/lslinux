#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/gcc/gcc-{{version}}/gcc-{{version}}.tar.xz
HOMEPAGE=http://www.multiprecision.org/mpc/
DESCRIPTION="GNU compiler collections (c/c++ only)"
SECTION=devtools
BUILD-DEPENDS="mpfr-dev gmp-dev mpc-dev"
DEPENDS="mpfr gmp mpc"
DOCPKG=true
#libgcc libstdc++?

doconf --prefix=/usr --disable-multilib --disable-nls --disable-libsanitizer --enable-languages=c,c++ --enable-shared
dobuild
doinstall
