CCC=/home/yury/work/toolchain/thunderx-tools/bin/aarch64-thunderx-linux-gnu
./configure --host=aarch64 --prefix=/home/yury/work/glibc-img/ltp/lp64        \
	CC=$CCC-gcc  \
	AR=$CCC-ar  \
	STRIP=$CCC-strip     \
	RANLIB=$CCC-ranlib  \
	LDFLAGS=" -Wl,--rpath=/root/sys-root/lib64 -Wl,--dynamic-linker=/root/sys-root/lib64/ld-2.24.90.so"
