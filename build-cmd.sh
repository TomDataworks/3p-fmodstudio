#!/bin/bash

FMOD_ROOT_NAME="fmodstudioapi"
FMOD_VERSION="10706"
FMOD_VERSION_PRETTY="1.07.06"

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
case "$AUTOBUILD_PLATFORM" in
    windows*)
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    ;;
    "darwin")
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    ;;
    linux*)
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    ;;
esac
FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
FMOD_ARCHIVE="$FMOD_SOURCE_DIR$FMOD_FILEEXTENSION"

case "$FMOD_ARCHIVE" in
    *.exe)
        # We can't run the NSIS installer as admin in TC
        # so we do this part manually and put the whole lot
        # into the repo instead.
        #
        bash_install_dir="$(pwd)/$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
        win_install_dir=`cygpath -w "$bash_install_dir"`
        #
        # This will invoke the UAC dialog to confirm permission before
        # proceeding.  You can run the build on a 'modified' system with
        # permissions granted to the build account or you might be able
        # to get to the dialog using remote desktop.  Either way, manual
        # preparation for this is required.
        #
        chmod +x "$FMOD_ARCHIVE"
        cmd.exe /c "$FMOD_ARCHIVE /S /D=$win_install_dir"
        if [ ! -d "$win_install_dir" ]; then
            echo "Please run $FMODEX_ARCHIVE as administrator and install to  $win_install_dir"
            fail
        fi
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

echo "${FMOD_VERSION_PRETTY}" > "${stage}/VERSION.txt"

pushd "$FMOD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmodL_vc.lib" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmod_vc.lib" "$stage_release"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmodL.dll" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmod.dll" "$stage_release"
        ;;
        "windows64")
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmodL64_vc.lib" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmod64_vc.lib" "$stage_release"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmodL64.dll" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/lowlevel/lib/fmod64.dll" "$stage_release"
        ;;
        "darwin")
            cp "api/lowlevel/lib/libfmodL.dylib" "$stage_debug"
            cp "api/lowlevel/lib/libfmod.dylib" "$stage_release"
            pushd "$stage_debug"
              fix_dylib_id libfmodL.dylib
            popd
            pushd "$stage_release"
              fix_dylib_id libfmod.dylib
            popd
        ;;
        "linux")
            # Copy the relevant stuff around
            cp -a api/lowlevel/lib/x86/libfmodL.so* "$stage_debug"
            cp -a api/lowlevel/lib/x86/libfmod.so* "$stage_release"
         ;;
        "linux64")
            # Copy the relevant stuff around
            cp -a api/lowlevel/lib/x86_64/libfmodL.so* "$stage_debug"
            cp -a api/lowlevel/lib/x86_64/libfmod.so* "$stage_release"
        ;;
    esac

    # Copy the headers
    cp -dR --preserve=mode,timestamps api/lowlevel/inc/*.h "$stage/include/fmodstudio"
    cp -dR --preserve=mode,timestamps api/lowlevel/inc/*.hpp "$stage/include/fmodstudio"

    # Copy License (extracted from the readme)
    cp "doc/LICENSE.TXT" "$stage/LICENSES/fmodstudio.txt"
popd
pass

