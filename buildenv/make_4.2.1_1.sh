#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/make/make-{{version}}.tar.bz2
HOMEPAGE=https://www.gnu.org/software/make/
DESCRIPTION="controls the generation of executables and other non-source files"
DOCPKG=true

doconf --prefix=/usr --disable-nls
dobuild
doinstall
