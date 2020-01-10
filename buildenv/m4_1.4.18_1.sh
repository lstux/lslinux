#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/m4/m4-{{version}}.tar.xz
HOMEPAGE=https://www.gnu.org/software/m4/
DESCRIPTION="GNU macro processor"
SECTION=devtools
DOCPKG=true
BUILD_DEPENDS=""
DEPENDS=""

doconf --prefix=/usr
dobuild
doinstall
