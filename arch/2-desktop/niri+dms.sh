#!/bin/bash
set -e

# 终端样式颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# 1. 检查运行权限（必须以非 root 普通用户运行）
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR] Do not run this script as root! Please run as your regular user with sudo access.${RESET}"
    exit 1
fi

echo -e "${GREEN}=== Installing Niri + DankMaterialShell (Desktop Only) ===${RESET}"

# 2. 仅安装合成器、XWayland、Portal、DMS 外壳及图形登录管理器 and fonts
echo -e "${YELLOW}Installing compositor, shell, portals, and display manager...${RESET}"
sudo pacman -Syu --needed --noconfirm \
    niri \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    alacritty \
    dms-shell-niri \
    matugen \
    cava \
    qt6-multimedia-ffmpeg \
    qt6-declarative \
    qt6-svg \
    sddm \
    ttf-jetbrains-mono-nerd \
    noto-fonts-cjk \
    noto-fonts-emoji \
    wqy-microhei

# 3. 绑定 systemd 用户服务自动托管 DMS
echo -e "${YELLOW}Binding DMS shell service to niri.service...${RESET}"
systemctl --user add-wants niri.service dms.service || systemctl --user add-wants niri.service dms

# 4. 启用 SDDM 显示管理器
echo -e "${YELLOW}Enabling SDDM display manager...${RESET}"
sudo systemctl enable sddm.service

echo
echo -e "${GREEN}=== Niri Desktop Setup Completed! ===${RESET}"
echo "Next step: Run 4-software.sh to set up yay, audio, fonts, and apps."
