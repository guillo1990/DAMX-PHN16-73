obj-m := ./src/linuwu_sense.o

KVER  ?= $(shell uname -r)
KDIR  ?= /lib/modules/$(KVER)/build
PWD   := $(shell pwd)

MDIR  ?= /lib/modules/$(KVER)/drivers/platform/x86

MODNAME := linuwu_sense

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	sudo rmmod $(MODNAME) || true
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	sudo rm -f /etc/modules-load.d/$(MODNAME).conf
	sudo rm -f /etc/modules-load.d/blacklist-acer_wmi.conf

install: all
	sudo rmmod acer_wmi || true
	echo "blacklist acer_wmi" | sudo tee /etc/modules-load.d/blacklist-acer_wmi.conf > /dev/null
	sudo install -d $(MDIR)
	sudo install -m 644 -c ./src/$(MODNAME).ko $(MDIR)
	sudo depmod -a
	echo "$(MODNAME)" | sudo tee /etc/modules-load.d/$(MODNAME).conf > /dev/null
	sudo modprobe $(MODNAME)
	@echo "Module $(MODNAME) installed and configured to load at boot."
