REPO=https://github.com/norov/glibc.git
BRANCH=ilp32-2.24-dev1

ABI=ilp32 lp64
_ABI=$(subst .$(BUILD_SUF),,$@)

CC=ccache /home/yury/work/thunderx-tools-437/bin/aarch64-thunderx-linux-gnu-gcc
CXX=ccache /home/yury/work/thunderx-tools-437/bin/aarch64-thunderx-linux-gnu-g++
TOP=/home/yury/work/glibc-img
SRC=$(TOP)/glibc
DST=$(TOP)/sys-root
LINUX_DIR=/home/yury/work/linux

TARGET=--target=aarch64-thunderx-linux-gnu
HOST=--host=aarch64-thunderx-linux-gnu
PREFIX=--prefix=/usr
HEADERS=--with-headers=$(LINUX_DIR)/usr/include
TEST_WRAPPER=test-wrapper="$(TOP)/glibc/scripts/cross-test-ssh.sh $(REMOTE)"

CONF=$(TARGET) $(HOST) $(PREFIX) $(HEADERS)
BUILD_SUF=build
LOG_SUF=log
BUILD=$(addsuffix .$(BUILD_SUF), $(ABI))
LOGS=$(addsuffix .$(LOG_SUF), $(ABI))

REMOTE=root@10.0.0.2

all: glibc $(ABI)# ltp_build

glibc:
	git clone $(REPO)
	cd $@; git checkout $(BRANCH)

pull: glibc
	cd glibc; git checkout $(BRANCH)
	cd glibc; git reset --hard
	cd glibc; git pull -f

clean_glibc:
	rm -rf glibc

clean:
	rm -rf $(BUILD)
	rm -rf $(LOGS)
	rm -rf $(DST)

%.$(BUILD_SUF):
	mkdir -p $@;
	cd $@; $(SRC)/configure $(CONF) CXX="$(CXX) -mabi=$(_ABI)" \
		CC="$(CC) -mabi=$(_ABI)" >../$(_ABI).$(LOG_SUF) || cd ..; \
		rm -rf $@

lp64: lp64.$(BUILD_SUF)
	make -C $@.$(BUILD_SUF) -j`nproc` > $@.$(LOG_SUF);
	make -C $@.$(BUILD_SUF) install DESTDIR=$(DST)  >> $@.$(LOG_SUF);

ilp32: ilp32.$(BUILD_SUF)
	make -C $@.$(BUILD_SUF) -j`nproc` > $@.$(LOG_SUF);
	make -C $@.$(BUILD_SUF) install DESTDIR=$(DST)  >> $@.$(LOG_SUF);

clean_trinity:
	rm -rf trinity32 trinity64
	make -C trinity.src clean

install_trinity: trinity32 trinity64
	scp trinity32 arm:/home/trinity/trinity_32
	scp trinity64 arm:/home/trinity/trinity_64

trinity32: trinity.src
	rm $SYSROOT -rf
	cp -r /home/yury/work/glibc-img/sys-root $SYSROOT
	cp -r /home/yury/work/linux/usr/include/* $SYSROOT/usr/include
	make -C trinity.src  clean
	cd trinity.src; CC=gcc SYSROOT=/home/yury/work/glibc-img/sr \
	CFLAGS="-mabi=ilp32 -B/home/yury/work/glibc-img/sr/usr/libilp32" ./configure  
	CC=gcc SYSROOT=/home/yury/work/glibc-img/sr \
	CFLAGS="-mabi=ilp32 -B/home/yury/work/glibc-img/sr/usr/libilp32" \
	LDFLAGS="-mabi=ilp32 -Wl,--rpath=/root/sys-root/libilp32 \
	-Wl,--dynamic-linker=/root/sys-root/libilp32/ld-2.24.90.so" \
	make -C trinity.src -j12 && mv trinity.src/trinity ./trinity32

trinity64: trinity.src
	rm $SYSROOT -rf
	cp -r /home/yury/work/glibc-img/sys-root $SYSROOT
	cp -r /home/yury/work/linux/usr/include/* $SYSROOT/usr/include
	make -C trinity.src  clean
	cd trinity.src; CC=gcc \
	SYSROOT=/home/yury/work/glibc-img/sr \
	CFLAGS=-B/home/yury/work/glibc-img/sr/usr/lib64 ./configure  
	CC=gcc \
	SYSROOT=/home/yury/work/glibc-img/sr \
	CFLAGS=-B/home/yury/work/glibc-img/sr/usr/lib64 \
	LDFLAGS=" -Wl,--rpath=/root/sys-root/lib64 \
	-Wl,--dynamic-linker=/root/sys-root/lib64/ld-2.24.90.so" \
	make -C trinity.src -j12 && mv trinity.src/trinity ./trinity64

install: $(DST)
	rsync -avz $(DST) $(REMOTE):

$(DST): $(BUILD)

headers_install:
	make -C $(LINUX_DIR) headers_install

# Assume REMOTE has mounted TOP under /
# To do it with sshfs, on REMOTE, try:
# sshfs LOCAL:TOP TOP
check: check64 check32
	diff -y --suppress-common-lines ilp32.build/tests.sum lp64.build/tests.sum | tee check.diff

check64: lp64.$(BUILD_SUF)
	-make -C lp64.$(BUILD_SUF) check $(TEST_WRAPPER) > lp64.check
	cp lp64.build/tests.sum results/lp64-`date -I`.sum

check32: ilp32.$(BUILD_SUF)
	-make -C ilp32.$(BUILD_SUF) check $(TEST_WRAPPER) > ilp32.check
	cp ilp32.build/tests.sum results/ilp32-`date -I`.sum

ltp_build: ltp32 ltp64

ltp_clean:
	rm -rf ltp/ilp32 ltp/lp64
	rm -f ltp-ilp32.err ltp-ilp32.log
	rm -f ltp-lp64.err ltp-lp64.log

ltp32: ltp
	cd ltp; sh ../conf32.sh > ../ltp-ilp32.log;
	cd ltp; make clean >> ../ltp-ilp32.log;
	cd ltp; make -j`nproc` >> ../ltp-ilp32.log;
	cd ltp; make install >> ../ltp-ilp32.log;

ltp64: ltp
	cd ltp; sh ../conf64.sh > ../ltp-lp64.log;
	cd ltp; make clean >> ../ltp-lp64.log;
	cd ltp; make -j`nproc` >> ../ltp-lp64.log;
	cd ltp; make install >> ../ltp-lp64.log;

ltp_install:
	rsync -avz ltp/ilp32 arm:
	rsync -avz ltp/lp64 arm:

ltp_run: ltp_run32 ltp_run64
	diff -y --suppress-common-lines ltp-ilp32.sum ltp-lp64.sum | tee ltp.diff

ltp_run32:
	ssh arm "cd ilp32; rm -f results/ltp-ilp32.sum testcases/bin/ltp-ilp32.out \
		&&  ./runltplite.sh -l ltp-ilp32.sum -p -o ltp-ilp32.out & "
	scp arm:/root/ilp32/results/ltp-ilp32.sum ./

ltp_run64:
	ssh arm "cd lp64; rm -f results/ltp-lp64.sum testcases/bin/ltp-lp64.out \
		&&  ./runltplite.sh -l ltp-lp64.sum -p -o ltp-lp64.out & "
	scp arm:/root/lp64/results/ltp-lp64.sum ./

ltp_show32:
	ssh arm "tail -f ilp32/results/ltp-ilp32.sum"

ltp_show64:
	ssh arm "tail -f lp64/results/ltp-lp64.sum"

