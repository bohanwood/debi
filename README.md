# Debian Network Reinstall Script

- <span lang="zh-CN">[中文版在这里](./README.zh-CN.md)</span>
- <span lang="ja-JP">[日本語はこちら](./README.ja-JP.md)</span>

## What is this?

A script that reinstalls any VPS or physical machine to minimal Debian via network boot. Works by injecting the Debian installer into GRUB and automatically configuring the installation process.

**Perfect for:**
- Converting Oracle Cloud's Ubuntu images to Debian
- Removing cloud provider surveillance agents 
- Creating minimal, clean Debian environments
- Automating installations with preseed/cloud-init
- Rescuing broken systems

## Quick Start

```bash
# Download the script
curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
chmod +x debi.sh

# Basic installation (creates user 'debian' with sudo access)
sudo ./debi.sh

# Or install as root user instead
sudo ./debi.sh --user root

# Reboot when ready
sudo reboot
```

**Default settings:** Debian 13 (trixie), DHCP networking, user `debian` with sudo access, you'll be prompted for password.

## Platform Support

| Platform | Status | Notes |
|----------|---------|-------|
| ✅ **KVM/Physical** | Full support | All features work |
| ✅ **Most VPS** | Full support | DigitalOcean, Vultr, Linode, etc. |
| ⚠️ **Google Cloud** | Requires manual network | Must use `--ip`, `--gateway` (DHCP broken) |
| ⚠️ **AWS EC2** | BIOS only | UEFI boot not yet supported |
| ❌ **Containers** | Not supported | Requires GRUB bootloader |

**Requirements:**
- KVM or physical machine (not containers)
- GRUB 2 bootloader
- Root access

## Regional Presets

| Preset | Mirror | DNS | NTP | Best for |
|--------|---------|-----|-----|----------|
| *Default* | deb.debian.org | Google DNS | time.google.com | Global |
| `--cloudflare` | deb.debian.org | Cloudflare | time.cloudflare.com | Global (privacy) |
| `--aws` | cdn-aws.deb.debian.org | Google DNS | time.aws.com | AWS instances |
| `--aliyun` | mirrors.aliyun.com | AliDNS | time.amazonaws.cn | China |
| `--ustc` | mirrors.ustc.edu.cn | DNSPod | time.amazonaws.cn | China |
| `--tuna` | mirrors.tuna.tsinghua.edu.cn | DNSPod | time.amazonaws.cn | China |

## Complete Options Reference

### System & User Configuration
| Option | Default | Description |
|--------|---------|-------------|
| `--version 13` | `13` | Debian version: `10`, `11`, `12`, `13`, `14` |
| `--suite trixie` | `trixie` | Debian suite: `stable`, `testing`, `sid`, etc. |
| `--user debian` | `debian` | Username (use `root` for root-only) |
| `--password PASSWORD` | *prompt* | User password (prompted if not specified) |
| `--authorized-keys-url URL` | *password auth* | SSH keys from URL (e.g., `https://github.com/user.keys`) |
| `--no-account-setup` | *create user* | Skip user creation (manual setup via console) |
| `--sudo-with-password` | *no password* | Require password for sudo commands |
| `--timezone UTC` | `UTC` | System timezone (e.g., `Asia/Shanghai`) |
| `--hostname NAME` | *current* | System hostname |

### Network Configuration
| Option | Default | Description |
|--------|---------|-------------|
| `--interface auto` | `auto` | Network interface (e.g., `eth0`, `eth1`) |
| `--ip ADDRESS` | *DHCP* | Static IP: `10.0.0.100`, `1.2.3.4/24`, `2001:db8::1/64` |
| `--static-ipv4` | *DHCP* | Use current IPv4 settings automatically |
| `--netmask MASK` | *auto* | Network mask: `255.255.255.0`, `ffff:ffff:ffff:ffff::` |
| `--gateway ADDRESS` | *auto* | Gateway IP (use `none` for no gateway) |
| `--dns '8.8.8.8 8.8.4.4'` | `1.1.1.1 1.0.0.1` | DNS servers for IPv4 |
| `--dns6 '2001:4860:4860::8888'` | `2606:4700:4700::1111` | DNS servers for IPv6 |
| `--ethx` | *consistent naming* | Use `eth0`/`eth1` instead of `enp0s3` style |
| `--ntp time.google.com` | `time.google.com` | NTP server |

### Network Console (Remote Installation)
| Option | Default | Description |
|--------|---------|-------------|
| `--network-console` | *disabled* | Enable SSH access during installation |

**Network Console Usage:**
1. Enable with `--network-console` and reboot
2. Wait 2-3 minutes for Debian installer to load components
3. SSH to your server: `ssh installer@YOUR_IP`
4. Use multiple terminals:
   - **Alt+F1**: Main installer interface
   - **Alt+F2**: Shell access
   - **Alt+F3**: Additional shell
   - **Alt+F4**: System logs (monitor automated installation progress)
   - Navigate with Alt+Left/Alt+Right

> [!IMPORTANT]  
> If `--authorized-keys-url` is used, SSH password authentication is disabled (SSH keys required), **but you still need to set a user password for VNC console and sudo access.**

### Storage & Partitioning
| Option | Default | Description |
|--------|---------|-------------|
| `--disk /dev/sda` | *auto-detect* | Target disk (**required** if multiple disks) |
| `--no-disk-partitioning` | *auto partition* | Manual partitioning via console |
| `--filesystem ext4` | `ext4` | Root filesystem type |
| `--force-gpt` | *enabled* | Create GPT partition table |
| `--no-force-gpt` | *use GPT* | Use MBR partition table instead |
| `--bios` | *auto-detect* | Force BIOS boot (creates BIOS boot partition) |
| `--efi` | *auto-detect* | Force EFI boot (creates EFI system partition) |
| `--esp 106` | `106` | EFI system partition size (106=100MB, 538=512MB, 1075=1GB) |

### Mirror & Repository Configuration
| Option | Default | Description |
|--------|---------|-------------|
| `--mirror-protocol https` | `https` | Mirror protocol: `http`, `https`, `ftp` |
| `--https` | *enabled* | Alias for `--mirror-protocol https` |
| `--mirror-host deb.debian.org` | `deb.debian.org` | Mirror hostname |
| `--mirror-directory /debian` | `/debian` | Mirror directory path |
| `--mirror-proxy URL` | *none* | HTTP proxy for downloads and APT |
| `--reuse-proxy` | *none* | Use existing `http_proxy` environment variable |
| `--security-repository URL` | *auto* | Security updates repo (use `mirror` for main mirror) |

### APT Repository Components
| Option | Default | Description |
|--------|---------|-------------|
| `--apt-non-free-firmware` | *enabled* | Include non-free firmware (Debian 12+) |
| `--apt-non-free` | *disabled* | Enable non-free repository |
| `--apt-contrib` | *disabled* | Enable contrib repository |
| `--apt-src` | *enabled* | Enable source repositories |
| `--apt-backports` | *enabled* | Enable backports repository |
| `--no-apt-non-free-firmware` | *use default* | Disable non-free firmware |
| `--no-apt-non-free` | *use default* | Disable non-free |
| `--no-apt-contrib` | *use default* | Disable contrib |
| `--no-apt-src` | *use default* | Disable source repositories |
| `--no-apt-backports` | *use default* | Disable backports |

### Package Installation
| Option | Default | Description |
|--------|---------|-------------|
| `--install 'pkg1 pkg2'` | *minimal* | Additional packages (space-separated, quoted) |
| `--install-recommends` | *enabled* | Install recommended packages |
| `--no-install-recommends` | *install recommends* | Skip recommended packages |
| `--upgrade safe-upgrade` | `safe-upgrade` | Package upgrade mode |
| `--safe-upgrade` | *default* | Safe package upgrades during install |
| `--full-upgrade` | *safe upgrade* | Full system upgrade (`dist-upgrade`) |
| `--no-upgrade` | *safe upgrade* | Skip package upgrades entirely |

### Kernel Options
| Option | Default | Description |
|--------|---------|-------------|
| `--kernel PACKAGE` | `linux-image-ARCH` | Kernel package name |
| `--cloud-kernel` | *standard* | Use cloud-optimized kernel |
| `--bpo-kernel` | *stable* | Use newer kernel from backports |
| `--firmware` | *auto-detect* | Include non-free firmware for hardware |
| `--hyperv-pci-hotfix` | *disabled* | Download the matching Debian kernel package, embed it in the installer initrd, and load `pci-hyperv.ko` during installer startup (useful for Azure NVMe/Hyper-V vPCI disk detection) |

### Advanced Options
| Option | Default | Description |
|--------|---------|-------------|
| `--ssh-port 2222` | `22` | Custom SSH port |
| `--bbr` | *disabled* | Enable TCP BBR congestion control |
| `--architecture amd64` | *auto-detect* | Target architecture: `amd64`, `arm64`, `i386`, etc. |
| `--force-lowmem 1` | *auto* | Force low memory mode: `0`, `1`, `2` (for <512MB RAM) |
| `--no-force-efi-extra-removable` | *enabled* | Disable EFI extra removable media path |
| `--grub-timeout 5` | `5` | GRUB menu timeout in seconds |

### Debian Installer Options
| Option | Default | Description |
|--------|---------|-------------|
| `--release-d-i` | *auto* | Use release version of debian-installer |
| `--daily-d-i` | *auto* | Use daily build of debian-installer |

### Cloud-Init Integration
| Option | Default | Description |
|--------|---------|-------------|
| `--cidata /path/to/dir` | *none* | Custom cloud-init data directory |

**Cloud-Init Usage:**
```bash
# Create cloud-init configuration
mkdir my-cloud-config
echo "instance-id: my-server" > my-cloud-config/meta-data
cat > my-cloud-config/user-data << 'EOF'
#cloud-config
hostname: my-server
packages:
  - htop
  - git
EOF

# Use with installation
sudo ./debi.sh --cidata my-cloud-config
```

### Development & Testing
| Option | Default | Description |
|--------|---------|-------------|
| `--dry-run` | *execute* | Generate configuration without installing |
| `--hold` | *reboot* | Don't reboot after installation |
| `--power-off` | *reboot* | Power off instead of reboot |

## Examples

### Oracle Cloud (Ubuntu → Debian)
```bash
sudo ./debi.sh --cloudflare --user debian
```

### Google Cloud Platform
```bash
# GCP requires manual network (replace with your VPC settings)
sudo ./debi.sh --ip 10.128.0.100/24 --gateway 10.128.0.1
```

### Minimal Installation
```bash
sudo ./debi.sh --no-install-recommends --install 'curl git vim' --no-upgrade
```

### China Deployment
```bash
sudo ./debi.sh --ustc --timezone Asia/Shanghai --dns '119.29.29.29'
```

### Network Console Installation
```bash
# Enable remote access during install (SSH keys for network, password still needed for VNC/sudo)
sudo ./debi.sh --network-console --authorized-keys-url https://github.com/yourusername.keys
# After reboot, SSH: ssh installer@YOUR_IP
```

### Static Network with Cloud-Init
```bash
sudo ./debi.sh --ip 192.168.1.100/24 --gateway 192.168.1.1 --cidata ./cloud-config/
```

### Advanced Custom Configuration
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

## Troubleshooting

### Revert All Changes
```bash
# Remove all modifications and restore original GRUB
sudo rm -rf /etc/default/grub.d/zz-debi.cfg /boot/debian-*
sudo update-grub || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### Common Issues

**Multiple disks detected:**
```bash
# List available disks
lsblk
# Specify target disk
sudo ./debi.sh --disk /dev/sda
```

**Low memory VPS (<512MB):**
```bash
sudo ./debi.sh --force-lowmem 1
```

**Network configuration fails:**
```bash
# Use current network settings
sudo ./debi.sh --static-ipv4

# Or configure manually
sudo ./debi.sh --ip YOUR_IP/CIDR --gateway YOUR_GATEWAY
```

**Need firmware for network card:**
```bash
sudo ./debi.sh --firmware
```

**Azure NVMe disk not detected in installer (Hyper-V vPCI):**
```bash
sudo ./debi.sh --hyperv-pci-hotfix
```

**Installation debugging:**
```bash
# Generate preseed file only
sudo ./debi.sh --dry-run

# Enable network console for remote access (SSH keys for remote, password for VNC/sudo)
sudo ./debi.sh --network-console --authorized-keys-url YOUR_KEYS_URL
```

## How It Works

1. **Downloads Debian installer** to `/boot/debian-$VERSION/`
2. **Generates preseed file** with your configuration
3. **Modifies GRUB configuration** (adds installer menu entry)
4. **Injects configuration** into installer initramfs
5. **Updates GRUB** to include new boot option

**Changes made to your system:**
- Files added to `/boot/debian-*/`
- GRUB configuration in `/etc/default/grub.d/zz-debi.cfg`
- Updated GRUB menu

**These changes are safe and reversible** before reboot using the revert command above.

---

*Created by [@bohanyang](https://github.com/bohanyang) • [Issues](https://github.com/bohanyang/debi/issues) • [GitHub](https://github.com/bohanyang/debi)*
