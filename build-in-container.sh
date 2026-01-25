#!/bin/bash
#
# Build pam-python in a Rocky Linux 9 container
#
set -e

. vars

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="pam-python-build-rocky9"
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
echo "Building pam-python in Rocky Linux 9 container..."

# Clean up any existing container with the same name
$RUNTIME rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run the build in a Rocky 9 container
$RUNTIME run --rm --name "$CONTAINER_NAME" \
    -v "$SCRIPT_DIR:/src:Z" \
    -w /src \
    "$IMAGE" \
    bash -c '
set -e

echo "=== Installing build dependencies ==="
dnf install -y \
    gcc \
    make \
    python'${PYTHON_VER}'-devel \
    pam-devel \
    python'${PYTHON_VER}'-setuptools \
    python'${PYTHON_VER}'-pip

echo ""
echo "=== Setting up python3 to use python'${PYTHON_VER}' ==="
alternatives --install /usr/bin/python3 python3 /usr/bin/python'${PYTHON_VER}' 1
alternatives --set python3 /usr/bin/python'${PYTHON_VER}'

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
echo "Output files:"
ls -la build/lib.*/pam_python*.so 2>/dev/null || echo "No .so files found in build/"
ls -la pam_python.so 2>/dev/null || echo "No pam_python.so symlink found"

echo ""
echo "=== Extracting version from setup.py ==="
VERSION=$(sed -n "s/.*version\s*=\s*\"\([^\"]*\)\".*/\1/p" setup.py)
PYTHON_VERSION=$(python3 -c "import sys; print(str(sys.version_info.major)+chr(46)+str(sys.version_info.minor))")
echo "Package version: $VERSION"
echo "Python version: $PYTHON_VERSION"

echo ""
echo "=== Copying built library to dist/ ==="
mkdir -p /src/dist
for so_file in build/lib.*/pam_python*.so; do
    base_name=$(basename "$so_file" .so)
    dest_name="pam_python-${VERSION}-py${PYTHON_VERSION}.so"
    cp "$so_file" "/src/dist/$dest_name"
    echo "Copied to: /src/dist/$dest_name"
done
ls -la /src/dist/
'

echo ""
echo "Build complete! The built library is in: $SCRIPT_DIR/dist/"
ls -la "$SCRIPT_DIR/dist/" 2>/dev/null || echo "dist/ directory not found"
