#!/bin/lsbuild.sh -nodeps
SRCLINK=https://downloads.uclibc-ng.org/releases/{{version}}/{{pkgname}}-{{version}}.tar.xz
STRIPMODE=debug

doconf defconfig
dobuild
doinstall
