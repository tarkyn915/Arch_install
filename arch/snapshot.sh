#!/bin/bash
# ==============================================================================
# Btrfs 快照三件套配置脚本: Snapper + snap-pac + grub-btrfs
# 适用环境: 根目录为独立 Btrfs 子卷 (@)，且快照独立挂载 (@snapshots -> /.snapshots)
# ==============================================================================

set -euo pipefail

# 1. 检查 root / sudo 权限
if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 sudo 或 root 权限执行此脚本。"
    exit 1
fi

echo "==> 1. 安装所需软件包..."
pacman -S --needed --noconfirm snapper snap-pac grub-btrfs inotify-tools

echo "==> 2. 配置 Snapper (通过默认模板构建 system 配置)..."
mkdir -p /etc/snapper/configs /etc/conf.d

# 复制默认模板
cp /usr/share/snapper/config-templates/default /etc/snapper/configs/system

# 注册配置名到 /etc/conf.d/snapper
echo 'SNAPPER_CONFIGS="system"' > /etc/conf.d/snapper

# 写入更加人性化的策略 (3小时即时后悔药 + 3天日常 + 1个月底包 + pacman 容纳 20 组)
cat << 'EOF' > /etc/snapper/configs/system
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"

ALLOW_USERS=""
ALLOW_GROUPS="wheel"
SYNC_ACL="no"

BACKGROUND_COMPARISON="yes"

# pacman 软件变动限制 (20 个普通快照约等于 10 次操作，10 个内核重要快照)
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="10"

# 时间线定时快照策略 (专治改错配置，同时极度节约空间)
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="3"
TIMELINE_LIMIT_DAILY="3"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="1"
TIMELINE_LIMIT_YEARLY="0"

# 自动清理 pre/post 之间完全无实质文件变动的空快照
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

# 锁紧快照目录权限
chmod 750 /.snapshots

echo "==> 3. 配置 snap-pac..."
cat << 'EOF' > /etc/snap-pac.ini
[DEFAULT]
important_packages = ["linux", "linux-lts", "linux-zen"]
important_commands = ["pacman -Syu", "pacman -Syyu"]

[system]
snapshot = True
EOF

echo "==> 4. 启用后台服务与自动监听守护进程..."
# 启用时间线自动快照与旧快照清理定时器
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

# 启用 grub-btrfsd (监控快照变动并自动刷新 GRUB 菜单)
systemctl enable --now grub-btrfsd.service

echo "==> 5. 初始生成 GRUB 引导配置..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> 6. 验证当前 Snapper 配置列表..."
snapper list-configs

echo "=========================================================="
echo "配置全部完成！"
echo "已启用人性化策略：3 小时即时恢复 + 3 天滚动 + 1 个月稳定底包。"
echo "=========================================================="
