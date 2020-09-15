#!/usr/bin/env bash
# Written by Draco (tytydraco @ GitHub)

# Exit on any error
set -e

err() {
	echo -e "\e[91m[!] $@\e[39m"
	exit 1
}

# Configuration
lsblk
echo -n "Disk [/dev/sda]: "
read DISKPATH
DISKPATH=${DISKPATH:-/dev/sda}
[[ ! -b "$DISKPATH" ]] && err "Disk does not exist. Exiting."

echo -n "Bootloader [efi/bios]: "
read BOOTLOADER
[[ "$BOOTLOADER" != "efi" && "$BOOTLOADER" != "bios" ]] && err "Invalid bootloader mode. Exiting."

[[ "$BOOTLOADER" == "efi" ]] && _GRUB_TARGET="x86_64-efi"
[[ "$BOOTLOADER" == "bios" ]] && _GRUB_TARGET="i386-pc"

echo -n "GRUBv2 Target [$_GRUB_TARGET]: "
read GRUB_TARGET
FILESYSTEM=${GRUB_TARGET:-"$_GRUB_TARGET"}

echo -n "Filesystem [ext4]: "
read FILESYSTEM
FILESYSTEM=${FILESYSTEM:-ext4}
! command -v mkfs.$FILESYSTEM &> /dev/null && err "Filesystem type does not exist. Exiting."

echo -n "Timezone [America/Los_Angeles]: "
read TIMEZONE
TIMEZONE=${TIMEZONE:-America/Los_Angeles}
[[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]] && err "/usr/share/zoneinfo/$TIMEZONE does not exist. Exiting."

echo -n "Hostname [localhost]: "
read HOSTNAME
HOSTNAME=${HOSTNAME:-localhost}

echo -n "Password [root]: "
read -s PASSWORD
PASSWORD=${PASSWORD:-root}

# Setup partition variables
if [[ "$BOOTLOADER" == "efi" ]]
then
	BOOT="${DISKPATH}1"
	ROOT="${DISKPATH}2"
else
	BOOT="N/A"
	ROOT="${DISKPATH}2"
fi

echo ""
echo ""
printf "%-16s\t%-16s\n" "CONFIGURATION" "VALUE"
printf "%-16s\t%-16s\n" "Disk:" "$DISKPATH"
printf "%-16s\t%-16s\n" "Bootloader:" "$BOOTLOADER"
printf "%-16s\t%-16s\n" "Root Filesystem:" "$FILESYSTEM"
printf "%-16s\t%-16s\n" "Boot Partition:" "$BOOT"
printf "%-16s\t%-16s\n" "Root Partition:" "$ROOT"
printf "%-16s\t%-16s\n" "Timezone:" "$TIMEZONE"
printf "%-16s\t%-16s\n" "Hostname:" "$HOSTNAME"
printf "%-16s\t%-16s\n" "Password:" "`echo \"$PASSWORD\" | sed 's/./*/g'`"
echo ""
echo -n "Proceed? [y/n]: "
read PROCEED
[[ "$PROCEED" != "y" ]] && err "User chose not to proceed. Exiting."

# Unmount for safety
[[ "$BOOTLOADER" == "efi" ]] && umount "$BOOT" 2> /dev/null || true
umount "$ROOT" 2> /dev/null || true

# Timezone
timedatectl set-ntp true

# Partitioning
(
	echo g		# Erase as GPT

	# EFI or BIOS partitions
	if [[ "$BOOTLOADER" == "efi" ]]
	then
		echo n
		echo
		echo
		echo +512M
		echo t
		echo 1
	else
		echo n
		echo
		echo
		echo +1M
		echo t
		echo 4
	fi

	echo n		# Linux root
	echo
	echo
	echo
	sleep 3		# Delay to avoid race condition
	echo w		# Write
) | fdisk -w always "$DISKPATH"

# Formatting partitions
[[ "$BOOTLOADER" == "efi" ]] && mkfs.fat -F 32 "$BOOT"
yes | mkfs.$FILESYSTEM "$ROOT"

# Mount our new partition
mount "$ROOT" /mnt

# Initialize base system, kernel, and firmware
pacstrap /mnt base linux linux-firmware

# Setup fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot commands
(
	# Time and date configuration
	echo "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
	echo "hwclock --systohc"

	# Setup locales
	echo "sed -i \"s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/\" /etc/locale.gen"
	echo "locale-gen"
	echo "echo \"LANG=en_US.UTF-8\" > /etc/locale.conf"

	# Setup hostname and hosts file
	echo "echo \"$HOSTNAME\" > /etc/hostname"
	echo "echo -e \"127.0.0.1\tlocalhost\" >> /etc/hosts"
	echo "echo -e \"::1\t\tlocalhost\" >> /etc/hosts"
	echo "echo -e \"127.0.1.1\t$HOSTNAME\" >> /etc/hosts"
	echo "echo -e \"$PASSWORD\n$PASSWORD\" | passwd"

	# Install microcode
	echo "pacman -Sy --noconfirm amd-ucode intel-ucode"

	# Install GRUBv2 as a removable drive (universal across hw)
	if [[ "$BOOTLOADER" == "efi" ]]
	then
		echo "pacman -Sy --noconfirm grub"
		echo "mkdir /boot/efi"
		echo "mount \"$BOOT\" /boot/efi"
		echo "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable"
		echo "grub-mkconfig -o /boot/grub/grub.cfg"
	else
		echo "pacman -Sy --noconfirm grub efibootmgr"
		echo "grub-install --target=i386-pc --removable \"$DISKPATH\""
		echo "grub-mkconfig -o /boot/grub/grub.cfg"
	fi

	# Install and enable NetworkManager on boot
	echo "pacman -Sy --noconfirm networkmanager iwd"
	echo "systemctl enable NetworkManager"
) | arch-chroot /mnt

echo "Install completed on $DISKPATH." 
