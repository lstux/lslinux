#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/libtool/libtool-{{version}}.tar.xz
HOMEPAGE=https://www.gnu.org/software/libtool/
DESCRIPTION="generic library support script"
DEVPKG=true
DOCPKG=true
BUILD_DEPENDS=""
DEPENDS=""

doconf --prefix=/usr --disable-nls
dobuild
doinstall
