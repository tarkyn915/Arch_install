# Arch install scripts

> 交互式Arch Linux基础系统安装脚本

## Arch Linux

目录结构

```
arch/
├── install.sh        # base system
├── snapshot.sh       # snapshot backup
└── desktop/
    └── kde.sh        # KDE Plasma
    └── niri.sh       # niri + dms
```

快速开始

```
git clone https://github.com/tarkyn915/linux_install.git

bash install.sh
```

### 物理分区

| 分区 | 大小     | 文件系统 | 挂载点  |
| ---- | -------- | -------- | ------- |
| `p1` | 1 GB     | FAT32    | `/boot` |
| `p2` | 剩余全部 | Btrfs    | `/`     |

### Btrfs 子卷布局

| 子卷         | 挂载点        | 用途          |
| ------------ | ------------- | ------------- |
| `@`          | `/`           | 根文件系统    |
| `@home`      | `/home`       | 用户数据      |
| `@snapshots` | `/.snapshots` | 快照          |
| `@var_log`   | `/var/log`    | 日志          |
| `@swap`      | `/swap`       | 存放 swapfile |

> 挂载参数 `noatime,compress=zstd:1,discard=async`

## snapshot.sh

包含组件与依赖 `snapper` `snap-pac` `grub-btrfs` `inotify-tools`，包含Pacman自动快照，GRUB自动刷新

核心配置 (`/etc/snapper/configs/system`) + (`/etc/snap-pac.ini`)

```
# 容量熔断限制
SPACE_LIMIT="0.5"               # 快照最多占用该分区总空间的 50%
FREE_LIMIT="0.2"                # 磁盘剩余空间低于 20% 时优先淘汰老快照

# pacman 软件变动限制 (snap-pac)
NUMBER_LIMIT="20"               # 普通快照上限20
NUMBER_LIMIT_IMPORTANT="10"      # 内核等核心更新的快照保留上限
EMPTY_PRE_POST_CLEANUP="yes"    # 自动丢弃没有产生实质文件变动的空快照

# 定时时间线策略
TIMELINE_LIMIT_HOURLY="3"       # 保留最近 3 小时
TIMELINE_LIMIT_DAILY="3"        # 保留最近 3 天
TIMELINE_LIMIT_WEEKLY="0"       # 关闭周级别
TIMELINE_LIMIT_MONTHLY="1"      # 保留 1 个月
TIMELINE_LIMIT_YEARLY="0"       # 关闭年级别
```

```
[DEFAULT]
important_packages = ["linux", "linux-lts", "linux-zen"]
important_commands = ["pacman -Syu", "pacman -Syyu"]

[system]
snapshot = True
```

恢复快照

```
GRUB进入快照

# 挂载顶层到mnt
sudo mount -o subvolid=5 /dev/sdxx /mnt

# 修改原本的@
sudo mv /mnt/@ /mnt/@_bad

# 恢复快照到新/mnt/@ 5为快照ID
sudo btrfs subvolume snapshot /.snapshots/5/snapshot /mnt/@

# 取消挂载，重新进入桌面
sudo umount /mnt
sudo reboot
```

