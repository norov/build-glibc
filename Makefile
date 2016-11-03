REPO=https://github.com/norov/glibc.git
BRANCH=ilp32-2.24-dev1

ABI=ilp32 lp64

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
BUILD=$(addsuffix .build, $(ABI))
LOGS=$(addsuffix .build.log, $(ABI))

REMOTE=root@10.0.0.2

all: glibc $(ABI)

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

%.build:
	mkdir -p $@;
	cd $@; $(SRC)/configure $(CONF) CXX="$(CXX) -mabi=$(subst .build,,$@)" CC="$(CC) -mabi=$(subst .build,,$@)" >../$@.log || cd ..; rm -rf $@

lp64: lp64.build
	make -C lp64.build -j`nproc`  > lp64.build.log;
	make -C lp64.build install DESTDIR=$(DST)  >> lp64.build.log;

ilp32: ilp32.build
	make -C ilp32.build -j`nproc`  > ilp32.build.log;
	make -C ilp32.build install DESTDIR=$(DST) >> ilp32.build.log;

install: $(DST)
	rsync -avz sys-root $(REMOTE):

$(DST): $(BUILD)

headers_install:
	make -C $(LINUX_DIR) headers_install

# Assume REMOTE has mounted TOP under /
# To do it with sshfs, on REMOTE, try:
# sshfs LOCAL:TOP TOP
check: $(BUILD)
	make -C ilp32.build check $(TEST_WRAPPER) > ilp32.check
	make -C lp64.build check $(TEST_WRAPPER) > lp64.check
