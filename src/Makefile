all:	ctest build test-pam_python.pam

WARNINGS=-Wall -Wextra -Wundef -Wshadow -Wpointer-arith -Wbad-function-cast -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Werror
#WARNINGS=-Wunreachable-code 	# Gcc 4.1 .. 4.4 are too buggy to make this useful

LIBDIR ?= /lib/security

build: pam_python.c setup.py Makefile
	@[ ! -e build -o build/lib.*/pam_python.*.so -nt setup.py -a build/lib.*/pam_python.so -nt Makefile ] || rm -r build
	CFLAGS="$(WARNINGS) -I/usr/local/lib/ " ./setup.py build
	@#CFLAGS="-O0 $(WARNINGS)" ./setup.py build --debug
	@#CFLAGS="-O0 $(WARNINGS)" Py_DEBUG=1 ./setup.py build --debug
	ln -sf build/lib.*/pam_python*.so $$(pwd)/pam_python.so

.PHONY: install install-lib
install: install-lib
install-lib:
	s=$$([ $$(id -u) = 0 ] || echo sudo); $$s mkdir -p $(DESTDIR)$(LIBDIR)
	s=$$([ $$(id -u) = 0 ] || echo sudo); $$s cp build/lib.*/pam_python*.so $(DESTDIR)$(LIBDIR)

.PHONY: clean
clean:
	rm -rf build ctest test-pam_python.pam test.pyc core
	[ ! -e /etc/pam.d/test-pam_python.pam ] || { s=$$([ $$(id -u) = 0 ] || echo sudo); $$s rm -f /etc/pam.d/test-pam_python.pam; }
	[ ! -e /etc/pam.d/test-pam_python-installed.pam ] || { s=$$([ $$(id -u) = 0 ] || echo sudo); $$s rm -f /etc/pam.d/test-pam_python-installed.pam; }

.PHONY: ctest
ctest:	ctest.c Makefile
	gcc -O0 $(WARNINGS) -g -o $@ ctest.c -lpam $$(python3-config --libs --embed 2>/dev/null || python3-config --libs)

test-pam_python.pam: test-pam_python.pam.in Makefile
	sed "s,\\\$$PWD,$$(pwd),g" "$@.in" >"$@.tmp"
	mv $@.tmp $@

/etc/pam.d/test-pam_python.pam: test-pam_python.pam
	s=$$([ $$(id -u) = 0 ] || echo sudo); $$s ln -sf $$(pwd)/test-pam_python.pam /etc/pam.d

.PHONY: test
test: pam_python.so ctest /etc/pam.d/test-pam_python.pam
	python3 test.py
	./ctest

test-pam_python-installed.pam: test-pam_python.pam.in Makefile
	sed "s,\\\$$PWD/pam-python.so,pam-python.so,;s,\\\$$PWD,$$(pwd),g" "$@.in" >"$@.tmp"
	mv $@.tmp $@

/etc/pam.d/test-pam_python-installed.pam: test-pam_python-installed.pam
	s=$$([ $$(id -u) = 0 ] || echo sudo); $$s ln -sf $$(pwd)/test-pam_python-installed.pam /etc/pam.d

.PHONY: installed-test
installed-test: ctest /etc/pam.d/test-pam_python-installed.pam
	python3 test.py
	./ctest

# SAST (Static Application Security Testing) targets
.PHONY: sast sast-c sast-python sast-cppcheck sast-clang sast-bandit sast-flake8

# Run all SAST checks
sast: sast-c sast-python

# C static analysis
sast-c: sast-cppcheck sast-clang

# Python static analysis
sast-python: sast-bandit sast-flake8

# cppcheck - lightweight C/C++ static analyzer
sast-cppcheck:
	@echo "=== Running cppcheck on C source ==="
	@command -v cppcheck >/dev/null 2>&1 || { echo "cppcheck not installed. Install with: apt install cppcheck"; exit 1; }
	cppcheck --enable=all --force --error-exitcode=1 \
		--suppress=missingIncludeSystem --suppress=unusedFunction \
		--suppress=unmatchedSuppression --suppress=information \
		--inline-suppr \
		pam_python.c ctest.c

# clang static analyzer (scan-build)
sast-clang:
	@echo "=== Running clang static analyzer ==="
	@command -v scan-build >/dev/null 2>&1 || { echo "scan-build not installed. Install with: apt install clang-tools"; exit 1; }
	scan-build --status-bugs gcc -c $(WARNINGS) -I/usr/include/python3.* pam_python.c -o /dev/null

# bandit - Python security linter
sast-bandit:
	@echo "=== Running bandit on Python source ==="
	@command -v bandit >/dev/null 2>&1 || { echo "bandit not installed. Install with: pip install bandit"; exit 1; }
	bandit -r test.py setup.py ../examples/ -ll

# flake8 - Python style and logic checker
sast-flake8:
	@echo "=== Running flake8 on Python source ==="
	@command -v flake8 >/dev/null 2>&1 || { echo "flake8 not installed. Install with: pip install flake8"; exit 1; }
	flake8 --max-line-length=120 --ignore=E501,W503 test.py setup.py ../examples/
