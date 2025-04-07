obj-m := src/linuwu_sense.o

KVER  ?= $(shell uname -r)
KDIR  := /lib/modules/$(KVER)/build
PWD   := $(shell pwd)

MDIR  := /lib/modules/$(KVER)/kernel/drivers/platform/x86
MODNAME := linuwu_sense

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

uninstall:
	@sudo rm -f /etc/modules-load.d/$(MODNAME).conf
	@sudo rm -f /etc/modprobe.d/blacklist-acer_wmi.conf
	@sudo systemctl stop linuwu_sense.service
	@sudo systemctl disable linuwu_sense.service
	@sudo rm -f /etc/systemd/system/linuwu_sense.service
	@sudo systemctl daemon-reload
	@sudo rmmod $(MODNAME) 2>/dev/null || true
	@sudo modprobe acer_wmi

install: all
	@sudo rmmod acer_wmi 2>/dev/null || true
	@echo "blacklist acer_wmi" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf > /dev/null
	sudo install -d $(MDIR)
	sudo install -m 644 src/$(MODNAME).ko $(MDIR)
	sudo depmod -a
	@echo "$(MODNAME)" | sudo tee /etc/modules-load.d/$(MODNAME).conf > /dev/null
	sudo modprobe $(MODNAME)
	@sudo cp linuwu_sense.service /etc/systemd/system/
	@sudo systemctl daemon-reload
	@sudo systemctl enable linuwu_sense.service
	@sudo systemctl start linuwu_sense.service
	@echo "Module $(MODNAME) installed and configured to load at boot."

