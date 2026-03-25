<div lang="zh-CN">

# Debian 网络重装脚本

## 这是什么？

一个通过网络启动（network boot）方式，将任何 VPS 或物理机重装为最小化 Debian 系统的脚本。其工作原理是将 Debian 安装程序注入到 GRUB 中，并自动完成安装过程的配置。

**非常适合以下场景：**

  - 将 Oracle Cloud 的 Ubuntu 镜像更换为 Debian
  - 移除云服务商内置的监控代理
  - 创建最小、纯净的 Debian 环境
  - 使用 preseed 或 cloud-init 实现自动化安装
  - 拯救或恢复损坏的系统

## 快速上手

```bash
# 下载脚本
curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
chmod +x debi.sh

# 基础安装 (会创建一个拥有 sudo 权限的 'debian' 用户)
sudo ./debi.sh

# 或者，直接以 root 用户安装
sudo ./debi.sh --user root

# 准备就绪后重启
sudo reboot
```

**默认设置：** Debian 13 (trixie)，DHCP 网络，创建一个名为 `debian` 并拥有 sudo 权限的用户，脚本会提示你为该用户设置密码。

## 平台支持

| 平台 | 状态 | 备注 |
| :--- | :--- | :--- |
| ✅ **KVM/物理机** | 完全支持 | 所有功能均可正常工作 |
| ✅ **大多数 VPS** | 完全支持 | DigitalOcean, Vultr, Linode 等 |
| ⚠️ **Google Cloud** | 需要手动配置网络 | 必须使用 `--ip` 和 `--gateway` (DHCP 工作不正常) |
| ⚠️ **AWS EC2** | 仅支持 BIOS | 尚不支持 UEFI 启动模式 |
| ❌ **容器** | 不支持 | 需要 GRUB 引导加载程序 |

**环境要求：**

  - KVM 虚拟化或物理机 (不支持容器)
  - GRUB 2 引导加载程序
  - Root 权限

## 区域预设

| 预设 | 镜像源 | DNS | NTP | 适用场景 |
| :--- | :--- | :--- | :--- | :--- |
| *默认* | deb.debian.org | Google DNS | time.google.com | 全球通用 |
| `--cloudflare` | deb.debian.org | Cloudflare | time.cloudflare.com | 全球通用 (注重隐私) |
| `--aws` | cdn-aws.deb.debian.org | Google DNS | time.aws.com | AWS 实例 |
| `--aliyun` | mirrors.aliyun.com | AliDNS | time.amazonaws.cn | 中国大陆 |
| `--ustc` | mirrors.ustc.edu.cn | DNSPod | time.amazonaws.cn | 中国大陆 |
| `--tuna` | mirrors.tuna.tsinghua.edu.cn | DNSPod | time.amazonaws.cn | 中国大陆 |

## 完整选项参考

### 系统和用户配置

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--version 13` | `13` | Debian 版本：`10`, `11`, `12`, `13`, `14` |
| `--suite trixie` | `trixie` | Debian 发行代号：`stable`, `testing`, `sid` 等 |
| `--user debian` | `debian` | 用户名 (使用 `root` 则只创建 root 用户) |
| `--password PASSWORD` | *交互式提示* | 用户密码 (如果未指定，则会提示输入) |
| `--authorized-keys-url URL` | *密码认证* | 从 URL 加载 SSH 公钥 (例如 `https://github.com/user.keys`) |
| `--no-account-setup` | *创建用户* | 跳过用户创建步骤 (需要通过控制台手动设置) |
| `--sudo-with-password` | *无需密码* | 执行 sudo 命令时需要输入密码 |
| `--timezone UTC` | `UTC` | 系统时区 (例如 `Asia/Shanghai`) |
| `--hostname NAME` | *当前主机名* | 系统主机名 |

### 网络配置

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--interface auto` | `auto` | 网络接口 (例如 `eth0`, `eth1`) |
| `--ip ADDRESS` | *DHCP* | 静态 IP：`10.0.0.100`, `1.2.3.4/24`, `2001:db8::1/64` |
| `--static-ipv4` | *DHCP* | 自动使用当前系统的 IPv4 设置 |
| `--netmask MASK` | *自动* | 子网掩码：`255.255.255.0`, `ffff:ffff:ffff:ffff::` |
| `--gateway ADDRESS` | *自动* | 网关 IP (使用 `none` 表示无网关) |
| `--dns '8.8.8.8 8.8.4.4'` | `1.1.1.1 1.0.0.1` | IPv4 的 DNS 服务器 |
| `--dns6 '2001:4860:4860::8888'` | `2606:4700:4700::1111` | IPv6 的 DNS 服务器 |
| `--ethx` | *一致性命名* | 使用 `eth0`/`eth1` 风格的网卡名，而不是 `enp0s3` |
| `--ntp time.google.com` | `time.google.com` | NTP 时间服务器 |

### 网络控制台 (远程安装)

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--network-console` | *禁用* | 在安装过程中启用 SSH 访问 |

**网络控制台用法：**

1.  使用 `--network-console` 参数并重启
2.  等待 2-3 分钟，让 Debian 安装程序加载组件
3.  通过 SSH 连接到你的服务器：`ssh installer@YOUR_IP`
4.  使用多个终端窗口进行操作：
      - **Alt+F1**: 主安装界面
      - **Alt+F2**: Shell 终端
      - **Alt+F3**: 另一个 Shell 终端
      - **Alt+F4**: 系统日志 (可监控自动化安装进度)
      - 使用 Alt+Left/Alt+Right 切换


**⚠️ 注意事项**

如果使用了 `--authorized-keys-url`，SSH 的密码认证将被禁用 (必须使用 SSH 密钥登录)，**但你仍然需要设置一个用户密码**，用于 VNC 控制台登录和执行 sudo 命令。

### 存储和分区

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--disk /dev/sda` | *自动检测* | 目标磁盘 (**如果有多块磁盘，此项为必填**) |
| `--no-disk-partitioning` | *自动分区* | 通过控制台手动分区 |
| `--filesystem ext4` | `ext4` | 根文件系统类型 |
| `--force-gpt` | *启用* | 创建 GPT 分区表 |
| `--no-force-gpt` | *使用 GPT* | 使用 MBR 分区表代替 GPT |
| `--bios` | *自动检测* | 强制使用 BIOS 启动 (会创建 BIOS boot 分区) |
| `--efi` | *自动检测* | 强制使用 EFI 启动 (会创建 EFI 系统分区) |
| `--esp 106` | `106` | EFI 系统分区 (ESP) 大小 (106=100MB, 538=512MB, 1075=1GB) |

### 镜像源和仓库配置

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--mirror-protocol https` | `https` | 镜像源协议：`http`, `https`, `ftp` |
| `--https` | *启用* | `--mirror-protocol https` 的别名 |
| `--mirror-host deb.debian.org` | `deb.debian.org` | 镜像源主机名 |
| `--mirror-directory /debian` | `/debian` | 镜像源目录路径 |
| `--mirror-proxy URL` | *无* | 用于下载和 APT 的 HTTP 代理 |
| `--reuse-proxy` | *无* | 使用当前环境中的 `http_proxy` 变量 |
| `--security-repository URL` | *自动* | 安全更新仓库地址 (使用 `mirror` 表示与主镜像源一致) |

### APT 仓库组件

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--apt-non-free-firmware` | *启用* | 包含 non-free-firmware (Debian 12+) |
| `--apt-non-free` | *禁用* | 启用 non-free 仓库 |
| `--apt-contrib` | *禁用* | 启用 contrib 仓库 |
| `--apt-src` | *启用* | 启用源码仓库 |
| `--apt-backports` | *启用* | 启用 backports 仓库 |
| `--no-apt-non-free-firmware` | *使用默认值* | 禁用 non-free-firmware |
| `--no-apt-non-free` | *使用默认值* | 禁用 non-free |
| `--no-apt-contrib` | *使用默认值* | 禁用 contrib |
| `--no-apt-src` | *使用默认值* | 禁用源码仓库 |
| `--no-apt-backports` | *使用默认值* | 禁用 backports |

### 软件包安装

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--install 'pkg1 pkg2'` | *最小化* | 额外安装的软件包 (用空格分隔，并用引号括起来) |
| `--install-recommends` | *启用* | 安装推荐的软件包 |
| `--no-install-recommends` | *安装推荐包* | 跳过推荐的软件包 |
| `--upgrade safe-upgrade` | `safe-upgrade` | 软件包升级模式 |
| `--safe-upgrade` | *默认* | 在安装过程中执行安全的软件包升级 |
| `--full-upgrade` | *安全升级* | 执行完整的系统升级 (`dist-upgrade`) |
| `--no-upgrade` | *安全升级* | 完全跳过软件包升级 |

### 内核选项

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--kernel PACKAGE` | `linux-image-ARCH` | 内核软件包名称 |
| `--cloud-kernel` | *标准内核* | 使用为云环境优化的内核 |
| `--bpo-kernel` | *稳定版内核* | 使用来自 backports 的较新内核 |
| `--firmware` | *自动检测* | 为硬件安装 non-free 固件 |
| `--hyperv-pci-hotfix` | *禁用* | 下载与安装器内核匹配的 Debian kernel 包，将其写入安装器 initrd，并在安装器启动早期加载 `pci-hyperv.ko`（适用于 Azure NVMe / Hyper-V vPCI 磁盘识别） |

### 高级选项

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--ssh-port 2222` | `22` | 自定义 SSH 端口 |
| `--bbr` | *禁用* | 启用 TCP BBR 拥塞控制算法 |
| `--architecture amd64` | *自动检测* | 目标系统架构：`amd64`, `arm64`, `i386` 等 |
| `--force-lowmem 1` | *自动* | 强制开启低内存模式：`0`, `1`, `2` (适用于内存 \<512MB 的机器) |
| `--no-force-efi-extra-removable` | *启用* | 禁用 EFI 的 extra removable media 路径 |
| `--grub-timeout 5` | `5` | GRUB 菜单等待超时时间 (秒) |

### Debian 安装程序选项

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--release-d-i` | *自动* | 使用发布版的 debian-installer |
| `--daily-d-i` | *自动* | 使用每日构建版的 debian-installer |

### Cloud-Init 集成

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--cidata /path/to/dir` | *无* | 自定义 cloud-init 数据目录 |

**Cloud-Init 用法：**

```bash
# 创建 cloud-init 配置文件
mkdir my-cloud-config
echo "instance-id: my-server" > my-cloud-config/meta-data
cat > my-cloud-config/user-data << 'EOF'
#cloud-config
hostname: my-server
packages:
  - htop
  - git
EOF

# 在安装时使用
sudo ./debi.sh --cidata my-cloud-config
```

### 开发与测试

| 选项 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `--dry-run` | *执行* | 只生成配置文件，不执行安装 |
| `--hold` | *重启* | 安装后不重启 |
| `--power-off` | *重启* | 安装后关机而不是重启 |

## 使用示例

### Oracle Cloud (Ubuntu → Debian)

```bash
sudo ./debi.sh --cloudflare --user debian
```

### Google Cloud Platform

```bash
# GCP 需要手动配置网络 (请替换为你的 VPC 设置)
sudo ./debi.sh --ip 10.128.0.100/24 --gateway 10.128.0.1
```

### 最小化安装

```bash
sudo ./debi.sh --no-install-recommends --install 'curl git vim' --no-upgrade
```

### 中国大陆部署

```bash
sudo ./debi.sh --ustc --timezone Asia/Shanghai --dns '119.29.29.29'
```

### 使用网络控制台安装

```bash
# 在安装过程中启用远程访问 (SSH 密钥用于网络登录，密码仍需用于 VNC/sudo)
sudo ./debi.sh --network-console --authorized-keys-url https://github.com/yourusername.keys
# 重启后，通过 SSH 连接: ssh installer@YOUR_IP
```

### 静态网络与 Cloud-Init

```bash
sudo ./debi.sh --ip 192.168.1.100/24 --gateway 192.168.1.1 --cidata ./cloud-config/
```

### 高级自定义配置

```bash
sudo ./debi.sh \
  --version 13 \
  --user admin \
  --timezone Europe/London \
  --disk /dev/nvme0n1 \
  --filesystem btrfs \
  --cloud-kernel \
  --bbr \
  --ssh-port 2222 \
  --install 'htop iotop ncdu'
```

## 故障排查

### 撤销所有更改

```bash
# 移除所有修改并恢复原始的 GRUB 配置
sudo rm -rf /etc/default/grub.d/zz-debi.cfg /boot/debian-*
sudo update-grub || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 常见问题

**检测到多块磁盘：**

```bash
# 列出可用磁盘
lsblk
# 指定目标磁盘
sudo ./debi.sh --disk /dev/sda
```

**低内存 VPS (\<512MB)：**

```bash
sudo ./debi.sh --force-lowmem 1
```

**网络配置失败：**

```bash
# 使用当前系统的网络设置
sudo ./debi.sh --static-ipv4

# 或者手动配置
sudo ./debi.sh --ip YOUR_IP/CIDR --gateway YOUR_GATEWAY
```

**网卡需要固件 (firmware)：**

```bash
sudo ./debi.sh --firmware
```

**Azure NVMe 磁盘在安装器中无法识别（Hyper-V vPCI）：**

```bash
sudo ./debi.sh --hyperv-pci-hotfix
```

**安装过程调试：**

```bash
# 只生成 preseed 文件
sudo ./debi.sh --dry-run

# 启用网络控制台进行远程访问 (SSH 密钥用于远程登录，密码用于 VNC/sudo)
sudo ./debi.sh --network-console --authorized-keys-url YOUR_KEYS_URL
```

## 工作原理

1.  **下载 Debian 安装程序** 到 `/boot/debian-$VERSION/` 目录
2.  根据你的配置**生成 preseed 应答文件**
3.  **修改 GRUB 配置** (添加一个新的安装程序菜单项)
4.  将配置文件**注入到安装程序的 initramfs** 中
5.  **更新 GRUB** 以加载新的启动选项

**对你系统所做的更改：**

  - 在 `/boot/debian-*/` 目录中添加文件
  - 在 `/etc/default/grub.d/zz-debi.cfg` 创建 GRUB 配置文件
  - 更新 GRUB 菜单

**在重启之前，所有这些更改都是安全且可逆的**，可以使用上面的撤销命令来恢复。

-----

*作者 [@bohanyang](https://github.com/bohanyang) • [问题反馈](https://github.com/bohanyang/debi/issues) • [GitHub 仓库](https://github.com/bohanyang/debi)*

</div>
