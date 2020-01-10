build:
	@echo "Nothing to build, run 'make [DESTDIR=/] install' to install"

install: directories files devices

directories:
	[ -d "$(DESTDIR)/" ] || install -v -d -m755 -oroot -groot "$(DESTDIR)/"
	for d in boot dev etc etc/profile.d home proc run sys var var/log; do [ -d "$(DESTDIR)/$$d" ] || install -v -d -m755 -oroot -groot "$(DESTDIR)/$$d"; done
	[ -d "$(DESTDIR)/tmp" ] || install -v -d -m777 -oroot -groot "$(DESTDIR)/tmp"
	[ -d "$(DESTDIR)/root" ] || install -v -d -m750 -oroot -groot "$(DESTDIR)/root"
	for l in tmp run; do [ -L "${DESTDIR}/var/$$l" ] || ln -v -s ../$$l "${DESTDIR}/var/$$l"; done

files: profile hostname
	[ -e "$(DESTDIR)/etc/profile" ] || install -v -m644 -oroot -groot profile "$(DESTDIR)/etc/profile"
	[ -e "$(DESTDIR)/etc/hostname" ] || install -v -m644 -oroot -groot hostname "$(DESTDIR)/etc/hostname"
	[ -e "$(DESTDIR)/etc/passwd" ] || install -v -m644 -oroot -groot passwd "$(DESTDIR)/etc/passwd"
	[ -e "$(DESTDIR)/etc/shadow" ] || install -v -m640 -oroot -groot shadow "$(DESTDIR)/etc/shadow"

devices:
	[ -e "$(DESTDIR)/dev/null" ]    || mknod -m666 "$(DESTDIR)/dev/null"    c 1 3
	[ -e "$(DESTDIR)/dev/zero" ]    || mknod -m666 "$(DESTDIR)/dev/zero"    c 1 5
	[ -e "$(DESTDIR)/dev/random" ]  || mknod -m444 "$(DESTDIR)/dev/random"  c 1 8
	[ -e "$(DESTDIR)/dev/urandom" ] || mknod -m444 "$(DESTDIR)/dev/urandom" c 1 9
	[ -e "$(DESTDIR)/dev/tty" ]     || mknod -m666 "$(DESTDIR)/dev/tty"     c 5 0
	[ -e "$(DESTDIR)/dev/console" ] || mknod -m622 "$(DESTDIR)/dev/console" c 5 1
	[ -e "$(DESTDIR)/dev/ptmx" ]    || mknod -m666 "$(DESTDIR)/dev/ptmx"    c 5 2
