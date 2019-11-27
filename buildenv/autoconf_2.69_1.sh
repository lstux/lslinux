#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/autoconf/autoconf-{{version}}.tar.xz
HOMEPAGE=https://www.gnu.org/software/autoconf/
DESCRIPTION="automatically configure software source code packages"
DOCPKG=true
BUILD_DEPENDS="m4-dev"
DEPENDS="m4"

doconf --prefix=/usr
dobuild
doinstall
