.PHONY:	all
all:	doc lib

.PHONY:	lib
lib:
	$(MAKE) --directory src

.PHONY:	doc
doc:
	$(MAKE) --directory doc

.PHONY:	test
test:
	$(MAKE) --directory src $@

.PHONY:	sast sast-c sast-python sast-cppcheck sast-clang sast-bandit sast-flake8
sast sast-c sast-python sast-cppcheck sast-clang sast-bandit sast-flake8:
	$(MAKE) --directory src $@

.PHONY:	update-readme-badge
update-readme-badge:
	@. ./vars && sed -i "s|Python-[0-9.]*-blue|Python-$$PYTHON_VER-blue|g" README.md
	@. ./vars && echo "Updated README.md badge to Python $$PYTHON_VER"

.PHONY:	clean-pam_python
clean-pam_python:
	rm -rf pam_python

.PHONY:	clean
clean: clean-pam_python
	$(MAKE) --directory doc $@
	$(MAKE) --directory src $@

.PHONY:	install
install: install-doc install-lib

.PHONY:	install-doc
install-doc: clean-pam_python
	$(MAKE) --directory doc $@

.PHONY:	install-lib
install-lib: clean-pam_python
	$(MAKE) --directory src $@

RELEASE_SOURCES = \
	ChangeLog.txt \
	Makefile \
	Makefile.release \
	pam-python.html \
	README.md \
	doc/pam_python.rst \
	src/ctest.c \
	src/Makefile \
	src/pam_python.c \
	src/setup.py \
	src/test-pam_python.pam.in \
	src/test.py

include Makefile.release

release-project-clean:: clean
