#!/bin/lsbuild.sh -nodeps
SRCLINK=https://busybox.net/downloads/busybox-{{version}}.tar.bz2
HOMEPAGE=https://busybox.net
DESCRIPTION="Swiss army knife of embedded Linux"
SECTION=syscore
DEPENDS="uClibc-ng"

doconf defconfig
dobuild
doinstall -d CONFIG_PREFIX
