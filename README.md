# arch-simple-installer
An extremely basic Arch Linux installer, configuring Arch, GRUB, NetworkManager, and iwd.

# Features
- Consistently reproducible
- 512 MB EFI, everything else is rootfs
- Timezone, RTC, hosts, hostname setup
- AMD and Intel microcode install
- GRUBv2 UEFI install
- NetworkManager + IWD install
- Bare minimum universal installation

# Comparing Alternatives
- [archfi](https://github.com/MatMoul/archfi): Bloated, large final install, lots of steps.
- [aui](https://github.com/helmuthdu/aui): Manual partitioning, over complicated, requires `unzip` package.
- arch-simple-installer: Auto partition, only 5 manual configs, bare minimum install.

# Usage
1. Boot Arch Linux live image
2. Connect to the internet
3. `curl -L https://bit.ly/3itxqnP > installer`
4. `bash installer`
