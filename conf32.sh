CCC=/home/yury/work/toolchain/thunderx-tools/bin/aarch64-thunderx-linux-gnu
./configure --host=aarch64 --prefix=/home/yury/work/glibc-img/ltp/ilp32        \
	CC=$CCC-gcc  \
	AR=$CCC-ar  \
	STRIP=$CCC-strip     \
	RANLIB=$CCC-ranlib  \
	CFLAGS=-mabi=ilp32 \
	LDFLAGS="-mabi=ilp32 -Wl,--rpath=/root/sys-root/libilp32 \
	-Wl,--dynamic-linker=/root/sys-root/libilp32/ld-2.24.90.so"
