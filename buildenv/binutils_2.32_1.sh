#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/binutils/binutils-{{version}}.tar.xz
HOMEPAGE=https://www.gnu.org/software/binutils/
DESCRIPTION="a collection of binary tools"
SECTION=devtools
DEVPKG=true
DOCPKG=true

doconf --prefix=/usr --disable-nls
dobuild
doinstall
