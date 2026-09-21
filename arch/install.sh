#!/bin/bash
set -e

# Terminal styling color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

clear
echo -e "${GREEN}=====================================================${RESET}"
echo -e "${GREEN}    Arch Linux Automated Base System Installer       ${RESET}"
echo -e "${GREEN}=====================================================${RESET}\n"

# ==============================================================================
# Step 1: Pre-installation Environment Self-Check
# ==============================================================================
echo -e "${YELLOW}==> [1/7] Performing pre-flight checks...${RESET}"

# Set console font for HiDPI displays
if setfont ter-132b 2>/dev/null; then
    echo -e "Console font: ${GREEN}Applied ter-132b${RESET}"
else
    echo -e "Console font: ${YELLOW}ter-132b not found, using default font${RESET}"
fi

# Check firmware boot mode (Must be 64-bit UEFI)
EFI_PLATFORM_FILE="/sys/firmware/efi/fw_platform_size"
if [ -f "$EFI_PLATFORM_FILE" ]; then
    fw_size=$(cat "$EFI_PLATFORM_FILE")
    if [ "$fw_size" -eq 64 ]; then
        echo -e "Boot mode:    ${GREEN}UEFI 64-bit mode (OK)${RESET}"
    else
        echo -e "Boot mode:    ${RED}Abnormal (${fw_size}-bit UEFI)${RESET}"
        echo -e "${RED}[ERROR] Modern Arch Linux requires 64-bit UEFI! Check BIOS settings.${RESET}"
        exit 1
    fi
else
    echo -e "Boot mode:    ${RED}BIOS/Legacy mode detected${RESET}"
    echo -e "${RED}[ERROR] UEFI mode is required. Please disable CSM/Legacy in BIOS!${RESET}"
    exit 1
fi

# Configure network time synchronization (NTP)
timedatectl set-ntp true 2>/dev/null || true
sleep 1
ntp_status=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
if [ "$ntp_status" = "yes" ]; then
    echo -e "NTP status:   ${GREEN}Active (Synchronized)${RESET}\n"
else
    echo -e "NTP status:   ${YELLOW}Not ready (Check network connection if pacstrap fails later)${RESET}\n"
fi

# Pre-check confirmation
read -rp "Pre-check completed. Proceed with installation? [y/N]: " PRE_CONFIRM

if [[ "$PRE_CONFIRM" =~ ^[Yy] ]]; then
    echo -e "${GREEN}==> Proceeding to configuration...${RESET}\n"
else
    echo -e "${YELLOW}==> Installation aborted by user.${RESET}"
    exit 0
fi

# ==============================================================================
# Step 2: Collect User Configuration
# ==============================================================================
echo -e "${CYAN}-----------------------------------------------------${RESET}"
echo -e "${YELLOW}==> [2/7] Collecting user configuration...${RESET}"

# Hostname
read -r -p "Enter hostname [default: archlinux]: " HOST_NAME
HOST_NAME=${HOST_NAME:-archlinux}

# Username
read -r -p "Enter username to create: " USER_NAME
while [ -z "$USER_NAME" ]; do
    echo -e "${RED}Username cannot be empty!${RESET}"
    read -r -p "Enter username to create: " USER_NAME
done

# CPU Microcode
read -r -p "Select CPU vendor [amd/intel] (default: amd): " CPU_TYPE
CPU_TYPE=${CPU_TYPE:-amd}
if [ "$CPU_TYPE" = "intel" ]; then
    UCODE="intel-ucode"
else
    UCODE="amd-ucode"
fi

# Hibernation Option
read -r -p "Enable Hibernation support with Btrfs swapfile? [y/N]: " ENABLE_HIBERNATE
ENABLE_HIBERNATE=${ENABLE_HIBERNATE:-N}

# ==============================================================================
# Step 3: Disk Selection, Partitioning & Btrfs Layout
# ==============================================================================
echo -e "\n${CYAN}-----------------------------------------------------${RESET}"
echo -e "${YELLOW}==> [3/7] Disk Partitioning & Btrfs Subvolume Setup...${RESET}"
echo -e "Available block devices:"
lsblk -dpno NAME,SIZE,TYPE,MODEL | grep -E "disk"
echo -e "${CYAN}-----------------------------------------------------${RESET}"

read -r -p "Enter target disk path to WIPE (e.g. /dev/nvme0n1 or /dev/sda): " TARGET_DISK
while [ ! -b "$TARGET_DISK" ]; do
    echo -e "${RED}Block device '$TARGET_DISK' does not exist!${RESET}"
    read -r -p "Please enter a valid disk path: " TARGET_DISK
done

echo -e "\n${RED}===================== CRITICAL WARNING =====================${RESET}"
echo -e "${RED}ALL existing data on ${TARGET_DISK} will be PERMANENTLY WIPED!${RESET}"
echo -e "${RED}============================================================${RESET}"

# set swap
read -r -p "Enter swapfile size in GB [default: 36]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-36}

read -r -p "Type 'YES' (uppercase) to confirm wiping the drive: " WIPE_CONFIRM



if [ "$WIPE_CONFIRM" != "YES" ]; then
    echo -e "${YELLOW}==> Disk formatting aborted.${RESET}"
    exit 0
fi

# Resolve partition naming (nvme0n1p1 vs sda1)
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    BOOT_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

# Clean up existing mounts & swap
echo -e "${YELLOW}Cleaning up existing mounts and swap on ${TARGET_DISK}...${RESET}"
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true

# Wiping & GPT Partitioning using sgdisk
echo -e "${YELLOW}Wiping partition table and creating GPT layout...${RESET}"
sgdisk --zap-all "$TARGET_DISK"
wipefs -a "$TARGET_DISK"

# 1: 1GB EFI System Partition (type EF00)
# 2: Rest of disk for Btrfs (type 8300)
sgdisk -n 1:0:+1G -t 1:ef00 "$TARGET_DISK"
sgdisk -n 2:0:0   -t 2:8300 "$TARGET_DISK"

partprobe "$TARGET_DISK"
sleep 2

# Formatting Partitions
echo -e "${YELLOW}Formatting EFI partition (FAT32)...${RESET}"
mkfs.fat -F32 "$BOOT_PART"

echo -e "${YELLOW}Formatting Root partition (Btrfs)...${RESET}"
mkfs.btrfs -f "$ROOT_PART"

# Subvolume Creation (5 Recommended Subvolumes)
echo -e "${YELLOW}Creating Btrfs subvolumes (@, @home, @snapshots, @var_log, @swap)...${RESET}"
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@swap
umount /mnt

# Mount Subvolumes with optimal flags
BTRFS_OPTS="noatime,compress=zstd:1,discard=async"

echo -e "${YELLOW}Mounting subvolumes to /mnt...${RESET}"
mount -o "${BTRFS_OPTS},subvol=@" "$ROOT_PART" /mnt

mkdir -p /mnt/{boot,home,.snapshots,var/log,swap}
mount -o "${BTRFS_OPTS},subvol=@home" "$ROOT_PART" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "$ROOT_PART" /mnt/var/log
mount -o "noatime,discard=async,subvol=@swap" "$ROOT_PART" /mnt/swap
mount "$BOOT_PART" /mnt/boot

# Setup Btrfs Swapfile (36GB)
echo -e "${YELLOW}Creating 36GB Swapfile in @swap subvolume...${RESET}"

# swap_size
btrfs filesystem mkswapfile --size "${SWAP_SIZE}G" /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# ==============================================================================
# Step 4: Official Mirror Setup & pacstrap
# ==============================================================================
echo -e "\n${YELLOW}==> [4/7] Configuring Tsinghua official mirror...${RESET}"
echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

echo -e "${YELLOW}Installing core system packages with pacstrap...${RESET}"
pacstrap -K /mnt base linux linux-firmware terminus-font sudo nano vim networkmanager \
    grub efibootmgr "$UCODE" btrfs-progs git bash-completion

# Generate /etc/fstab
echo -e "\n${YELLOW}Generating /etc/fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab

# Ensure swapfile is recorded in fstab if genfstab missed it
if ! grep -q "/swap/swapfile" /mnt/etc/fstab; then
    echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
fi

echo -e "${GREEN}Generated /etc/fstab:${RESET}"
cat /mnt/etc/fstab

# ==============================================================================
# Step 5: System Configuration in chroot
# ==============================================================================
echo -e "\n${YELLOW}==> [5/7] Creating and executing chroot configuration script...${RESET}"

cat << 'EOF' > /mnt/chroot_setup.sh
#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

HOST_NAME="$1"
ENABLE_HIBERNATE="$2"
ROOT_DEV="$3"
USER_NAME="$4"

echo -e "${GREEN}=== Setting up system in chroot ===${RESET}"

# Timezone and Hardware Clock
echo -e "${YELLOW}Setting timezone to Asia/Shanghai...${RESET}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# Locale Configuration
echo -e "${YELLOW}Configuring locales...${RESET}"
sed -i -E 's/^#[[:space:]]*(en_US|zh_CN)\.UTF-8/\1.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Permanent TTY Console Font
echo -e "${YELLOW}Setting console font to ter-132b...${RESET}"
echo "FONT=ter-132b" > /etc/vconsole.conf

# Hostname and Hosts
echo "$HOST_NAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
HOSTS

# Enable NetworkManager
systemctl enable NetworkManager

# Create Non-root User
echo -e "${YELLOW}Creating user '${USER_NAME}' and configuring sudo...${RESET}"
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists."
else
    useradd -m -G wheel -s /bin/bash "$USER_NAME"
fi

# Enable sudo for wheel group
sed -i -E 's/^#[[:space:]]*(%wheel[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+ALL)/\1/' /etc/sudoers

# Configure archlinuxcn repository (in /etc/pacman.conf, avoiding duplicates)
echo -e "${YELLOW}Configuring archlinuxcn repository...${RESET}"
if ! grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    cat << 'PACMAN_CONF' >> /etc/pacman.conf

[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
PACMAN_CONF
fi

# Initialize keyring and install archlinuxcn-keyring
echo -e "${YELLOW}Initializing pacman keyring and installing archlinuxcn-keyring...${RESET}"
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinuxcn-keyring

# Hibernation Configuration (Optional)
if [[ "$ENABLE_HIBERNATE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Configuring Hibernation (suspend-to-disk)...${RESET}"

    # Add resume hook before filesystems hook
    if grep -q "resume" /etc/mkinitcpio.conf; then
        echo "Resume hook already present in /etc/mkinitcpio.conf"
    else
        sed -i 's/\bfilesystems\b/resume filesystems/' /etc/mkinitcpio.conf
    fi

    # Regenerate initramfs
    echo -e "${YELLOW}Regenerating initramfs...${RESET}"
    mkinitcpio -P

    SWAPFILE_PATH="/swap/swapfile"
    if [ ! -f "$SWAPFILE_PATH" ]; then
        echo -e "${RED}[WARNING] $SWAPFILE_PATH not found! Skipping GRUB resume cmdline setup.${RESET}"
    else
        SWAP_UUID=$(blkid -s UUID -o value "$ROOT_DEV")
        SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r "$SWAPFILE_PATH")

        echo -e "${GREEN}Found UUID: ${SWAP_UUID}${RESET}"
        echo -e "${GREEN}Found Offset: ${SWAP_OFFSET}${RESET}"

        sed -i "s/quiet/quiet resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}/" /etc/default/grub
    fi
else
    echo "Skipping hibernation configuration."
fi

# Install GRUB EFI Bootloader
echo -e "${YELLOW}Installing GRUB EFI Bootloader...${RESET}"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Set Passwords
echo -e "\n${GREEN}Please set ROOT password:${RESET}"
passwd

echo -e "\n${GREEN}Please set password for user '${USER_NAME}':${RESET}"
passwd "$USER_NAME"

rm -f /chroot_setup.sh
echo -e "${GREEN}Chroot configuration complete!${RESET}"
EOF

chmod +x /mnt/chroot_setup.sh

# Run script inside chroot
arch-chroot /mnt /chroot_setup.sh "$HOST_NAME" "$ENABLE_HIBERNATE" "$ROOT_PART" "$USER_NAME"

# ==============================================================================
# Step 6: Clone/Copy Install Scripts Repository to User Home
# ==============================================================================
echo -e "\n${YELLOW}==> [6/7] Copying installation script directory to user home...${RESET}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TARGET_DIR="/mnt/home/${USER_NAME}/linux_install"

rm -rf "$TARGET_DIR"
cp -r "$SCRIPT_DIR" "$TARGET_DIR" || { echo -e "${RED}[ERROR] Failed to copy scripts!${RESET}" >&2; exit 1; }

# Fix ownership
arch-chroot /mnt chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/linux_install" || {
    echo -e "${RED}[ERROR] Failed to fix ownership!${RESET}" >&2
    exit 1
}

echo -e "${GREEN}Scripts successfully copied to: /home/${USER_NAME}/linux_install${RESET}"

# ==============================================================================
# Step 7: Completion & Reboot Prompt
# ==============================================================================
echo -e "\n${GREEN}=====================================================${RESET}"
echo -e "${GREEN}   Arch Linux Base System Installed Successfully!    ${RESET}"
echo -e "${GREEN}=====================================================${RESET}"

read -r -p "Deactivate swap, unmount /mnt and reboot now? [y/N]: " DO_REBOOT
if [[ "$DO_REBOOT" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deactivating swap and unmounting partitions...${RESET}"
    swapoff -a 2>/dev/null || true
    umount -R /mnt
    echo -e "${GREEN}Rebooting...${RESET}"
    reboot
else
    echo -e "${YELLOW}You can manually finish by running:${RESET}"
    echo "swapoff -a && umount -R /mnt && reboot"
fi