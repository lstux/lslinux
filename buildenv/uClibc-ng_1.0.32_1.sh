#!/bin/lsbuild.sh -nodeps
SRCLINK=https://downloads.uclibc-ng.org/releases/{{version}}/{{pkgname}}-{{version}}.tar.xz
HOMEPAGE=https://uclibc-ng.org
DESCRIPTION="small C library for developing embedded Linux systems"
STRIPMODE=debug
DEVPKG=true

doconf defconfig set KERNEL_HEADERS="/usr/include"
dobuild
doinstall
