#!/bin/sh
# shellcheck shell=dash

set -eu

err() {
    printf "\nError: %s.\n" "$1" 1>&2
    exit 1
}

warn() {
    printf "\nWarning: %s.\nContinuing with the default...\n" "$1" 1>&2
    sleep 5
}

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Sets variable:
in_target_script=
in_target() {
    local command=

    for argument in "$@"; do
        command="$command $argument"
    done

    if [ -n "$command" ]; then
        [ -z "$in_target_script" ] && in_target_script='true'
        in_target_script="$in_target_script;$command"
    fi
}

in_target_backup() {
    in_target "if [ ! -e \"$1.backup\" ]; then cp \"$1\" \"$1.backup\"; fi"
}

configure_sshd() {
    # !isset($sshd_config_backup)
    [ -z "${sshd_config_backup+1s}" ] && in_target_backup /etc/ssh/sshd_config
    sshd_config_backup=
    in_target sed -Ei \""s/^#?$1 .+/$1 $2/"\" /etc/ssh/sshd_config
}

prompt_password() {
    local prompt=

    if [ $# -gt 0 ]; then
        prompt=$1
    elif [ "$username" = root ]; then
        prompt="Choose a password for the root user: "
    else
        prompt="Choose a password for user $username: "
    fi

    stty -echo
    trap 'stty echo' EXIT

    while [ -z "$password" ]; do
        echo -n "$prompt" > /dev/tty
        read -r password < /dev/tty
        echo > /dev/tty
    done

    stty echo
    trap - EXIT
}

download() {
    # Set "$http/https/ftp_proxy" with "$mirror_proxy"
    # only when none of those have ever been set
    [ -n "$mirror_proxy" ] &&
    [ -z "${http_proxy+1s}" ] &&
    [ -z "${https_proxy+1s}" ] &&
    [ -z "${ftp_proxy+1s}" ] &&
    export http_proxy="$mirror_proxy" &&
    export https_proxy="$mirror_proxy" &&
    export ftp_proxy="$mirror_proxy"

    if command_exists wget; then
        wget -O "$2" "$1"
    elif command_exists curl; then
        curl -fL "$1" -o "$2"
    elif command_exists busybox && busybox wget --help > /dev/null 2>&1; then
        busybox wget -O "$2" "$1"
    else
        err 'Cannot find "wget", "curl" or "busybox wget" to download files'
    fi
}

find_kernel_package() {
    local package_name filename

    package_name="linux-image-$1"
    filename=$(
        gzip -dc "$2" | awk -v pkg="$package_name" '
            BEGIN { RS = ""; FS = "\n" }
            $1 == "Package: " pkg {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^Filename: /) {
                        sub(/^Filename: /, "", $i)
                        print $i
                        exit
                    }
                }
            }
        '
    )
    [ -n "$filename" ] && {
        printf '%s\n' "$filename"
        return 0
    }

    package_name="linux-image-$1-unsigned"
    filename=$(
        gzip -dc "$2" | awk -v pkg="$package_name" '
            BEGIN { RS = ""; FS = "\n" }
            $1 == "Package: " pkg {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^Filename: /) {
                        sub(/^Filename: /, "", $i)
                        print $i
                        exit
                    }
                }
            }
        '
    )
    [ -n "$filename" ] && printf '%s\n' "$filename"
}

find_installer_kernel_version() {
    cpio -it -F "$1" 2> /dev/null |
    sed -n 's#^lib/modules/\([^/]*\)/.*#\1#p' |
    sort -u |
    head -n 1
}

inject_hyperv_pci_hotfix() {
    local initrd_file installer_kernel_version packages_url package_path tmpdir

    initrd_file=$1
    installer_kernel_version=$(find_installer_kernel_version "$initrd_file")
    [ -n "$installer_kernel_version" ] ||
    err "Could not determine the installer kernel version from $initrd_file"

    tmpdir=$(mktemp -d)
    packages_url="$mirror_protocol://$mirror_host$mirror_directory/dists/$suite/main/binary-$architecture/Packages.gz"
    download "$packages_url" "$tmpdir/Packages.gz"

    package_path=$(find_kernel_package "$installer_kernel_version" "$tmpdir/Packages.gz" || true)
    [ -n "$package_path" ] || {
        rm -rf "$tmpdir"
        err "Could not find a Debian kernel package for installer kernel $installer_kernel_version"
    }

    mkdir -p \
        "$tmpdir/hotfix/debi-hyperv-pci" \
        "$tmpdir/hotfix/lib/debian-installer-startup.d"
    download "$mirror_protocol://$mirror_host$mirror_directory/$package_path" "$tmpdir/hotfix/debi-hyperv-pci/kernel.deb"
    chmod 0644 "$tmpdir/hotfix/debi-hyperv-pci/kernel.deb"

    cat > "$tmpdir/hotfix/lib/debian-installer-startup.d/S25pci-hyperv-hotfix" << EOF
#!/bin/sh
set -eu

kernel_version=$installer_kernel_version
module_path="/lib/modules/\$kernel_version/kernel/drivers/pci/controller/pci-hyperv.ko"
package_path=/debi-hyperv-pci/kernel.deb
tmpdir=

cleanup() {
    [ -n "\$tmpdir" ] && rm -rf "\$tmpdir"
}

trap cleanup EXIT INT TERM

modprobe pci_hyperv_intf 2> /dev/null || true

if [ ! -f "\$module_path" ]; then
    tmpdir=\$(mktemp -d /tmp/debi-hv-pci.XXXXXX) || exit 0
    data_member=\$(ar t "\$package_path" 2> /dev/null | awk '/^data\\.tar\\./ { print; exit }')
    ar p "\$package_path" "\$data_member" > "\$tmpdir/\$data_member" 2> /dev/null || exit 0
    mkdir -p "\$tmpdir/extract" "\$(dirname "\$module_path")"
    xzcat "\$tmpdir/\$data_member" | tar -xf - -C "\$tmpdir/extract" "./lib/modules/\$kernel_version/kernel/drivers/pci/controller/pci-hyperv.ko" 2> /dev/null || exit 0
    cp -f "\$tmpdir/extract/lib/modules/\$kernel_version/kernel/drivers/pci/controller/pci-hyperv.ko" "\$module_path" || exit 0
    chmod 0644 "\$module_path" || exit 0
fi

modprobe pci_hyperv 2> /dev/null || insmod "\$module_path" 2> /dev/null || true
EOF
    chmod 0755 "$tmpdir/hotfix/lib/debian-installer-startup.d/S25pci-hyperv-hotfix"

    (
        cd "$tmpdir/hotfix"
        find debi-hyperv-pci lib | cpio -o -H newc -A -F "$initrd_file" > /dev/null 2>&1
    ) || {
        rm -rf "$tmpdir"
        err 'Could not append the Hyper-V PCI hotfix to the installer initrd'
    }

    rm -rf "$tmpdir"
}

# Set "$mirror_proxy" with "$http/https/ftp_proxy"
# only when it is empty and one of those is not empty
set_mirror_proxy() {
    [ -n "$mirror_proxy" ] && return

    case $mirror_protocol in
        http)
            if [ -n "${http_proxy+1s}" ]; then mirror_proxy="$http_proxy"; fi
            ;;
        https)
            if [ -n "${https_proxy+1s}" ]; then mirror_proxy="$https_proxy"; fi
            ;;
        ftp)
            if [ -n "${ftp_proxy+1s}" ]; then mirror_proxy="$ftp_proxy"; fi
            ;;
        *)
            err "Unsupported protocol: $mirror_protocol"
    esac
}

# Determines the security repository path format based on Debian suite
# - Buster (Debian 10): Uses old format "buster/updates" 
# - Bullseye onwards and testing: Uses new format "suite-security"
# - Sid/unstable: No security repository (fixes go directly to unstable)
set_security_archive() {
    case $suite in
        buster)
            security_archive="$suite/updates"
            ;;
        bullseye|oldoldstable|bookworm|oldstable|trixie|stable|forky|testing)
            security_archive="$suite-security"
            ;;
        sid|unstable)
            security_archive=''
            ;;
        *)
            err "Unsupported suite: $suite"
    esac
}

# Determines whether to use daily or stable installer builds
# - Stable/oldstable releases: Use stable installer builds (thoroughly tested)
# - Testing/unstable: Use daily installer builds (latest changes, may be less stable)
# Daily builds are necessary for testing/unstable as they need the latest kernel and packages
set_daily_d_i() {
    case $suite in
        buster|bullseye|oldoldstable|bookworm|oldstable|trixie|stable)
            daily_d_i=false
            ;;
        forky|testing|sid|unstable)
            daily_d_i=true
            ;;
        *)
            err "Unsupported suite: $suite"
    esac
}

set_suite() {
    suite=$1
    set_daily_d_i
    set_security_archive
}

# Maps version numbers and release aliases to actual suite names
# Accepts: version number (10-14), suite name (buster, bullseye, etc.), or alias (stable, testing, etc.)
# Current mapping:
# - 10/buster: No longer supported as oldoldstable (archived)
# - 11/bullseye/oldoldstable: LTS support
# - 12/bookworm/oldstable: Previous stable
# - 13/trixie/stable: Current stable release
# - 14/forky/testing: Next release in development
# - sid/unstable: Rolling development branch
set_debian_version() {
    case $1 in
        10|buster)
            set_suite buster
            ;;
        11|bullseye|oldoldstable)
            set_suite bullseye
            ;;
        12|bookworm|oldstable)
            set_suite bookworm
            ;;
        13|trixie|stable)
            set_suite trixie
            ;;
        14|forky|testing)
            set_suite forky
            ;;
        sid|unstable)
            set_suite sid
            ;;
        *)
            err "Unsupported version: $1"
    esac
}

# Checks if cloud-optimized kernels are available for the current architecture and suite
# Cloud kernels are minimal kernels optimized for cloud/virtual environments
# - Buster: Only amd64 has cloud kernel, arm64 requires backports
# - Bullseye onwards: Both amd64 and arm64 have cloud kernels
# - Other architectures (i386, etc.): No cloud kernels available
# Returns 0 if available, 1 if not
has_cloud_kernel() {
    case $suite in
        buster)
            [ "$architecture" = amd64 ] && return
            [ "$architecture" = arm64 ] && [ "$bpo_kernel" = true ] && return
            ;;
        bullseye|oldoldstable|bookworm|oldstable|trixie|stable|forky|testing|sid|unstable)
            [ "$architecture" = amd64 ] || [ "$architecture" = arm64 ] && return
    esac

    local tmp; tmp=''; [ "$bpo_kernel" = true ] && tmp='-backports'
    warn "No cloud kernel is available for $architecture/$suite$tmp"

    return 1
}

# Checks if backports repository is available for the current suite
# Backports provide newer versions of packages from testing/unstable rebuilt for stable releases
# - All stable releases and testing: Have backports available
# - Sid/unstable: No backports (already has the latest packages)
# Returns 0 if available, 1 if not
has_backports() {
    case $suite in
        bookworm|oldstable|trixie|stable|forky|testing) return
    esac

    # buster|bullseye|oldoldstable DO have backports, but it's in archive.debian.org now
    # considering mirrors support varies and the code complexity we must accommodate, we just treat them as no backports available

    warn "No backports kernel is available for $suite"

    return 1
}

interface=auto
ip=
netmask=
gateway=
dns='1.1.1.1 1.0.0.1'
dns6='2606:4700:4700::1111 2606:4700:4700::1001'
dns10='1.1.1.1 2606:4700:4700::1111'
hostname=
network_console=false
set_debian_version 13
mirror_protocol=https
mirror_host=deb.debian.org
mirror_directory=/debian
mirror_proxy=
security_repository=mirror
account_setup=true
username=debian
password=
authorized_keys_url=
sudo_with_password=false
timezone=UTC
ntp=time.google.com
disk_partitioning=true
disk="/dev/$(lsblk -no PKNAME "$(df /boot | grep -Eo '/dev/[a-z0-9]+')")"
force_gpt=true
efi=
esp=106
filesystem=ext4
kernel=
cloud_kernel=false
bpo_kernel=false
install_recommends=true
install=
upgrade=
kernel_params=
force_lowmem=
bbr=false
ssh_port=
hold=false
power_off=false
architecture=
firmware=false
hyperv_pci_hotfix=false
force_efi_extra_removable=true
grub_timeout=5
dry_run=false
apt_non_free_firmware=true
apt_non_free=false
apt_contrib=false
apt_src=true
apt_backports=true
cidata=

while [ $# -gt 0 ]; do
    case $1 in
        --cdn)
            ;;
        --aws)
            mirror_host=cdn-aws.deb.debian.org
            ntp=time.aws.com
            ;;
        --cloudflare)
            dns='1.1.1.1 1.0.0.1'
            dns6='2606:4700:4700::1111 2606:4700:4700::1001'
            ntp=time.cloudflare.com
            ;;
        --aliyun)
            dns='223.5.5.5 223.6.6.6'
            dns6='2400:3200::1 2400:3200:baba::1'
            mirror_host=mirrors.aliyun.com
            ntp=time.amazonaws.cn
            ;;
        --ustc|--china)
            dns='119.29.29.29'
            dns6='2402:4e00::'
            mirror_host=mirrors.ustc.edu.cn
            ntp=time.amazonaws.cn
            ;;
        --tuna)
            dns='119.29.29.29'
            dns6='2402:4e00::'
            mirror_host=mirrors.tuna.tsinghua.edu.cn
            ntp=time.amazonaws.cn
            ;;
        --static-ipv4)
            ip=$(ip r get 1.1.1.1 | awk '/src/ {print $7}')
            gateway=$(ip r get 1.1.1.1 | awk '/via/ {print $3}')
            _cidr=$(ip -o -f inet addr show | grep -w "$ip" | awk '{print $4}' | cut -d'/' -f2)
            ip="$ip/$_cidr"
            hostname=$(hostname)
            interface=$(ip r get 1.1.1.1 | awk '/dev/ {print $5}')
            ;;
        --interface)
            interface=$2
            shift
            ;;
        --ip)
            ip=$2
            shift
            ;;
        --netmask)
            netmask=$2
            shift
            ;;
        --gateway)
            gateway=$2
            shift
            ;;
        --dns)
            dns=$2
            shift
            ;;
        --dns6)
            dns6=$2
            shift
            ;;
        --hostname)
            hostname=$2
            shift
            ;;
        --network-console)
            network_console=true
            ;;
        --version)
            set_debian_version "$2"
            shift
            ;;
        --suite)
            set_suite "$2"
            shift
            ;;
        --release-d-i)
            daily_d_i=false
            ;;
        --daily-d-i)
            daily_d_i=true
            ;;
        --mirror-protocol)
            mirror_protocol=$2
            shift
            ;;
        --https)
            mirror_protocol=https
            ;;
        --mirror-host)
            mirror_host=$2
            shift
            ;;
        --mirror-directory)
            mirror_directory=${2%/}
            shift
            ;;
        --mirror-proxy|--proxy)
            mirror_proxy=$2
            shift
            ;;
        --reuse-proxy)
            set_mirror_proxy
            ;;
        --security-repository)
            security_repository=$2
            shift
            ;;
        --no-user|--no-account-setup)
            account_setup=false
            ;;
        --user|--username)
            username=$2
            shift
            ;;
        --password)
            password=$2
            shift
            ;;
        --authorized-keys-url)
            authorized_keys_url=$2
            shift
            ;;
        --sudo-with-password)
            sudo_with_password=true
            ;;
        --timezone)
            timezone=$2
            shift
            ;;
        --ntp)
            ntp=$2
            shift
            ;;
        --no-part|--no-disk-partitioning)
            disk_partitioning=false
            ;;
        --force-lowmem)
            [ "$2" != 0 ] && [ "$2" != 1 ] && [ "$2" != 2 ] && err 'Low memory level can only be 0, 1 or 2'
            force_lowmem=$2
            shift
            ;;
        --disk)
            disk=$2
            shift
            ;;
        --no-force-gpt)
            force_gpt=false
            ;;
        --bios)
            efi=false
            ;;
        --efi)
            efi=true
            ;;
        --esp)
            esp=$2
            shift
            ;;
        --filesystem)
            filesystem=$2
            shift
            ;;
        --kernel)
            kernel=$2
            shift
            ;;
        --cloud-kernel)
            cloud_kernel=true
            ;;
        --bpo-kernel)
            bpo_kernel=true
            ;;
        --apt-non-free-firmware)
            apt_non_free_firmware=true
            ;;
        --apt-non-free)
            apt_non_free=true
            apt_contrib=true
            ;;
        --apt-contrib)
            apt_contrib=true
            ;;
        --apt-src)
            apt_src=true
            ;;
        --apt-backports)
            apt_backports=true
            ;;
        --no-apt-non-free-firmware)
            apt_non_free_firmware=false
            ;;
        --no-apt-non-free)
            apt_non_free=false
            ;;
        --no-apt-contrib)
            apt_contrib=false
            apt_non_free=false
            ;;
        --no-apt-src)
            apt_src=false
            ;;
        --no-apt-backports)
            apt_backports=false
            ;;
        --no-install-recommends)
            install_recommends=false
            ;;
        --install)
            install=$2
            shift
            ;;
        --no-upgrade)
            upgrade=none
            ;;
        --safe-upgrade)
            upgrade=safe-upgrade
            ;;
        --full-upgrade)
            upgrade=full-upgrade
            ;;
        --ethx)
            kernel_params="$kernel_params net.ifnames=0 biosdevname=0"
            ;;
        --bbr)
            bbr=true
            ;;
        --ssh-port)
            ssh_port=$2
            shift
            ;;
        --hold)
            hold=true
            ;;
        --power-off)
            power_off=true
            ;;
        --architecture)
            architecture=$2
            shift
            ;;
        --firmware)
            firmware=true
            ;;
        --hyperv-pci-hotfix)
            hyperv_pci_hotfix=true
            ;;
        --no-force-efi-extra-removable)
            force_efi_extra_removable=false
            ;;
        --grub-timeout)
            grub_timeout=$2
            shift
            ;;
        --dry-run)
            dry_run=true
            ;;
        --cidata)
            cidata=$(realpath "$2")
            [ ! -f "$cidata/meta-data" ] && err 'No "meta-data" file found in the cloud-init directory'
            [ ! -f "$cidata/user-data" ] && err 'No "user-data" file found in the cloud-init directory'
            shift
            ;;
        *)
            err "Unknown option: \"$1\""
    esac
    shift
done

[ -z "$architecture" ] && {
    architecture=$(dpkg --print-architecture 2> /dev/null) || {
        case $(uname -m) in
            x86_64)
                architecture=amd64
                ;;
            aarch64)
                architecture=arm64
                ;;
            i386)
                architecture=i386
                ;;
            *)
                err 'No "--architecture" specified'
        esac
    }
}

[ -z "$kernel" ] && {
    kernel="linux-image-$architecture"

    [ "$cloud_kernel" = true ] && has_cloud_kernel && kernel="linux-image-cloud-$architecture"
    [ "$bpo_kernel" = true ] && has_backports && install="$kernel/$suite-backports $install"
}

[ -n "$authorized_keys_url" ] && ! download "$authorized_keys_url" /dev/null &&
err "Failed to download SSH authorized public keys from \"$authorized_keys_url\""

# Determines if the non-free-firmware repository component is available
# Starting from Debian 12 (Bookworm), firmware was split into a separate component
# to make it easier to include necessary firmware while keeping main free
# - Bookworm onwards: non-free-firmware component available
# - Bullseye and earlier: Firmware is in non-free component
non_free_firmware_available=false
case $suite in
    bookworm|oldstable|trixie|stable|forky|testing|sid|unstable)
        non_free_firmware_available=true
        ;;
    *)
        apt_non_free_firmware=false
esac

apt_components=main
[ "$apt_contrib" = true ] && apt_components="$apt_components contrib"
[ "$apt_non_free" = true ] && apt_components="$apt_components non-free"
[ "$apt_non_free_firmware" = true ] && apt_components="$apt_components non-free-firmware"

apt_services=updates
[ "$apt_backports" = true ] && has_backports && apt_services="$apt_services, backports"

installer_directory="/boot/debian-$suite"

save_preseed='cat'
[ "$dry_run" = false ] && {
    [ "$(id -u)" -ne 0 ] && err 'root privilege is required'
    rm -rf "$installer_directory"
    mkdir -p "$installer_directory"
    cd "$installer_directory"
    save_preseed='tee -a preseed.cfg'
}

if [ "$account_setup" = true ]; then
    prompt_password
elif [ "$network_console" = true ] && [ -z "$authorized_keys_url" ]; then
    prompt_password "Choose a password for the installer user of the SSH network console: "
fi

$save_preseed << EOF
# Localization

d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network configuration

d-i netcfg/choose_interface select $interface
EOF

[ -n "$ip" ] && {
    echo 'd-i netcfg/disable_autoconfig boolean true' | $save_preseed
    echo "d-i netcfg/get_ipaddress string $ip" | $save_preseed
    [ -n "$netmask" ] && echo "d-i netcfg/get_netmask string $netmask" | $save_preseed
    [ -n "$gateway" ] && echo "d-i netcfg/get_gateway string $gateway" | $save_preseed
    [ -z "${ip%%*:*}" ] && [ -n "${dns%%*:*}" ] && dns="$dns6"
    [ -n "$dns" ] && echo "d-i netcfg/get_nameservers string $dns" | $save_preseed
    echo 'd-i netcfg/confirm_static boolean true' | $save_preseed
}

[ -z "$ip" ] && {
    echo "d-i netcfg/get_nameservers string $dns10" | $save_preseed
}

if [ -n "$hostname" ]; then
    echo "d-i netcfg/hostname string $hostname" | $save_preseed
    hostname=debian
    domain=
else
    hostname=$(cat /proc/sys/kernel/hostname)
    domain=$(cat /proc/sys/kernel/domainname)
    if [ "$domain" = '(none)' ]; then
        domain=
    else
        domain=" $domain"
    fi
fi

$save_preseed << EOF
d-i netcfg/get_hostname string $hostname
d-i netcfg/get_domain string$domain
EOF

echo 'd-i hw-detect/load_firmware boolean true' | $save_preseed

[ "$network_console" = true ] && {
    $save_preseed << 'EOF'

# Network console

d-i anna/choose_modules string network-console
d-i preseed/early_command string anna-install network-console
EOF
    if [ -n "$authorized_keys_url" ]; then
        echo "d-i network-console/authorized_keys_url string $authorized_keys_url" | $save_preseed
    else
        $save_preseed << EOF
d-i network-console/password password $password
d-i network-console/password-again password $password
EOF
    fi

    echo 'd-i network-console/start select Continue' | $save_preseed
}

$save_preseed << EOF

# Mirror settings

d-i mirror/country string manual
d-i mirror/protocol string $mirror_protocol
d-i mirror/$mirror_protocol/hostname string $mirror_host
d-i mirror/$mirror_protocol/directory string $mirror_directory
d-i mirror/$mirror_protocol/proxy string $mirror_proxy
d-i mirror/suite string $suite
EOF

[ "$account_setup" = true ] && {
    password_hash=$(mkpasswd -m sha-256 "$password" 2> /dev/null) ||
    password_hash=$(openssl passwd -5 "$password" 2> /dev/null) ||
    password_hash=$(busybox mkpasswd -m sha256 "$password" 2> /dev/null) || {
        for python in python3 python python2; do
            password_hash=$("$python" -c 'import crypt, sys; print(crypt.crypt(sys.argv[1], crypt.mksalt(crypt.METHOD_SHA256)))' "$password" 2> /dev/null) && break
        done
    }

    $save_preseed << 'EOF'

# Account setup

EOF
    [ -n "$authorized_keys_url" ] && configure_sshd PasswordAuthentication no

    if [ "$username" = root ]; then
        if [ -z "$authorized_keys_url" ]; then
            configure_sshd PermitRootLogin yes
        else
            in_target "mkdir -m 0700 -p ~root/.ssh && busybox wget -O- \"$authorized_keys_url\" >> ~root/.ssh/authorized_keys"
        fi

        $save_preseed << 'EOF'
d-i passwd/root-login boolean true
d-i passwd/make-user boolean false
EOF

        if [ -z "$password_hash" ]; then
            $save_preseed << EOF
d-i passwd/root-password password $password
d-i passwd/root-password-again password $password
EOF
        else
            echo "d-i passwd/root-password-crypted password $password_hash" | $save_preseed
        fi
    else
        configure_sshd PermitRootLogin no

        [ -n "$authorized_keys_url" ] &&
        in_target "sudo -u $username mkdir -m 0700 -p ~$username/.ssh && busybox wget -O - \"$authorized_keys_url\" | sudo -u $username tee -a ~$username/.ssh/authorized_keys"

        [ "$sudo_with_password" = false ] &&
        in_target "echo \"$username ALL=(ALL:ALL) NOPASSWD:ALL\" > \"/etc/sudoers.d/90-user-$username\""

        $save_preseed << EOF
d-i passwd/root-login boolean false
d-i passwd/make-user boolean true
d-i passwd/user-fullname string
d-i passwd/username string $username
EOF

        if [ -z "$password_hash" ]; then
            $save_preseed << EOF
d-i passwd/user-password password $password
d-i passwd/user-password-again password $password
EOF
        else
            echo "d-i passwd/user-password-crypted password $password_hash" | $save_preseed
        fi
    fi
}

[ -n "$ssh_port" ] && configure_sshd Port "$ssh_port"

$save_preseed << EOF

# Clock and time zone setup

d-i time/zone string $timezone
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string $ntp

# Partitioning

EOF

[ "$disk_partitioning" = true ] && {
    $save_preseed << 'EOF'
d-i partman-auto/method string regular
EOF
    if [ -n "$disk" ]; then
        echo "d-i partman-auto/disk string $disk" | $save_preseed
    else
        # shellcheck disable=SC2016
        echo 'd-i partman/early_command string debconf-set partman-auto/disk "$(list-devices disk | head -n 1)"' | $save_preseed
    fi
}

[ "$force_gpt" = true ] && {
    $save_preseed << 'EOF'
d-i partman-partitioning/choose_label string gpt
d-i partman-partitioning/default_label string gpt
EOF
}

[ "$disk_partitioning" = true ] && {
    echo "d-i partman/default_filesystem string $filesystem" | $save_preseed

    [ -z "$efi" ] && {
        efi=false
        [ -d /sys/firmware/efi ] && efi=true
    }

    $save_preseed << 'EOF'
d-i partman-auto/expert_recipe string \
    naive :: \
EOF
    if [ "$efi" = true ]; then
        $save_preseed << EOF
        $esp $esp $esp free \\
EOF
        $save_preseed << 'EOF'
            $iflabel{ gpt } \
            $reusemethod{ } \
            method{ efi } \
            format{ } \
        . \
EOF
    else
        $save_preseed << 'EOF'
        1 1 1 free \
            $iflabel{ gpt } \
            $reusemethod{ } \
            method{ biosgrub } \
        . \
EOF
    fi

    $save_preseed << 'EOF'
        1075 1076 -1 $default_filesystem \
            method{ format } \
            format{ } \
            use_filesystem{ } \
            $default_filesystem{ } \
            mountpoint{ / } \
        .
EOF
    if [ "$efi" = true ]; then
        echo 'd-i partman-efi/non_efi_system boolean true' | $save_preseed
    fi

    $save_preseed << 'EOF'
d-i partman-auto/choose_recipe select naive
d-i partman-basicfilesystems/no_swap boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-lvm/device_remove_lvm boolean true
EOF
}

$save_preseed << EOF

# Base system installation

d-i base-installer/kernel/image string $kernel
EOF

[ "$install_recommends" = false ] && echo "d-i base-installer/install-recommends boolean $install_recommends" | $save_preseed

[ "$security_repository" = mirror ] && security_repository=$mirror_protocol://$mirror_host${mirror_directory%/*}/debian-security

$save_preseed << EOF

# Apt setup

d-i apt-setup/contrib boolean $apt_contrib
d-i apt-setup/non-free boolean $apt_non_free
d-i apt-setup/enable-source-repositories boolean $apt_src
d-i apt-setup/services-select multiselect $apt_services
EOF

[ "$non_free_firmware_available" = true ] && echo "d-i apt-setup/non-free-firmware boolean $apt_non_free_firmware" | $save_preseed

# If not sid/unstable
[ -n "$security_archive" ] && {
    $save_preseed << EOF
d-i apt-setup/local0/repository string $security_repository $security_archive $apt_components
d-i apt-setup/local0/source boolean $apt_src
EOF
}

$save_preseed << 'EOF'

# Package selection

tasksel tasksel/first multiselect ssh-server
EOF

install="$install ca-certificates libpam-systemd"
[ -n "$cidata" ] && install="$install cloud-init"

[ -n "$install" ] && echo "d-i pkgsel/include string $install" | $save_preseed
[ -n "$upgrade" ] && echo "d-i pkgsel/upgrade select $upgrade" | $save_preseed

$save_preseed << 'EOF'
popularity-contest popularity-contest/participate boolean false

# Boot loader installation

EOF

if [ -n "$disk" ]; then
    echo "d-i grub-installer/bootdev string $disk" | $save_preseed
else
    echo 'd-i grub-installer/bootdev string default' | $save_preseed
fi

[ "$force_efi_extra_removable" = true ] && echo 'd-i grub-installer/force-efi-extra-removable boolean true' | $save_preseed
[ -n "$kernel_params" ] && echo "d-i debian-installer/add-kernel-opts string$kernel_params" | $save_preseed

$save_preseed << 'EOF'

# Finishing up the installation

EOF

[ "$hold" = false ] && echo 'd-i finish-install/reboot_in_progress note' | $save_preseed

[ "$bbr" = true ] && in_target '{ echo "net.core.default_qdisc=fq"; echo "net.ipv4.tcp_congestion_control=bbr"; } > /etc/sysctl.d/bbr.conf'

[ -n "$cidata" ] && {
    in_target 'echo "datasource_list: [ NoCloud ]" > /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "datasource:" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "  ConfigDrive:" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "    dsmode: disabled" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "  NoCloud:" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "    fs_label: ~" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
    in_target 'echo "    dsmode: local" >> /etc/cloud/cloud.cfg.d/91_set_datasource.cfg'
}

late_command='true'
[ -n "$in_target_script" ] && late_command="$late_command; in-target sh -c '$in_target_script'"
[ -n "$cidata" ] && late_command="$late_command; mkdir -p /target/var/lib/cloud/seed/nocloud; cp -r /cidata/. /target/var/lib/cloud/seed/nocloud/"

echo "d-i preseed/late_command string $late_command" | $save_preseed

[ "$power_off" = true ] && echo 'd-i debian-installer/exit/poweroff boolean true' | $save_preseed

save_grub_cfg='cat'
[ "$dry_run" = false ] && {
    base_url="$mirror_protocol://$mirror_host$mirror_directory/dists/$suite/main/installer-$architecture/current/images/netboot/debian-installer/$architecture"
    [ "$suite" = stretch ] && [ "$efi" = true ] && base_url="$mirror_protocol://$mirror_host$mirror_directory/dists/buster/main/installer-$architecture/current/images/netboot/debian-installer/$architecture"
    [ "$daily_d_i" = true ] && base_url="https://d-i.debian.org/daily-images/$architecture/daily/netboot/debian-installer/$architecture"
    firmware_url="https://cdimage.debian.org/cdimage/unofficial/non-free/firmware/$suite/current/firmware.cpio.gz"

    download "$base_url/linux" linux
    download "$base_url/initrd.gz" initrd.gz
    [ "$firmware" = true ] && download "$firmware_url" firmware.cpio.gz

    gzip -d initrd.gz
    [ "$hyperv_pci_hotfix" = true ] && inject_hyperv_pci_hotfix "$PWD/initrd"
    # cpio reads a list of file names from the standard input
    echo preseed.cfg | cpio -o -H newc -A -F initrd

    if [ -n "$cidata" ]; then
        cp -r "$cidata" cidata
        find cidata | cpio -o -H newc -A -F initrd
    fi

    gzip -1 initrd

    mkdir -p /etc/default/grub.d
    tee /etc/default/grub.d/zz-debi.cfg 1>&2 << EOF
GRUB_DEFAULT=debi
GRUB_TIMEOUT=$grub_timeout
GRUB_TIMEOUT_STYLE=menu
EOF

    if command_exists update-grub; then
        grub_cfg=/boot/grub/grub.cfg
        update-grub
    elif command_exists grub2-mkconfig; then
        tmp=$(mktemp)
        grep -vF zz_debi /etc/default/grub > "$tmp"
        cat "$tmp" > /etc/default/grub
        rm "$tmp"
        # shellcheck disable=SC2016
        echo 'zz_debi=/etc/default/grub.d/zz-debi.cfg; if [ -f "$zz_debi" ]; then . "$zz_debi"; fi' >> /etc/default/grub
        grub_cfg=/boot/grub2/grub.cfg
        [ -d /sys/firmware/efi ] && grub_cfg=/boot/efi/EFI/*/grub.cfg
        grub2-mkconfig -o "$grub_cfg"
    elif command_exists grub-mkconfig; then
        tmp=$(mktemp)
        grep -vF zz_debi /etc/default/grub > "$tmp"
        cat "$tmp" > /etc/default/grub
        rm "$tmp"
        # shellcheck disable=SC2016
        echo 'zz_debi=/etc/default/grub.d/zz-debi.cfg; if [ -f "$zz_debi" ]; then . "$zz_debi"; fi' >> /etc/default/grub
        grub_cfg=/boot/grub/grub.cfg
        grub-mkconfig -o "$grub_cfg"
    else
        err 'Could not find "update-grub" or "grub2-mkconfig" or "grub-mkconfig" command'
    fi

    save_grub_cfg="tee -a $grub_cfg"
}

mkrelpath=$installer_directory
[ "$dry_run" = true ] && mkrelpath=/boot
installer_directory=$(grub-mkrelpath "$mkrelpath" 2> /dev/null) ||
installer_directory=$(grub2-mkrelpath "$mkrelpath" 2> /dev/null) || {
    err 'Could not find "grub-mkrelpath" or "grub2-mkrelpath" command'
}
[ "$dry_run" = true ] && installer_directory="$installer_directory/debian-$suite"

kernel_params="$kernel_params lowmem/low=1"

[ -n "$force_lowmem" ] && kernel_params="$kernel_params lowmem=+$force_lowmem"

initrd="$installer_directory/initrd.gz"
[ "$firmware" = true ] && initrd="$initrd $installer_directory/firmware.cpio.gz"

$save_grub_cfg 1>&2 << EOF
menuentry 'Debian Installer' --id debi {
    insmod part_msdos
    insmod part_gpt
    insmod ext2
    insmod xfs
    insmod btrfs
    linux $installer_directory/linux$kernel_params
    initrd $initrd
}
EOF
