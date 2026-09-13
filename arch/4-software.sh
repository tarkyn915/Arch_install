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

echo -e "${GREEN}=== Starting 4-software.sh: Development, Media & Productivity Setup ===${RESET}"

# -------------------------------------------------------------
# 软件包清单定义（按功能模块分类）
# -------------------------------------------------------------

# 1. 基础编译与 AUR 构建工具链（确保 yay 打包不报 fakeroot/debugedit 缺失）
PKG_DEVEL=(
    base-devel
    git
    yay
)

# 2. 完整音频架构与调音台
PKG_AUDIO=(
    pipewire                # 现代音视频核心服务
    wireplumber             # 会话与设备管理器
    pipewire-pulse          # 兼容替代 PulseAudio
    pipewire-alsa           # 兼容 ALSA 应用
    pipewire-jack           # 兼容低延迟 JACK 音频
    pavucontrol             # 图形化音频控制面板
)

# 3. 终端、浏览器与点文件管理
PKG_APPS=(
    ghostty                 # GPU 加速终端
    starship                # 终端提示符工具
    firefox                 # 保底浏览器
    stow                    # 符号链接与 dotfiles 管理工具
)

# 4. 文件管理、解压与图片浏览
PKG_FILES=(
    nautilus                # 主力图形文件管理器
    gvfs                    # 虚拟文件系统支持（回收站、网络位置）
    gvfs-mtp                # 移动设备与手机 MTP 挂载传输
    file-roller             # 图形化归档解压工具
    loupe                   # 官方 Image Viewer（图像查看器）
    webp-pixbuf-loader      # Nautilus 的 WebP 缩略图生成支持
    libheif                 # Nautilus 的 HEIC 图片缩略图与支持
)

# 5. 视频播放器与全能解码组件
PKG_VIDEO=(
    mpv                     # 极简/高性能全能播放器（基于完整 FFmpeg）
    showtime                # 现代化 GNOME 官方视频播放器（Libadwaita 风格）
    celluloid               # GTK 前端的 mpv 播放器（兼具 GUI 与 mpv 强大兼容性）
    ffmpeg                  # 核心音视频解码与多媒体处理库
    ffmpegthumbnailer       # 为 Nautilus 提供视频缩略图预览
    gst-plugins-bad         # GStreamer 专利/额外编解码器（解决 Showtime H.265 问题）
    gst-plugins-ugly        # GStreamer 受限制与非自由编解码器
    gst-libav               # GStreamer 的 FFmpeg 桥接插件
    libde265                # 开源 H.265/HEVC 解码器
)

# 6. Fcitx5 中文输入法与雾凇拼音生态
PKG_IME=(
    fcitx5                  # 输入法框架核心
    fcitx5-gtk              # GTK 模块支持
    fcitx5-qt               # Qt 模块支持
    fcitx5-configtool       # 图形配置界面
    fcitx5-pinyin-zhwiki    # 维基百科中文词库
    fcitx5-chinese-addons   # 官方扩展与云拼音支持
    fcitx5-rime             # Rime 中州韵引擎
    rime-ice                # 雾凇拼音词库与输入方案
)

# -------------------------------------------------------------
# 合并清单并执行安装
# -------------------------------------------------------------
ALL_PACKAGES=(
    "${PKG_DEVEL[@]}"
    "${PKG_AUDIO[@]}"
    "${PKG_APPS[@]}"
    "${PKG_FILES[@]}"
    "${PKG_VIDEO[@]}"
    "${PKG_IME[@]}"
)


# -------------------------------------------------------------
# 预先清理冲突包（关键：防止 --noconfirm 时被默认选 N 阻断）
# -------------------------------------------------------------
if pacman -Qq jack2 &>/dev/null; then
    echo -e "${YELLOW}==> Removing legacy jack2 to avoid conflicts with pipewire-jack...${RESET}"
    sudo pacman -Rdd --noconfirm jack2
fi

# -------------------------------------------------------------
# 执行正式安装
# -------------------------------------------------------------
echo -e "${YELLOW}==> 1. Installing all packages...${RESET}"
sudo pacman -Syu --needed --noconfirm "${ALL_PACKAGES[@]}"


# -------------------------------------------------------------
# 配置输入法全局环境变量 (/etc/environment)
# -------------------------------------------------------------
echo -e "${YELLOW}==> 2. Setting up IME environment variables...${RESET}"
sudo tee -a /etc/environment > /dev/null << 'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

echo
echo -e "${GREEN}=== 4-software.sh Completed Successfully! ===${RESET}"
echo "Next step: Run 5-stow.sh to deploy your personal dotfiles."
