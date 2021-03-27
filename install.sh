#!/usr/bin/env bash
# Written by Draco (tytydraco @ GitHub)

# Exit on any error
set -e

err() {
	echo -e " \e[91m*\e[39m $@"
	exit 1
}

prompt() {
	echo -ne " \e[92m*\e[39m $@"
}

# Configuration
lsblk
prompt "Disk [/dev/sda]: "
read DISKPATH
DISKPATH=${DISKPATH:-/dev/sda}
[[ ! -b "$DISKPATH" ]] && err "Disk does not exist. Exiting."

prompt "Filesystem [ext4]: "
read FILESYSTEM
FILESYSTEM=${FILESYSTEM:-ext4}
! command -v mkfs.$FILESYSTEM &> /dev/null && err "Filesystem type does not exist. Exiting."

prompt "Timezone [America/Los_Angeles]: "
read TIMEZONE
TIMEZONE=${TIMEZONE:-America/Los_Angeles}
[[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]] && err "/usr/share/zoneinfo/$TIMEZONE does not exist. Exiting."

prompt "Hostname [localhost]: "
read HOSTNAME
HOSTNAME=${HOSTNAME:-localhost}

prompt "SSH [no]: "
read SSH
SSH=${SSH:-no}

prompt "Password [root]: "
read -s PASSWORD
PASSWORD=${PASSWORD:-root}

# Setup partition variables
BOOT_BIOS="${DISKPATH}1"
BOOT_EFI="${DISKPATH}2"
ROOT="${DISKPATH}3"

echo ""
echo ""
printf "%-16s\t%-16s\n" "CONFIGURATION" "VALUE"
printf "%-16s\t%-16s\n" "Disk:" "$DISKPATH"
printf "%-16s\t%-16s\n" "Root Filesystem:" "$FILESYSTEM"
printf "%-16s\t%-16s\n" "Boot Partition [BIOS]:" "$BOOT_BIOS"
printf "%-16s\t%-16s\n" "Boot Partition [EFI]:" "$BOOT_EFI"
printf "%-16s\t%-16s\n" "Root Partition:" "$ROOT"
printf "%-16s\t%-16s\n" "Timezone:" "$TIMEZONE"
printf "%-16s\t%-16s\n" "Hostname:" "$HOSTNAME"
printf "%-16s\t%-16s\n" "Password:" "`echo \"$PASSWORD\" | sed 's/./*/g'`"
printf "%-16s\t%-16s\n" "SSH:" "$SSH"
echo ""
prompt "Proceed? [y/N]: "
read PROCEED
[[ "$PROCEED" != "y" ]] && err "User chose not to proceed. Exiting."

# Unmount for safety
umount "$BOOT_BIOS" 2> /dev/null || true
umount "$BOOT_EFI" 2> /dev/null || true
umount "$ROOT" 2> /dev/null || true

# Timezone
timedatectl set-ntp true

# Partitioning
(
	echo g		# Erase as GPT

	echo n		# BIOS partition
	echo
	echo
	echo +1M
	echo t
	echo 4

	echo n		# EFI partition
	echo
	echo
	echo +512M
	echo t
	echo
	echo 1

	echo n		# Linux root
	echo
	echo
	echo
	sleep 3		# Delay to avoid race condition
	echo w		# Write
) | fdisk -w always -W always "$DISKPATH"

# Formatting partitions
mkfs.fat -F 32 "$BOOT_EFI"
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
	echo "pacman -Sy --noconfirm grub efibootmgr"

	# BIOS steps
	echo "grub-install --target=i386-pc \"$DISKPATH\" --recheck"

	# EFI steps
	echo "mkdir /boot/efi"
	echo "mount \"$BOOT_EFI\" /boot/efi"
	echo "grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck"
	
	# Install GRUB config
	echo "grub-mkconfig -o /boot/grub/grub.cfg"

	# Install and enable NetworkManager on boot
	echo "pacman -Sy --noconfirm networkmanager iwd"
	echo "systemctl enable NetworkManager"

	# Fix initramfs for portable media
	echo "sed -i \"s/autodetect modconf block filesystems keyboard/block keyboard autodetect modconf filesystems/\" /etc/mkinitcpio.conf"
	echo "mkinitcpio -P"

	# Enable SSH server out of the box
	if [[ "$SSH" == "yes" ]]
	then
                echo "pacman -Sy --noconfirm openssh"
		echo "sed -i \"s/#PermitRootLogin prohibit-password/PermitRootLogin yes/\" /etc/ssh/sshd_config"
		echo "systemctl enable sshd"
	fi
) | arch-chroot /mnt

echo "Install completed on $DISKPATH." 
