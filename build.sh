#!/bin/bash
PREVDIR=$(pwd)
SDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
mkcd(){ mkdir -p "$@"; cd "$@"; }
add_inc(){ export CFLAGS="$CFLAGS -I$@"; }
add_link(){ export LDFLAGS="$LDFLAGS -R$@ -L$@"; }

export NDK=$ANDROID_NDK
export TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
export ANDROID_USR=$TOOLCHAIN/sysroot/usr
export API=21 # Set this to your minSdkVersion.
TALLOC_V=2.3.4

configure_android(){
	export CFLAGS="-I$ANDROID_USR/include -I$ANDROID_USR/include/$TARGET" # -fPIE
	export LDFLAGS="-R$ANDROID_USR/lib/$TARGET/$API -L$ANDROID_USR/lib/$TARGET/$API"
	export AR=$TOOLCHAIN/bin/llvm-ar
	export CC="$TOOLCHAIN/bin/$TARGET$API-clang"
	export AS=$CC
	export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
	export LD=$TOOLCHAIN/bin/ld
	export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
	export OBJDUMP=$TOOLCHAIN/bin/llvm-objdump
	export OBJCOPY=$TOOLCHAIN/bin/llvm-objcopy
	export STRIP=$TOOLCHAIN/bin/llvm-strip
	export ARCH=$(echo $TARGET | grep -Po "^\\K\w+(?=-)")
	mkdir -p "$SDIR/build/$ARCH2"
}

build_proot(){
	cd $SDIR
	add_link "$SDIR/build/$ARCH2"
	add_inc "$SDIR/talloc-$TALLOC_V"
	make -C src loader.elf loader-m32.elf build.h
	make -C src proot
}

download_talloc(){
	cd $SDIR
	if [ ! -d "talloc-$TALLOC_V" ]; then
		wget -O - "https://download.samba.org/pub/talloc/talloc-$TALLOC_V.tar.gz" | tar -xzv
	fi
}

build_talloc(){
	cd "$SDIR/talloc-$TALLOC_V"

cat <<EOF >cross-answers.txt
Checking uname sysname type: "Linux"
Checking uname machine type: "dontcare"
Checking uname release type: "dontcare"
Checking uname version type: "dontcare"
Checking simple C program: OK
rpath library support: OK
-Wl,--version-script support: FAIL
Checking getconf LFS_CFLAGS: OK
Checking for large file support without additional flags: OK
Checking for -D_FILE_OFFSET_BITS=64: OK
Checking for -D_LARGE_FILES: OK
Checking correct behavior of strtoll: OK
Checking for working strptime: OK
Checking for C99 vsnprintf: OK
Checking for HAVE_SHARED_MMAP: OK
Checking for HAVE_MREMAP: OK
Checking for HAVE_INCOHERENT_MMAP: OK
Checking for HAVE_SECURE_MKSTEMP: OK
Checking getconf large file support flags work: OK
Checking for HAVE_IFACE_IFCONF: FAIL
EOF

	./configure build -C --prefix="$PWD" --disable-rpath --disable-python --cross-compile --cross-answers=cross-answers.txt \
		--cross-execute="/usr/bin/true"
	"$AR" rcs "$SDIR/build/$ARCH2/libtalloc.a" bin/default/talloc*.o
}

doall(){
	configure_android

	#download_talloc
	#build_talloc

	build_proot
}

export TARGET=aarch64-linux-android
ARCH2=arm64-v8a
doall

cd $PREVDIR