obj-m += ./src/linuwu_sense.o

KDIR = /lib/modules/$(shell uname -r)/build


all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	sudo rmmod acer_wmi
	sudo insmod linuwu_sense.ko
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	sudo rmmod linuwu_sense.ko
