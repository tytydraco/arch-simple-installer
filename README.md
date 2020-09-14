# arch-simple-installer
An extremely basic Arch Linux installer, configuring Arch, GRUB, NetworkManager, and iwd.

# Features
- Consistently reproducible
- 512 MB EFI, everything else is ext4 rootfs
- Timezone, RTC, hosts, hostname setup
- AMD and Intel microcode install
- GRUBv2 UEFI install
- NetworkManager + IWD install
- Bare minimum universal installation

# Usage
1. Boot Arch Linux live image
2. Connect to the internet
3. `curl -L https://bit.ly/3itxqnP > installer`
4. `bash installer`
