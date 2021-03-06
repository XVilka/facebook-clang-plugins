#!/bin/bash

# Simple installation script for llvm/clang.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_RELATIVE_PATH="$(basename "${BASH_SOURCE[0]}")"
CLANG_RELATIVE_SRC="src/clang-3.8.tar.xz"
CLANG_SRC="$SCRIPT_DIR/$CLANG_RELATIVE_SRC"
CLANG_PATCH="$SCRIPT_DIR/src/AttrDump.inc.patch"
CLANG_PREFIX="$SCRIPT_DIR"
CLANG_INSTALLED_VERSION_FILE="$SCRIPT_DIR/installed.version"

SHA256SUM="shasum -a 256 -p"

usage () {
    echo "Usage: $0 [-chr]"
    echo
    echo " options:"
    echo "    -c,--only-check-install    check if recompiling clang is needed"
    echo "    -h,--help                  show this message"
    echo "    -r,--only-record-install   do not install clang but pretend we did"
}

check_installed () {
    pushd "$SCRIPT_DIR" > /dev/null
    $SHA256SUM -c "$CLANG_INSTALLED_VERSION_FILE" >& /dev/null
    local result=$?
    popd > /dev/null
    return $result
}

record_installed () {
    pushd "$SCRIPT_DIR" > /dev/null
    $SHA256SUM "$CLANG_RELATIVE_SRC" "$SCRIPT_RELATIVE_PATH" > "$CLANG_INSTALLED_VERSION_FILE"
    popd > /dev/null
}

ONLY_CHECK=
ONLY_RECORD=

while [[ $# > 0 ]]; do
    opt_key="$1"
    case $opt_key in
        -c|--only-check-install)
            ONLY_CHECK=yes
            shift
            continue
            ;;
        -r|--only-record-install)
            ONLY_RECORD=yes
            shift
            continue
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
    esac
    shift
done

platform=`uname`

case $platform in
    Darwin)
        CONFIGURE_ARGS=(
            --prefix="$CLANG_PREFIX"
            --enable-libcpp
            --enable-cxx11
            --disable-assertions
            --enable-optimized
            --enable-bindings=none
        );;
    *)
        CONFIGURE_ARGS=(
            --prefix="$CLANG_PREFIX"
            --enable-cxx11
            --disable-assertions
            --enable-optimized
            --enable-bindings=none
        )
esac

if [ "$ONLY_RECORD" = "yes" ]; then
    record_installed
    exit 0
fi

check_installed
already_installed=$?

if [ "$ONLY_CHECK" = "yes" ]; then
    # trick to always exit with 0 or 1
    [ $already_installed -eq 0 ]
    exit $?
fi

if [ $already_installed -eq 0 ]; then
    echo "Clang is already installed according to $CLANG_INSTALLED_VERSION_FILE"
    echo "Nothing to do, exiting."
    exit 0
fi

# start the installation
set -e
echo "Installing clang..."
TMP=`mktemp -d /tmp/clang-setup.XXXXXX`
pushd "$TMP"

if tar --version | grep -q 'GNU'; then
    # GNU tar is too verbose if the tarball was created on MacOS
    QUIET_TAR="--warning=no-unknown-keyword"
fi
tar --extract $QUIET_TAR --file "$CLANG_SRC"

llvm/configure "${CONFIGURE_ARGS[@]}"

JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
make -j $JOBS && make install
cp Release/bin/clang "$CLANG_PREFIX/bin/clang"
strip -x "$CLANG_PREFIX/bin/clang"
popd

rm -rf "$TMP"

record_installed
