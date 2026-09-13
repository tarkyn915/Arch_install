#!/bin/bash

# 定义样式变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# 设置终端字体
echo -e "${GREEN}set terminal font ter-132b${RESET}"
setfont ter-132b

echo

# 检查引导模式
echo -e "${RED}check your boot mode IS 64${RESET}"

echo

TARGET_FILE="/sys/firmware/efi/fw_platform_size"

if [ -f "$TARGET_FILE" ]; then
    size=$(cat "$TARGET_FILE")
    echo "fw_platform_size = ${size}"
else
    echo "fw_platform_size = (no file，maybe on BIOS/Legacy mode)"
fi


echo

# 提取同步状态
ntp_status=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)

if [ "$ntp_status" = "yes" ]; then
    echo -e "NTP status = \033[32m active (yes)\033[0m"
else
    echo -e "NTP 状态 = \033[31m not active (no)\033[0m"
    echo "USE  timedatectl set-ntp true TO SET NTP"
fi


echo

timedatectl set-ntp true
