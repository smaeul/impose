#
# Copyright © 2019 Samuel Holland <samuel@sholland.org>
# SPDX-License-Identifier: 0BSD
#

prefix=/usr/local
bindir=${prefix}/bin
libexecdir=${prefix}/libexec

IMPOSE=${bindir}/impose
LIB=${libexecdir}/impose/lib.sh

all:
	@echo 'Nothing to build! `make install` or run impose.sh directly.'

install: ${DESTDIR}${IMPOSE} ${DESTDIR}${LIB}

uninstall:
	rm -f ${DESTDIR}${IMPOSE}
	rmdir -p $(dir ${DESTDIR}${IMPOSE}) || true
	rm -f ${DESTDIR}${LIB}
	rmdir -p $(dir ${DESTDIR}${LIB}) || true

${DESTDIR}${IMPOSE}: impose.sh
	mkdir -p $(dir $@)
	sed -e '/^LIB=/s|=.*|=${LIB}|' $< > $@.tmp || { rm -f $@.tmp; false; }
	chmod 0755 $@.tmp
	mv $@.tmp $@

${DESTDIR}${LIB}: lib.sh
	mkdir -p $(dir $@)
	cp $< $@

.PHONY: all install uninstall
