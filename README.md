# Linux install scripts

## arch

arch的脚本分为三个部分，只需要手动进行硬盘分区和挂载就可以了（默认需要配置/swap/swapfile，脚本内置休眠配置）

| 脚本             | 内容                                                         |
| ---------------- | ------------------------------------------------------------ |
| check            | 设置终端字体ter-132b 检查引导模式 确认时间同步               |
| 1-install-sys.sh | 检查/mnt是否正常挂载，配置root和普通用户，配置休眠（可选），安装基本系统，配置fstab，配置新系统时区，本地化编码，配置hostname，添加普通用户进sudo组，配置archlinuxcn源，安装GRUB |
| 2-desktop        | 目前只有一个niri+dms的环境（内置niri官方推荐的安装+几个中文字体包+sddm） |
| 3-software.sh    | 安装基础软件集合（个人向）包含基础系统音频+视频+图片组件，ghostty终端，firefox，fcitx5+rime+雾凇 |

