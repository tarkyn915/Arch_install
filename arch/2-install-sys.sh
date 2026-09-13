#!/bin/bash
set -e

# 终端样式颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${GREEN}=== Arch Linux Installation & System Setup ===${RESET}"
echo

# 1. 检查 /mnt 分区是否已正常挂载
if ! mountpoint -q /mnt; then
    echo -e "${RED}[ERROR] /mnt is not mounted! Please mount your target partitions first.${RESET}"
    exit 1
fi

# 2. 收集用户配置信息
read -r -p "Enter hostname [default: archlinux]: " HOST_NAME
HOST_NAME=${HOST_NAME:-archlinux}

# 强制要求输入非空用户名
read -r -p "Enter username to create: " USER_NAME
while [ -z "$USER_NAME" ]; do
    echo -e "${RED}Username cannot be empty!${RESET}"
    read -r -p "Enter username to create: " USER_NAME
done

# CPU 微码包选择
read -r -p "Select CPU vendor [amd/intel] (default: amd): " CPU_TYPE
CPU_TYPE=${CPU_TYPE:-amd}
if [ "$CPU_TYPE" = "intel" ]; then
    UCODE="intel-ucode"
else
    UCODE="amd-ucode"
fi

# 休眠与 Btrfs Swapfile 支持选择
read -r -p "Enable Hibernation support with Btrfs swapfile? [y/N]: " ENABLE_HIBERNATE
ENABLE_HIBERNATE=${ENABLE_HIBERNATE:-N}

BTRFS_DEV=""
if [[ "$ENABLE_HIBERNATE" =~ ^[Yy]$ ]]; then
    echo
    lsblk -p -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
    echo
    read -r -p "Enter Btrfs partition path where /swap resides (e.g. /dev/sda2 or /dev/nvme0n1p2): " BTRFS_DEV
    while [ ! -b "$BTRFS_DEV" ]; do
        echo -e "${RED}Block device '$BTRFS_DEV' does not exist!${RESET}"
        read -r -p "Please enter a valid partition path: " BTRFS_DEV
    done
fi

# 3. 配置官方清华镜像源并执行 pacstrap
echo
echo -e "${YELLOW}Configuring Tsinghua official mirror...${RESET}"
echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# 安装系统核心基础包（含 vim、网络管理、引导工具、微码等）
echo -e "${YELLOW}Installing base packages (including vim) with pacstrap...${RESET}"
pacstrap -K /mnt base linux linux-firmware terminus-font sudo nano vim networkmanager \
    grub efibootmgr "$UCODE" btrfs-progs git bash-completion

# 生成挂载信息表 /etc/fstab
echo
echo -e "${YELLOW}Generating /etc/fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "${GREEN}Generated fstab:${RESET}"
cat /mnt/etc/fstab
echo

# 4. 生成新系统初始化脚本（chroot 内部执行）
cat << 'EOF' > /mnt/chroot_setup.sh
#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

HOST_NAME="$1"
ENABLE_HIBERNATE="$2"
BTRFS_DEV="$3"
USER_NAME="$4"

echo -e "${GREEN}=== Setting up system in chroot ===${RESET}"

# 设置时区与同步硬件时钟
echo -e "${YELLOW}Setting timezone to Asia/Shanghai...${RESET}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# 配置字符集与本地化编码
echo -e "${YELLOW}Configuring locales...${RESET}"
sed -i -E 's/^#[[:space:]]*(en_US|zh_CN)\.UTF-8/\1.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 配置控制台默认大字体（TTY 永久生效）
echo -e "${YELLOW}Setting console font to ter-132b...${RESET}"
echo "FONT=ter-132b" > /etc/vconsole.conf

# 配置系统主机名与本地 hosts 解析
echo "$HOST_NAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
HOSTS

# 启用开机自启 NetworkManager
systemctl enable NetworkManager

# 创建普通用户并加入 wheel 管理组
echo -e "${YELLOW}Creating user '${USER_NAME}' and configuring sudo...${RESET}"
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists."
else
    useradd -m -G wheel -s /bin/bash "$USER_NAME"
fi

# 解开 wheel 组的 sudo 权限限制
sed -i -E 's/^#[[:space:]]*(%wheel[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+ALL)/\1/' /etc/sudoers

# 配置 archlinuxcn 国内社区源
echo -e "${YELLOW}Configuring archlinuxcn repository...${RESET}"
if ! grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    cat << 'PACMAN_CONF' >> /etc/pacman.conf

[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
PACMAN_CONF
fi

# 初始化密钥环并安装 archlinuxcn-keyring
echo -e "${YELLOW}Initializing keyring and installing archlinuxcn-keyring...${RESET}"
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinuxcn-keyring

# 配置休眠唤醒（可选）
if [[ "$ENABLE_HIBERNATE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Configuring Hibernation (suspend-to-disk)...${RESET}"
    
    # 向 initramfs 添加 resume hook
    if grep -q "resume" /etc/mkinitcpio.conf; then
        echo "Resume hook already present in /etc/mkinitcpio.conf"
    else
        sed -i 's/\bfilesystems\b/resume filesystems/' /etc/mkinitcpio.conf
    fi

    # 重新生成系统 initramfs 镜像
    echo -e "${YELLOW}Regenerating initramfs (mkinitcpio -P)...${RESET}"
    mkinitcpio -P

    # 计算 Btrfs swapfile 的物理偏移量与磁盘 UUID 并写入 GRUB
    SWAPFILE_PATH="/swap/swapfile"
    if [ ! -f "$SWAPFILE_PATH" ]; then
        echo -e "${RED}[WARNING] $SWAPFILE_PATH not found! Skipping GRUB resume cmdline setup.${RESET}"
    else
        SWAP_UUID=$(blkid -s UUID -o value "$BTRFS_DEV")
        SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r "$SWAPFILE_PATH")
        
        echo -e "${GREEN}Found UUID: ${SWAP_UUID}${RESET}"
        echo -e "${GREEN}Found Offset: ${SWAP_OFFSET}${RESET}"

        # 将 resume 启动参数写入 GRUB 配置文件
        sed -i "s/quiet/quiet resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}/" /etc/default/grub
    fi
else
    echo "Skipping hibernation configuration."
fi

# 安装 GRUB UEFI 引导器并生成配置文件
echo -e "${YELLOW}Installing GRUB EFI Bootloader...${RESET}"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 设置 root 用户密码
echo
echo -e "${GREEN}Please set ROOT password:${RESET}"
passwd

# 设置新建普通用户的密码
echo
echo -e "${GREEN}Please set password for '${USER_NAME}':${RESET}"
passwd "$USER_NAME"

# 任务完成后清理自身临时脚本
rm -f /chroot_setup.sh
echo -e "${GREEN}Chroot configuration complete!${RESET}"
EOF

chmod +x /mnt/chroot_setup.sh

# 5. 进入 chroot 执行刚刚生成的初始化脚本
echo -e "${GREEN}Entering chroot...${RESET}"
arch-chroot /mnt /chroot_setup.sh "$HOST_NAME" "$ENABLE_HIBERNATE" "$BTRFS_DEV" "$USER_NAME"

# 6. 完成安装并提示是否卸载分区重启
echo
echo -e "${GREEN}=== Installation finished successfully! ===${RESET}"
read -r -p "Unmount /mnt and reboot now? [y/N]: " DO_REBOOT
if [[ "$DO_REBOOT" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deactivating swap and unmounting partitions...${RESET}"
    swapoff -a 2>/dev/null || true
    umount -R /mnt
    echo -e "${GREEN}Rebooting...${RESET}"
    reboot
else
    echo "You can manually exit with: swapoff -a && umount -R /mnt && reboot"
fi
