#!/bin/lsbuild.sh
SRCLINK=https://downloads.uclibc-ng.org/releases/{{version}}/{{pkgname}}-{{version}}.tar.xz
STRIPMODE=none

doconf defconfig
dobuild
doinstall
