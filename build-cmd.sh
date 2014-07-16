#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

# Check autobuild is around or fail
if [ -z "$AUTOBUILD" ] ; then
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# Load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

# Form the official fmod archive URL to fetch
# Note: fmod is provided in 3 flavors (one per platform) of precompiled binaries. We do not have access to source code.
FMOD_ROOT_NAME="fmodstudioapi"
FMOD_VERSION="10404"
case "$AUTOBUILD_PLATFORM" in
    windows*)
    FMOD_SERV_DIR="Win"
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    FMOD_MD5="397ecba15ccf98dc6b39c7d8a234d6f8"
    ;;
    "darwin")
    FMOD_SERV_DIR="Mac"
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    FMOD_MD5="06c5337685fcbefbe3eae44b831c6fa6"
    ;;
    linux*)
    FMOD_SERV_DIR="Linux"
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="485d3b4780973a8e9688153ef05a7764"
    ;;
esac
FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
FMOD_ARCHIVE="$FMOD_SOURCE_DIR$FMOD_FILEEXTENSION"
FMOD_URL="http://www.fmod.org/download/fmodstudio/api/$FMOD_SERV_DIR/$FMOD_ARCHIVE"

# Fetch and extract the official fmod files
fetch_archive "$FMOD_URL" "$FMOD_ARCHIVE" "$FMOD_MD5"
# Workaround as extract does not handle .zip files (yet)
# TODO: move that logic to the appropriate autobuild script
case "$FMOD_ARCHIVE" in
    *.exe)
        7z x "$FMOD_ARCHIVE" -o"$FMOD_SOURCE_DIR"
    ;;
    *.tar.gz)
        extract "$FMOD_ARCHIVE"
    ;;
    *.dmg)
        hdid "$FMOD_ARCHIVE"
        mkdir -p "$(pwd)/$FMOD_SOURCE_DIR"
        cp -r /Volumes/FMOD\ Programmers\ API\ Mac/FMOD\ Programmers\ API/* "$FMOD_SOURCE_DIR"
        umount /Volumes/FMOD\ Programmers\ API\ Mac/
    ;;
esac

stage="$(pwd)/stage"
stage_release="$stage/lib/release"
stage_debug="$stage/lib/debug"

# Create the staging license folder
mkdir -p "$stage/LICENSES"

# Create the staging include folders
mkdir -p "$stage/include/fmodstudio"

#Create the staging debug and release folders
mkdir -p "$stage_debug"
mkdir -p "$stage_release"

pushd "$FMOD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            cp "api/lowlevel/lib/fmodL_vc.lib" "$stage_debug"
            cp "api/lowlevel/lib/fmod_vc.lib" "$stage_release"
            cp "api/lowlevel/lib/fmodL.dll" "$stage_debug"
            cp "api/lowlevel/lib/fmod.dll" "$stage_release"
        ;;
        "windows64")
            cp "api/lowlevel/lib/fmodL64_vc.lib" "$stage_debug"
            cp "api/lowlevel/lib/fmod64_vc.lib" "$stage_release"
            cp "api/lowlevel/lib/fmodL64.dll" "$stage_debug"
            cp "api/lowlevel/lib/fmod64.dll" "$stage_release"
        ;;
        "darwin")
            cp "api/lowlevel/lib/libfmodL.dylib" "$stage_debug"
            cp "api/lowlevel/lib/libfmod.dylib" "$stage_release"
            pushd "$stage_debug"
              fix_dylib_id libfmodexL.dylib
            popd
            pushd "$stage_release"
              fix_dylib_id libfmodex.dylib
            popd
        ;;
        "linux")
            # Copy the relevant stuff around
            cp -a api/lib/libfmodexL-*.so "$stage_debug"
            cp -a api/lib/libfmodex-*.so "$stage_release"
            cp -a api/lib/libfmodexL.so "$stage_debug"
            cp -a api/lib/libfmodex.so "$stage_release"
        ;;
        "linux64")
            # Copy the relevant stuff around
            cp -a api/lib/libfmodexL64-*.so "$stage_debug"
            cp -a api/lib/libfmodex64-*.so "$stage_release"
            cp -a api/lib/libfmodexL64.so "$stage_debug"
            cp -a api/lib/libfmodex64.so "$stage_release"
        ;;
    esac

    # Copy the headers
    cp -a api/lowlevel/inc/*.h "$stage/include/fmodstudio"
    cp -a api/lowlevel/inc/*.hpp "$stage/include/fmodstudio"

    # Copy License (extracted from the readme)
    cp "doc/LICENSE.TXT" "$stage/LICENSES/fmodstudio.txt"
popd
pass

