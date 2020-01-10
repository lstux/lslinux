#!/bin/lsbuild.sh -nodeps
SRCLINK=https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-{{version}}.tar.xz
SRCDIR="linux-{{version}}"
HOMEPAGE=https://www.kernel.org
DESCRIPTION="Linux kernel headers"
SECTION=devlibs


doconf mrproper
make -C "${SOURCESDIR}" INSTALL_HDR_PATH="${INSTALLDIR}/usr" headers_install
