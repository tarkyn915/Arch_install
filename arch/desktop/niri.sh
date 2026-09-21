#!/bin/bash
set -e

# -------------------------------------------------------------
# 终端输出样式配置
# -------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

# -------------------------------------------------------------
# 运行权限检查（必须为具备 sudo 权限的普通用户）
# -------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR] Do not run this script as root! Use a regular user with sudo instead.${RESET}"
    exit 1
fi

echo -e "${CYAN}====================================================${RESET}"
echo -e "${CYAN}   Install Niri + DMS desktop env   ${RESET}"
echo -e "${CYAN}====================================================${RESET}"

# -------------------------------------------------------------
# 软件安装包组定义
# -------------------------------------------------------------

# Niri + DMS
GROUP_NIRI=(
    niri
    xwayland-satellite
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    alacritty
    dms-shell-niri
    matugen
    cava
    qt6-multimedia-ffmpeg
    qt6-declarative
    qt6-svg
)

# DISPLAY-MANAGER
GROUP_DISPLAY_MANAGER=(
    sddm
)

# FONTS
GROUP_FONTS=(
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
)
# FCITX + RIME
GROUP_FCITX5=(
    fcitx5
    fcitx5-gtk
    fcitx5-qt
    fcitx5-configtool
    fcitx5-chinese-addons
    fcitx5-rime
    rime-ice
)
# sound
GROUP_SOUND=(
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    pavucontrol
)
# COMMON
GROUP_COMMON=(
    base-devel
    git
    yay
    ghostty
    starship
    firefox
    stow
    ffmpeg
    mpv
    onlyoffice-bin
)


# -------------------------------------------------------------
# 安装所有的包
# -------------------------------------------------------------
echo -e "${YELLOW}==> Syncing repos and installing all package groups...${RESET}"
sudo pacman -Syu --needed --noconfirm \
    "${GROUP_NIRI[@]}" \
    "${GROUP_DISPLAY_MANAGER[@]}" \
    "${GROUP_FONTS[@]}" \
    "${GROUP_FCITX5[@]}" \
    "${GROUP_SOUND[@]}" \
    "${GROUP_COMMON[@]}"

# -------------------------------------------------------------
# 4. niri+dms sddm服务绑定与自启配置
# -------------------------------------------------------------
echo -e "${YELLOW}==> Binding DMS user service to niri.service...${RESET}"
systemctl --user add-wants niri.service dms

echo -e "${YELLOW}==> Enabling SDDM display manager on boot...${RESET}"
sudo systemctl enable sddm.service

echo
echo -e "${GREEN}====================================================${RESET}"
echo -e "${GREEN}   Niri + DankMaterialShell desktop suite installed!   ${RESET}"
echo -e "${GREEN}====================================================${RESET}"


# -------------------------------------------------------------
# 输入法环境变量与雾凇拼音自动化部署
# -------------------------------------------------------------
echo -e "${YELLOW}==>Initializing Rime paging rules and rime-ice config...${RESET}"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
mkdir -p "$RIME_DIR"
cat << 'EOF' > "$RIME_DIR/default.custom.yaml"
patch:
__include: rime_ice_suggestion:/
__patch:
key_binder/bindings/+:
- { when: paging, accept: comma, send: Page_Up }
- { when: has_menu, accept: period, send: Page_Down }
EOF
echo -e "${YELLOW}==>Setting Fcitx5 default input method (US keyboard + rime-ice)...${RESET}"
FCITX5_CONFIG_DIR="$HOME/.config/fcitx5"
mkdir -p "$FCITX5_CONFIG_DIR"
cat << 'EOF' > "$FCITX5_CONFIG_DIR/profile"
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime
[Groups/0/Items/0]
Name=keyboard-us
Layout=
[Groups/0/Items/1]
Name=rime
Layout=
[GroupOrder]
0=Default
EOF
echo -e "${YELLOW}==>Reloading input method daemon...${RESET}"
killall fcitx5 2>/dev/null || true
sleep 1
fcitx5 -d >/dev/null 2>&1 || true
echo
echo -e "${GREEN}==============================================${RESET}"
echo -e "${GREEN}   ${DESKTOP_NAME} and all base ecosystem components installed!${RESET}"
echo -e "${GREEN}==============================================${RESET}"

echo
read -rp "Reboot now? [Y/n] " REPLY
case "${REPLY:-y}" in
    [yY]|[yY][eE][sS])
        echo -e "${GREEN}Rebooting into ${DESKTOP_NAME}...${RESET}"
        sudo systemctl reboot
        ;;
    *)
        echo -e "${YELLOW}Skipped. Reboot later with: sudo systemctl reboot${RESET}"
        ;;
esac