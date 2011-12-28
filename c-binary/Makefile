VERSION=unknown

ifdef DEVICE
# Device build
STAGING_DIR=/srv/preware/build/staging/armv7
ifeq ($(shell uname -s),Darwin)
CC=/opt/PalmPDK/arm-gcc/bin/arm-none-linux-gnueabi-gcc
else
CC=/srv/preware/build/toolchain/cs07q3armel/build/arm-2007q3/bin/arm-none-linux-gnueabi-gcc
endif
else
# Emulator build
STAGING_DIR=/srv/preware/build/staging/i686
CC=/srv/preware/build/toolchain/i686-unknown-linux-gnu/build/i686-unknown-linux-gnu/bin/i686-unknown-linux-gnu-gcc
endif

CPPFLAGS :=  
LDFLAGS  := 

papctl: papctl.o

HOST = cdma-pre

install: papctl

clobber:
	rm -rf *.o papctl
