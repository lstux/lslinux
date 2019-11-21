#!/bin/lsbuild.sh -nodeps
SRCLINK=https://busybox.net/downloads/busybox-{{version}}.tar.bz2
DEPENDS="uClibc-ng"
DOCPKG=true

doconf defconfig #set CONFIG_PREFIX=${LSL_DESTDIR}/${PKG_NAME}-${PKG_VERSION}-${PKG_REVISION}
dobuild
doinstall -d CONFIG_PREFIX
