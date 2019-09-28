
# Introduction

Here are some notes on installing arch linux on the [Lenovo Yoga 530](https://www.lenovo.com/de/de/laptops/yoga/500-series/Yoga-530-14-Intel/p/88YG5000978). I set up uefi and encrypted the drive. Main goal (and challenge) is to get the touchpad and screen to work. It took a few tries and I tried to update these instructions based on what worked, but can't guarantee that it wouldn't need tweaks anyway.

My original attempt was based on these links
- https://gitlab.com/jsherman82/notes/blob/master/arch.md
- http://ticki.github.io/blog/setting-up-archlinux-on-a-lenovo-yoga/
- https://wiki.archlinux.org/index.php/Lenovo_ThinkPad_Yoga_S1

# Setup

You need to get a bootable USB stick with [arch](https://www.archlinux.org/download/) on it. I did it on the preinstalled windows 10 using [Rufus](https://rufus.ie/). When this is done click the restart button in the start menu while holding down shift, which gets you into the bios settings. Under "further settings", you then have to change the bootorder so that the usb is on top. Press F10 to save and quit the settings.

Once you have loaded into the terminal, load the keymap you need (in my case using `loadkeys de-latin1-nodeadkeys`). To get internet, unblock the card using `rfkill unblock all` and then connect to wifi through `wifi-menu`.

# Create the partitions
Check `fsdisk -l` to check what the harddisk is called, for me it was /dev/nvme0n1 followed by p and the partitionnumber (e.g. nvme0n1p1 for the first partition). For every partition you want to add, enter `fdisk /dev/nvme0n1` and then a set of keycodes, as follows:
- EFI partition:
  * g (start new table)
  * n (new partition)
  * 1 (partition number)
  * enter (for default start block)
  * +300M (for end block)
  * y (in case overwrite needs to be confirmed)
  * t (set type)
  * 1 (set type to uefi)
  * w (write)
- boot partition
  * n
  * 2
  * enter
  * +400M
  * w (we use the default type)
- LVM partition for root and home
  * n
  * 3
  * double enter to get rest of blocks on the disk (I used a swap file here)
  * t
  * 3
  * 31 (linux lvm)
  * w

Then set the filesystem type on the first two partitions (EFI and boot), using the /dev/NAME options found with fdisk -l. I will use my defaults here.

`mkfs.fat -F32 /dev/nvme0n1p1`

`mkfs.ext2 /dev/nvme0n1p2`

# Encryption!

The third partition will be encrypted and contain the LVM. Note that during boot you may end up with an odd keymap, so keep that in mind when choosing the password or when encountering trouble decrypting the drive!

`cryptsetup luksFormat /dev/nvme0n1p3`

Open the crypt to start the LVM formatting.

`cryptsetup open --type luks /dev/nvme0n1p3 lvm`

# LVM

Create the physical volume (the dataalignment is necessary when using an SSD).

`pvcreate --dataalignment 1m /dev/mapper/lvm`

Create the volume group (LUI is just what I decided to call it, short names are good)

`vgcreate LUI /dev/mapper/lvm`


Then setup root and home: 

`lvcreate -L 30GB LUI -n lv_root`

`lvcreate -l +100%FREE LUI -n lv_home`

Activate the volumes:

`modprobe dm_mod`

`vgscan`

`vgchange -ay`

# Mounting Home and root

Set the filessystem for home and root:

`mkfs.ext4 /dev/LUI/lv_root`

`mkfs.ext4 /dev/LUI/lv_home`

Mount home and root

`mount /dev/LUI/lv_root /mnt`

`mkdir /mnt/boot`

`mkdir /mnt/home`

`mount /dev/nvme0n1p2 /mnt/boot`

`mount /dev/LUI/lv_home /mnt/home`


# Install base system

`pacstrap -i /mnt base base-devel`

Write file system table:

`genfstab -U -p /mnt >> /mnt/etc/fstab`

Log into newly set up root:

`arch-chroot /mnt`

Install base packages:

`pacman -S grub efibootmgr dosfstools os-prober mtools linux-headers tlp plasma-wayland-session wpa_supplicant xf86-input-synaptics xf86-input-wacom`

Make sure the drive is decrypted and the lvm recognized by putting "encrypt lvm2" between block and filesystem in the init config file:


`nano /etc/mkinitcpio.conf`

Apply the changes using

`mkinitcpio -p linux`

# Configure root and user(s)

## locale and root password

Uncomment appropriate locale and apply changes:

`nano /etc/locale`

`locale-gen`

Root password:

`passwd`

## user

`useradd -m -g users -G wheel USERNAME`

`passwd USERNAME`

# GRUB

This part is where I was running into some trouble with the links I was following and I had to experiment with the kernel options for a bit. This [link](https://askubuntu.com/questions/575651/what-is-the-difference-between-grub-cmdline-linux-and-grub-cmdline-linux-default) explains the difference between GRUB_CMDLINE_LINUX_DEFAULT and GRUB_CMDLINE_LINUX. The latter is more important and will always be executed, so the encrypted drive must be identified there.

First get the EFI partition into /boot:

`mkdir /boot/EFI`

`mount /dev/nvme0n1p1 /boot/EFI`

Install grub:

`grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck`

Configure grub:

`nano /etc/default/grub` 

I changed the following lines from the default:

GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i8042.noloop i8042.nomux i8042.nopnp i8042.reset"

GRUB_CMDLINE_LINUX="cryptdevice=/dev/nvme0n1p3:LUI:allow-discards"

The i8042 options are for getting the touchpad and touchscreen to work. I added them later on, so I am hoping adding them here might make the touchpad work out of the box, but I can't be sure.

Apply the changes to the grub config.

`grub-mkconfig -o /boot/grub/grub.cfg`

# Make a SWAP file

Allocate memory

`fallocate -l 2G /swapfile`

Change permissions on the file (important for security!)

`chmod 600 /swapfile`

Assign swap

`mkswap /swapfile`

Add swap to fstab (check using `cat /etc/fstab`)

`echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab`

# Exit and reboot

If all went well, you can now unmount and reboot the system.

`exit`

`umount -a`

`reboot`

# Final Comments

## If you end up in the GRUB command line or less

If something goes wrong: F2 during boot and go through live arch system to fix things. imports any entries to the end of the 'linux' line. For me this generally worked out as follows, once in the arch terminal:

`cryptsetup open --type luks /dev/nvme0n1p3 lvm`

`lvscan`

`mount /dev/LUI/lv_root /mnt`

`mount /dev/nvme0n1p2 /mnt/boot`

`mount /dev/LUI/lv_home /mnt/home`

`arch-chroot /mnt`

`rfkill unblock all`

`wifi-menu`

**do what you gotta do**

`exit`

`umount -a`

`reboot`


## Other functions

- Plasma works great with wayland
- Used kde interface to change touchpad and keyboard behaviour
- pulseaudio works immediately with output sound
- if using something like keepass, the kde clipboard can randomly mess copying, can be fixed in the clipboard settings






