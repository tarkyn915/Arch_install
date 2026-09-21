# Linux install scripts

> 交互式Linux基础系统安装脚本

## Arch Linux

目录结构

```
arch/
├── install.sh        # base system
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
