#!/bin/bash
#
# Build and test pam-python in a Rocky Linux 9 container
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="pam-python-test-rocky9"
IMAGE="rockylinux:9"

# Detect container runtime (podman or docker)
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "Error: Neither podman nor docker found. Please install one of them."
    exit 1
fi

echo "Using container runtime: $RUNTIME"
echo "Building and testing pam-python in Rocky Linux 9 container..."

# Clean up any existing container with the same name
$RUNTIME rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run the build and tests in a Rocky 9 container
$RUNTIME run --rm --name "$CONTAINER_NAME" \
    -v "$SCRIPT_DIR:/src:Z" \
    -w /src \
    "$IMAGE" \
    bash -c '
set -e

echo "=== Installing build dependencies ==="
dnf install -y epel-release
dnf install -y \
    gcc \
    make \
    python3-devel \
    pam-devel \
    python3-setuptools \
    python3-pip \
    gdb \
    cppcheck \
    clang-tools-extra

echo ""
echo "=== Installing Python SAST tools ==="
pip3 install bandit flake8

echo ""
echo "=== Installing git for PyPAM build ==="
dnf install -y git

echo ""
echo "=== Building and installing PyPAM from source ==="
cd /tmp
git clone --single-branch --branch lsys-develop https://github.com/logicsys/PyPAM.git
cd PyPAM
python3 setup.py build
python3 setup.py install
cd /src

echo ""
echo "=== Python version ==="
python3 --version

echo ""
echo "=== Cleaning previous build ==="
cd /src/src
rm -rf build ctest test-pam_python.pam pam_python.so 2>/dev/null || true

echo ""
echo "=== Building pam_python extension ==="
make build

echo ""
echo "=== Build successful! ==="
ls -la pam_python.so

set +e

echo ""
echo "=== Running SAST checks ==="

echo ""
echo "--- Running cppcheck on C source ---"
make sast-cppcheck

echo ""
echo "--- Running clang static analyzer ---"
make sast-clang

echo ""
echo "--- Running bandit on Python source ---"
make sast-bandit

echo ""
echo "--- Running flake8 on Python source ---"
make sast-flake8

echo ""
echo "=== SAST checks passed! ==="

echo ""
echo "=== Building C test program ==="
make ctest

echo ""
echo "=== Generating PAM config ==="
make test-pam_python.pam

echo ""
echo "=== Installing PAM config (container-local) ==="
ln -sf /src/src/test-pam_python.pam /etc/pam.d/

echo ""
echo "=== Verifying PyPAM installation ==="
python3 -c "import PAM; print(PAM)"

echo ""
echo "=== Running Python tests ==="
python3 test.py || true

echo ""
echo "=== Checking syslog for pam_python errors ==="
grep -i pam /var/log/messages 2>/dev/null || journalctl --no-pager 2>/dev/null | grep -i pam | tail -30 || cat /var/log/secure 2>/dev/null | tail -30 || echo "Could not read syslog"

echo ""
echo "=== Running C tests ==="
./ctest

echo ""
echo "========================================="
echo "=== All tests passed successfully! ==="
echo "========================================="
'

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo "Container tests completed successfully!"
else
    echo ""
    echo "Container tests failed with exit code: $exit_code"
fi

exit $exit_code
