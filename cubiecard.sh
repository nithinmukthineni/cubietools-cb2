#!/bin/sh
#
# Copyright 2014, Silverio Diquigiovanni <shineworld.software@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

UBOOT_PATH="../u-boot-sunxi"
KERNEL_PATH="../ct-droid1/lichee/linux-3.3"
BUILD_PATH="../ct-droid1/android42/out/target/product/sugar-cubieboard2"

echo_red() {
	echo "\033[31m$1\033[0m"
}

echo_green() {
	echo "\033[32m$1\033[0m"
}

echo_on() {
	echo "on"
	#exec 1>&3 2>&4
}
echo_off() {
	echo "off"
	#exec 3>&1 4>&2 1>/dev/null 2>/dev/null
}	

nand_to_mmc_partition() {
  	sed -i "s/nandd/mmcblk0p5/g" $1
  	sed -i "s/nandj/mmcblk0p11/g" $1
  	sed -i "s/nandk/mmcblk0p12/g" $1
}

echo_green "check root user..."
if [ ! $USER = "root" ]; then
	echo_red "root priviledges required !"
	exit 1
fi

echo_green "check arguments..."
if [ $# -eq 0 ]; then
	echo "enter device (eg. /dev/sda):" 
	read DEV 
else
	if [ $# -ne 1 ]; then
		echo_red "invalid arguments count !"
		echo_red "example usage: $0"
		echo_red "               $0 /dev/sdb"
		exit 1
	else
		DEV=$1
	fi
fi

echo_green "check output device..."
if [ -z "$(fdisk -l 2> /dev/null | grep $1:)" ]; then
	echo_red "device $1 not found"
	exit
fi

echo_green "check u-boot path..."
if [ ! -d "$UBOOT_PATH" ]; then
	echo_red "invalid u-boot path !"
	exit 1
fi

echo_green "check kernel path..."
if [ ! -d "$KERNEL_PATH" ]; then
	echo_red "invalid kernel path !"
	exit 1
fi

echo_green "check build path..."
if [ ! -d "$BUILD_PATH" ] || [ ! -d $BUILD_PATH/root ] || [ ! -d $BUILD_PATH/system ] || [ ! -d $BUILD_PATH/recovery ]; then
	echo_red "invalid build path !"
	exit 1
fi

#
# Mount points for Android 4.2
#
#          from             to             name       size	note
#       ===========   ===============   ==========    ====	====
# 	nanda  vfat - mmcblk0p1  vfat - bootloader  - 8000
#	nandb  emmc - mmcblk0p2  ext4 - env         - 8000
# 	nandc  emmc - mmcblk0p3  ext4 - boot        - 8000	also known as root
# 	nandd  ext4 - mmcblk0p5  ext4 - system      - 100000
# 	nande  ext4 - mmcblk0p6  ext4 - data        - 100000
# 	nandf  emmc - mmcblk0p7  ext4 - misc        - 8000
# 	nandg  ext4 - mmcblk0p8  ext4 - recovery    - 10000
# 	nandh  ext4 - mmcblk0p9  ext4 - cache       - a0000
#	nandi  vfat - mmcblk0p10 vfat - private     - 8000
# 	nandj  ext4 - mmcblk0p11 ext4 - databk      - 80000
# 	nandk  vfat - mmcblk0p12 vfat - UDISK       - 400000

if true; then
. ./partition.sh

PART_START_OFFSET=0x2000
PART_01_SIZE=0x8000
PART_02_SIZE=0x8000
PART_03_SIZE=0x8000
PART_05_SIZE=0x100000
PART_06_SIZE=0x100000
PART_07_SIZE=0x8000
PART_08_SIZE=0x10000
PART_09_SIZE=0xa0000
PART_10_SIZE=0x8000
PART_11_SIZE=0x80000
PART_12_SIZE=0x400000

echo_green "get device geometries..."
part_init "$1"
part_info
echo_green "create device partitions..."
part_move_start $PART_START_OFFSET
part_add $PART_01_SIZE $PART_ID_FAT16
part_add $PART_02_SIZE $PART_ID_LINUX
part_add $PART_03_SIZE $PART_ID_LINUX
part_create_extended
part_add $PART_05_SIZE $PART_ID_LINUX
part_add $PART_06_SIZE $PART_ID_LINUX
part_add $PART_07_SIZE $PART_ID_LINUX
part_add $PART_08_SIZE $PART_ID_LINUX
part_add $PART_09_SIZE $PART_ID_LINUX
part_add $PART_10_SIZE $PART_ID_FAT32
part_add $PART_11_SIZE $PART_ID_LINUX
part_add $PART_12_SIZE $PART_ID_FAT32
part_do_job

echo_green "format device partitions..."
echo_off
mkfs.vfat ${DEV}1 -n bootloader
mkfs.ext4 ${DEV}2 -L env
mkfs.ext4 ${DEV}3 -L boot
mkfs.ext4 ${DEV}5 -L system
mkfs.ext4 ${DEV}6 -L data
mkfs.ext4 ${DEV}7 -L misc
mkfs.ext4 ${DEV}8 -L recovery
mkfs.ext4 ${DEV}9 -L cache
mkfs.vfat ${DEV}10 -n private
mkfs.ext4 ${DEV}11 -L databk
mkfs.vfat ${DEV}12 -n UDISK
echo_on

# workaround for EXT4-fs (mmcblk0pX): Filesystem with huge files cannot be mounted RDWR without CONFIG_LBDAF
# actually cubieboard-tv-sdk, that I'm using with this script, don't had CONFIG_LBDAF enabled so the workaround is needed
echo_green "remove huge_file option from ext4 partitios..."
echo_off
tune2fs -O ^huge_file ${DEV}2
#e2fsck ${DEV}2
tune2fs -O ^huge_file ${DEV}3
#e2fsck ${DEV}3
tune2fs -O ^huge_file ${DEV}5
#e2fsck ${DEV}5
tune2fs -O ^huge_file ${DEV}6
#e2fsck ${DEV}6
tune2fs -O ^huge_file ${DEV}7
#e2fsck ${DEV}7
tune2fs -O ^huge_file ${DEV}8
#e2fsck ${DEV}8
tune2fs -O ^huge_file ${DEV}9
#e2fsck ${DEV}9
tune2fs -O ^huge_file ${DEV}11
#e2fsck ${DEV}11
echo_on
fi

echo_green "write SPL and U-BOOT into device..."
dd if=$UBOOT_PATH/spl/sunxi-spl.bin of=$DEV bs=1024 seek=8
dd if=$UBOOT_PATH/u-boot.img of=$DEV bs=1024 seek=40
sync

echo_green "mount device partitions..."
if [ -d mnt ]; then
	rm -rf mnt
fi

mkdir mnt
mkdir mnt/bootloader
mkdir mnt/boot
mkdir mnt/system
mkdir mnt/recovery

mount ${DEV}1 mnt/bootloader
mount ${DEV}3 mnt/boot
mount ${DEV}5 mnt/system
mount ${DEV}8 mnt/recovery

echo_green "update bootloader..."
mkimage -A ARM -C none -T kernel -O linux -a 40008000 -e 40008000 -d $KERNEL_PATH/output/zImage mnt/bootloader/uImage
cp support/script.bin mnt/bootloader
cp support/uEnv.txt mnt/bootloader
sync

echo_green "update boot..."
cp -r $BUILD_PATH/root/* mnt/boot

echo_green "update system..."
cp -r $BUILD_PATH/system/* mnt/system

echo_green "update recovery..."
cp -r $BUILD_PATH/recovery/* mnt/recovery

echo_green "fixing /system/bin/data_resume.sh"
sed -i "s/dev\/block\/nandi/dev\/block\/nandj/g" mnt/system/bin/data_resume.sh

echo_green "copy modified files"
cp support/init.rc mnt/boot/
cp support/vold.fstab mnt/system/etc/

echo_green "change nand(x)/block/(y) to mmcblk0p(z) partitions..."
nand_to_mmc_partition mnt/boot/init.sun7i.rc
nand_to_mmc_partition mnt/system/etc/vold.fstab
nand_to_mmc_partition mnt/system/bin/preinstall.sh
nand_to_mmc_partition mnt/system/bin/sop.sh
nand_to_mmc_partition mnt/system/bin/data_resume.sh
nand_to_mmc_partition mnt/recovery/root/etc/recovery.fstab

echo_green "umount device partitions..."
sync
umount mnt/bootloader
umount mnt/boot
umount mnt/system
umount mnt/recovery

echo_green "clean mnt path..."
rm -rf mnt

echo_green "== THAT'S ALL FOLKS ! =="
