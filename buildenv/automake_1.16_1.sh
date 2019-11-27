#!/bin/lsbuild.sh -nodeps
SRCLINK=https://ftp.gnu.org/gnu/automake/automake-{{version}}.tar.xz
HOMEPAGE=https://www.gnu.org/software/automake/
DESCRIPTION="automatically generates Makefile.in"
DOCPKG=true
BUILD_DEPENDS="autoconf"
DEPENDS="autoconf"

doconf --prefix=/usr
dobuild
doinstall
