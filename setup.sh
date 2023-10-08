#!/bin/bash

set -e

# Versions configuration
LUA_VER="5.2.4"
OCAML_VER="4.09.1"
ELKHOUND_VER="2019-02-17"
WEIDU_VER_MAJOR="249"
WEIDU_VER="${WEIDU_VER_MAJOR}.00"
TISPACK_VER="0.91"
TILECONV_VER="0.6"
TILE2EE_VER="0.3"
SND2ACM_VER="7.7j+0.0.1fix"


# Go to the script directory
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>"/dev/null"

# Downloader abstraction
#   Possible uses (detected based on the last char of the first argument):
#       download "https://example.com/" "file.zip"
#       download "https://example.com/somename.zip" "myname.zip"
download() {
    REMOTE="${1}"
    FILE="${2}"
    if [ "${REMOTE: -1}" = "/" ]; then
        REMOTE="${REMOTE}${FILE}"
    fi
    if [ ! -e "cache/${FILE}" ]; then
        curl -L "${REMOTE}" --output "cache/${FILE}"
    fi
}

# Check os capabilities
OS_TOOLS_MISSING="0"
for OS_TOOL in "tee" "gcc" "g++" "iconv" "ffmpeg" "dos2unix" "mmv" "sox" "oggdec"; do
    if [ -z "$(which "${OS_TOOL}")" ]; then
        echo "${OS_TOOL} is missing..."
        OS_TOOLS_MISSING="1"
    fi
done
if [ "${OS_TOOLS_MISSING}" = "1" ]; then
    exit 1
fi


# Prepare destination structure
mkdir -p "opt/"{"bin","lib","include"} "cache"
PREFIX="${PWD}/opt"
TOOLS_PATH="${PREFIX}/bin"

# Use built tools as they appear
export PATH="${TOOLS_PATH}${PATH:+:${PATH}}"
export LD_LIBRARY_PATH="${PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export CPATH="${PREFIX}/include${CPATH:+:${CPATH}}"

# Install Lua
# Lua 5.2 is probably used in EE games (in the case of 2.6 patch)
LUA="${TOOLS_PATH}/lua"
if [ ! -x "${LUA}" ]; then
    download "https://www.lua.org/ftp/" "lua-${LUA_VER}.tar.gz"
    rm -rf "lua"*
    tar zxf "cache/lua-"*".tar.gz"
    cp -a "lua"* "lua-build"
    cd "lua-build"
    make "linux" MYCFLAGS="${CFLAGS}"
    cd ".."
    cp "lua-build/src/"{"lua","luac"} "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/lua"
    echo "See readme.html." >"${PREFIX}/share/doc/lua/license.txt"
    echo "Lua: MIT License as in share/doc/lua/readme.txt" >> "${PREFIX}/LICENSES"
    rm -rf "lua"*
fi

# Install OCaml
# For WeiDU. Picked a version that compiles well without enforced safe
# strings (WeiDU needs it, at least at v249.00)
OCAML="${TOOLS_PATH}/ocaml"
if [ ! -x "${OCAML}" ]; then
    download "https://github.com/ocaml/ocaml/archive/refs/tags/${OCAML_VER}.tar.gz" "ocaml-${OCAML_VER}.tar.gz"
    rm -rf "ocaml"*
    tar zxf "cache/ocaml-"*".tar.gz"
    cp -a "ocaml"* "ocaml-build"
    cd "ocaml-build"
    sed "s/SIGSTKSZ/8192/g" -i "./runtime/signals_nat.c"
    sed "s/common_cflags=\"-O2 -fno-strict-aliasing -fwrapv\";/common_cflags=\"-O2 $\{CFLAGS\} -fno-strict-aliasing -fwrapv\";/g" -i "configure"
    "./configure" --with-pic --disable-force-safe-string --prefix="${PREFIX}"
    make "world.opt"
    make "install"
    cd ".."
    mkdir -p "${PREFIX}/share/doc/ocaml"
    cp -a "ocaml-build/LICENSE" "${PREFIX}/share/doc/ocaml/"
    echo "OCaml: LGPLv2.1 License as in share/doc/ocaml/LICENSE" >> "${PREFIX}/LICENSES"
    rm -rf "ocaml"*
fi

# Install Elkhound
# Very WeiDU-specific.
ELKHOUND="${TOOLS_PATH}/elkhound"
if [ ! -x "${ELKHOUND}" ]; then
    download "https://github.com/WeiDUorg/elkhound/archive/refs/tags/${ELKHOUND_VER}.tar.gz" "elkhound-${ELKHOUND_VER}.tar.gz"
    rm -rf "elkhound"*
    tar zxf "cache/elkhound-"*".tar.gz"
    ln -sf "elkhound"* "elkhound"
    mkdir "elkhound-build"
    cd "elkhound-build"
    cmake "../elkhound/src" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_BUILD_TYPE="Release" -DCMAKE_CXX_FLAGS_RELEASE="${CXXFLAGS}"
    make
    cd ".."
    cp "elkhound-build/elkhound/elkhound" "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/elkhound"
    echo "Elkhound: BSD-compilant License as in share/doc/elkhound/license.txt" >> "${PREFIX}/LICENSES"
    rm -rf "elkhound"*
fi

# WeiDU itself!
WEIDU="${TOOLS_PATH}/weidu"
if [ ! -x "${WEIDU}" ]; then
    download "https://github.com/WeiDUorg/weidu/archive/refs/tags/v${WEIDU_VER}.tar.gz" "weidu-${WEIDU_VER}.tar.gz"
    rm -rf "weidu"*
    tar zxf "cache/weidu-"*".tar.gz"
    cp -a "weidu"* "weidu-build"
    cd "weidu-build"
    cp "sample.Configuration" "Configuration"
    sed -i "s|OCAMLDIR  = /usr/bin|OCAMLDIR  = ${TOOLS_PATH}|g" "Configuration"
    make -j1 "weidu" "weinstall"
    cd ".."
    cp "weidu-build/weidu.asm.exe" "${TOOLS_PATH}/weidu"
    cp "weidu-build/weinstall.asm.exe" "${TOOLS_PATH}/weinstall"
    mkdir -p "${PREFIX}/share/doc/weidu"
    cp -a "weidu-build/COPYING" "${PREFIX}/share/doc/weidu/"
    echo "WeiDU: GPLv2 License as in share/doc/weidu/COPYING" >> "${PREFIX}/LICENSES"
    rm -rf "weidu"*
fi

# Tispack
TISPACK="${TOOLS_PATH}/tispack"
if [ ! -x "${TISPACK}" ]; then
    download "http://mods.pocketplane.net/" "tispack-${TISPACK_VER}.zip"
    rm -rf "tispack"*
    unzip "cache/tispack"*".zip"
    cp -a "tispack"* "tispack-build"
    cd "tispack-build/source"
    cp "makefile.unix" "Makefile"
    make OPT="${CFLAGS}"
    cd "../.."
    cp "tispack-build/source/"{"tispack","tisunpack","tizparse","jpgextract"} "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/tispack"
    cp "tispack-build/readme.txt" "${PREFIX}/share/doc/tispack/readme.txt"
    echo "TisPack: zlib License in share/doc/tispack/readme.txt" >> "${PREFIX}/LICENSES"
    rm -rf "tispack"*
fi

# Mospack
# I can't find sources. WeiDU includes binaries, let's just live with that.
# At least either Weimer (love that guy btw) or the author from French forums created a 64-bit Linux binary.
MOSPACK="${TOOLS_PATH}/mospack"
if [ ! -x "${MOSPACK}" ]; then
    download "https://github.com/WeiDUorg/weidu/releases/download/v${WEIDU_VER}/" "WeiDU-Linux-${WEIDU_VER_MAJOR}-amd64.zip"
    unzip "cache/WeiDU-Linux-"*".zip"
    mv "WeiDU-Linux/mos"* "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/mospack"
    cp "WeiDU-Linux/readme-mosunpack.txt" "${PREFIX}/share/doc/mospack/readme.txt"
    echo "MosPack: zlib License in share/doc/mospack/readme.txt" >> "${PREFIX}/LICENSES"
    rm -rf "WeiDU-Linux"
fi

# Tileconv
TILECONV="${TOOLS_PATH}/tileconv"
if [ ! -x "${TILECONV}" ]; then
    download "https://github.com/InfinityTools/tileconv/archive/refs/tags/v${TILECONV_VER}.tar.gz" "tileconv-${TILECONV_VER}.tar.gz"
    rm -rf "tileconv"*
    tar zxf "cache/tileconv-"*".tar.gz"
    cp -a "tileconv"* "tileconv-build"
    cd "tileconv-build/tileconv"
    sed "s|#include <lib/libimagequant.h>|#include <libimagequant.h>|g" -i "colorquant.h"
    sed "/^#include <algorithm>/a #include <limits>" -i "tilethreadpool_base.cpp"
    sed "/^#include <algorithm>/a #include <limits>" -i "tiledata.cpp"
    sed "s/BytePtr mosData(nullptr, std::default_delete<uint8_t\[\]>());/BytePtr mosData(static_cast<uint8_t *>(nullptr), std::default_delete<uint8_t\[\]>());/g" -i "tileconv.cpp"
    make CXXFLAGS="-std=c++11 ${CXXFLAGS} -msse -mfpmath=sse -c"
    cd "../.."
    cp "tileconv-build/tileconv/tileconv" "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/tileconv"
    cp "tileconv-build/LICENSE" "${PREFIX}/share/doc/tileconv/LICENSE"
    echo "TILECONV: MIT License in share/doc/tileconv/LICENSE" >> "${PREFIX}/LICENSES"
    rm -rf "tileconv"*
fi

TILE2EE="${TOOLS_PATH}/tile2ee"
if [ ! -x "${TILE2EE}" ]; then
    download "https://github.com/InfinityTools/tile2ee/archive/refs/tags/v${TILE2EE_VER}.tar.gz" "tile2ee-${TILE2EE_VER}.tar.gz"
    rm -rf "tile2ee"*
    tar zxf "cache/tile2ee-"*".tar.gz"
    cp -a "tile2ee"* "tile2ee-build"
    cd "tile2ee-build/tile2ee"
    sed "s|#include <lib/libimagequant.h>|#include <libimagequant.h>|g" -i "ColorQuant.hpp"
    sed "/^#include <algorithm>/a #include <limits>" -i "TileThreadPoolBase.cpp"
    sed "/^#include <algorithm>/a #include <limits>" -i "TileData.cpp"
    sed "/std::printf(\"MOS size too small\\\\n\");$/{n;s/      return false;/      return retVal;/;}" -i "Graphics.cpp"
    make CXXFLAGS="-std=c++11 ${CXXFLAGS} -msse -mfpmath=sse -c"
    cd "../.."
    cp "tile2ee-build/tile2ee/tile2ee" "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/tile2ee"
    cp "tile2ee-build/LICENSE" "${PREFIX}/share/doc/tile2ee/LICENSE"
    echo "TILE2EE: MIT License in share/doc/tile2ee/LICENSE" >> "${PREFIX}/LICENSES"
    rm -rf "tile2ee"*
fi


OGGDEC="${TOOLS_PATH}/oggdec"
if [ ! -x "${OGGDEC}" ]; then
    cat >"${TOOLS_PATH}/oggdec" <<EOF
#!/usr/bin/env bash

# oggdec(1) wrapper for legacy -w support.

# This script is a part of ie-tools-linux project
# (https://github.com/dtiefling/ie-tools-linux), which is distributed on
# GNU General Public License Version 2.

ARGS=("\${@}")

IDX="0"
while [ "\${IDX}" -lt "\${#ARGS[*]}" ]; do
    if [ "\${ARGS["\${IDX}"]}" = "-w" ]; then
        ARGS["\${IDX}"]="-o"
    fi
    IDX=\$(("\${IDX}" + 1))
done

exec "/usr/bin/oggdec" "\${ARGS[@]}"
EOF
fi


SND2ACM="${TOOLS_PATH}/snd2acm"
if [ ! -x "${SND2ACM}" ]; then
    download "https://github.com/dtiefling/snd2acm-portable/archive/refs/tags/v${SND2ACM_VER}.tar.gz" "snd2acm-portable-${SND2ACM_VER}.tar.gz"
    rm -rf "snd2acm-portable"*
    tar zxf "cache/snd2acm-portable-"*".tar.gz"
    cp -a "snd2acm-portable"* "snd2acm-portable-build"
    cd "snd2acm-portable-build"
    make
    cd ".."
    cp -a "snd2acm-portable-build/bin/"* "${TOOLS_PATH}/"
    mkdir -p "${PREFIX}/share/doc/snd2acm-portable"
    cp "snd2acm-portable-build/COPYING" "${PREFIX}/share/doc/snd2acm-portable/COPYING"
    echo "snd2acm-portable: GPLv2 in share/doc/snd2acm-portable/COPYING" >> "${PREFIX}/LICENSES"
    rm -rf "snd2acm-portable"*
fi

echo "${TOOLS_PATH}"
