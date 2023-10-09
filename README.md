# ie-tools-linux
A script to build (or at least collect) the most necessary Infinity Engine
games modding tools for Linux.

## Usage

`./setup.sh`

It checks for the presence of all the tools, and prints the path to the toolkit.
If some tools are missing, it attempts to build them.
With binary release or after successful install, you can use it like this:

`export PATH="$(./setup.sh | tail -n1):${PATH}"`

Or just add the `opt/bin` directory to your PATH in any preffered way.

## Requirements

The prebuilt release is linked against:
 - glibc-like C library (libc.so.6, libm.so.6)
 - GCC support libraries (libgcc_s.so.1, libgomp.so.1, libstdc++.so.6)
 - readline (libreadline.so.8)
 - zlib (libz.so.1)
 - ncurses (libtinfo.so.6)
 - libjpeg (libjpeg.so.8)
 - Ogg (libogg.so.0)
 - Vorbis (libvorbis.so.0, libvorbisfile.so.3)
 - libimagequant (libimagequant.so.0)
 - libsquish (libsquish.so.0)

And assumes that you have:
  - Binaries compatible with that of GNU C Library (tee)
  - Core utilities like GNU ones (iconv)
  - dos2unix converter
  - mmv wildcard-based utility
  - FFmpeg
  - Vorbis tools
  - sox audio manipulator

To make sure you are not missing any of that, do your system equivalent of:

`sudo apt install libc-bin coreutils dos2unix mmv ffmpeg vorbis-tools sox libc6 libgcc-s1 libgomp1 libreadline8 zlib1g libtinfo6 libjpeg-turbo8 libogg0 libvorbis0a libvorbisfile3 libimagequant0 libsquish0`

## Building

Some requirements can be deducted from the above, you sure need headers of
the libraries from the "linking" list. It would also help to have
a C/C++ compiler, it was tested with GCC.
