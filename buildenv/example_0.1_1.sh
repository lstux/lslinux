#!/bin/lsbuild.sh -nodeps

# Where to download sources, gzip/bzip2/zip/xz archives are supported
# {{pkgname}}, {{version}} and {{revision}} will be replaced with corresponding values
SRCLINK=https://{{pkgname}}.org/downloads/{{pkgname}}-{{version}}.tar.xz

# Homepage of the project
HOMEPAGE=https://mypackage.org

# A small description of the package
DESCRIPTION="My awsome package for LsLinux"

# List of packages needed to correctly run this one
#DEPENDS="somepackage anotherpackage"

# List of packages needed to compile
#BUILD_DEPENDS="somepackage-dev anotherpackage-dev"

# If a particular user/group is needed, you may specify them like this
#ADDGROUP="groupname:gid"
#ADDUSER="username:uid:primarygroup[:homedir=/home/username[:shell=/sbin/nologin]]"

# If you want to split to a pkgname-doc package containing documentation
#DOCPKG=true
# You may redefine the matching patterns
#DOCPKG_PATTERNS="*/man/* */info/* readme"

# If you want to split to pkgname-lib package containing libraries
#LIBPKG=true
# You may redefine the matching patterns
#LIBPKG_PATTERNS="*.so*"

# If you want to split to pkgname-dev package containing developpement files
#DEVPKG=true
# You may redefine the matching patterns
#DEVPKG_PATTERNS=""


# To configure sources, you may use 'doconf' builtin
# default behaviour is to run './configure ${CONFIGOPTS}' in extracted sources directory
#   you may specify other options with 'doconf --my-option=my/value'
# it also supports "kernel style" configuration with 'doconf keyword [set key=value [key2=value2 ...]] [unset key3 [key4]]
#   this will run "make keyword" in extracted sources directory and set/unset specified keys in .config file
# finally if none of these options fits your needs, just run your own commands, sources are available in ${}
doconf

# To build sources, you may use 'dobuild' builtin
# default behaviour is to run 'make ${MAKEOPTS}' in extracted sources directory
dobuild

# To install sources, you may use 'doinstall' builtin
# default behaviour is to run 'make DESTDIR=${} install' in extracted sources directrory
# you may specify another keyword like 'doinstall -d CONFIG_PREFIX' which will run 'make CONFIG_PREFIX=${} install'
# you may also use your own commands, just install files to ${}
doinstall


# Pre/Post(un)installation functions may be defined here, they will be run by lspkg at (un)installation of package
# When updating a package, 'update' argument will be passed to thes functions
#preinst() {
#  dosome_checks run before installation
#}
#postinst() {
#  dosome_otherchecks run once package is installed
#}
#prerm() {
#  dosome_checks run before package removal
#}
#postrm() {
#  dosome_otherchecks run once package is removed
#}
