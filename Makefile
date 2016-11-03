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

install: $(DST)
	rsync -avz $(DST) $(REMOTE):

$(DST): $(BUILD)

headers_install:
	make -C $(LINUX_DIR) headers_install

# Assume REMOTE has mounted TOP under /
# To do it with sshfs, on REMOTE, try:
# sshfs LOCAL:TOP TOP
check: $(BUILD)
	make -C ilp32.$(BUILD_SUF) check $(TEST_WRAPPER) > ilp32.check
	make -C lp64.$(BUILD_SUF) check $(TEST_WRAPPER) > lp64.check
