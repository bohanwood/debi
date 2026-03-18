<div lang="ja-JP">

# Debian Network Reinstall Script

## このスクリプトについて

これは、あらゆるVPSや物理マシンを、ネットワークブート経由で最小構成のDebianに再インストールするためのスクリプトです。GRUBにDebianインストーラーを組み込み、インストールプロセスを自動的に設定することで動作します。

**主な用途:**
- Oracle CloudのUbuntuイメージをDebianに変換
- クラウドプロバイダーの監視エージェントの削除
- クリーンで最小限のDebian環境の構築
- Preseedやcloud-initを使用したインストールの自動化
- 破損したシステムのレスキュー

## クイックスタート

```bash
# スクリプトをダウンロード
curl -fLO [https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh](https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh)
chmod +x debi.sh

# 基本的なインストール（sudo権限を持つ 'debian' ユーザーを作成）
sudo ./debi.sh

# もしくは、rootユーザーとしてインストール
sudo ./debi.sh --user root

# 準備ができたら再起動
sudo reboot
````

**デフォルト設定:** Debian 13 (trixie)、DHCPによるネットワーク設定、sudo権限を持つ`debian`ユーザーが作成され、パスワードの入力を求められます。

## プラットフォームサポート

| プラットフォーム | ステータス | 備考 |
|---|---|---|
| ✅ **KVM/物理マシン** | フルサポート | 全ての機能が動作します |
| ✅ **ほとんどのVPS** | フルサポート | DigitalOcean, Vultr, Linodeなど |
| ⚠️ **Google Cloud** | 手動でのネットワーク設定が必要 | DHCPが機能しないため`--ip`, `--gateway`が必須 |
| ⚠️ **AWS EC2** | BIOSのみ | UEFIブートはまだサポートされていません |
| ❌ **コンテナ** | サポート対象外 | GRUBブートローダーが必要です |

**要件:**

  - KVMまたは物理マシン（コンテナは不可）
  - GRUB 2 ブートローダー
  - rootアクセス権限

## 地域別プリセット

| プリセット | ミラー | DNS | NTP | 最適な環境 |
|---|---|---|---|---|
| *Default* | deb.debian.org | Google DNS | time.google.com | グローバル |
| `--cloudflare` | deb.debian.org | Cloudflare | time.cloudflare.com | グローバル (プライバシー重視) |
| `--aws` | cdn-aws.deb.debian.org | Google DNS | time.aws.com | AWSインスタンス |
| `--aliyun` | mirrors.aliyun.com | AliDNS | time.amazonaws.cn | 中国 |
| `--ustc` | mirrors.ustc.edu.cn | DNSPod | time.amazonaws.cn | 中国 |
| `--tuna` | mirrors.tuna.tsinghua.edu.cn | DNSPod | time.amazonaws.cn | 中国 |

## 全オプションリファレンス

### システムとユーザー設定

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--version 13` | `13` | Debianのバージョン: `10`, `11`, `12`, `13`, `14` |
| `--suite trixie` | `trixie` | Debianのスイート: `stable`, `testing`, `sid` など |
| `--user debian` | `debian` | ユーザー名 (`root`を指定するとrootユーザーのみ) |
| `--password PASSWORD` | *プロンプト* | ユーザーのパスワード（指定しない場合はプロンプト表示） |
| `--authorized-keys-url URL` | *パスワード認証* | URLからSSH公開鍵を設定 (例: `https://github.com/user.keys`) |
| `--no-account-setup` | *ユーザー作成* | ユーザー作成をスキップ（コンソールでの手動設定が必要） |
| `--sudo-with-password` | *パスワード不要* | sudoコマンド実行時にパスワードを要求する |
| `--timezone UTC` | `UTC` | システムのタイムゾーン (例: `Asia/Tokyo`) |
| `--hostname NAME` | *現在の値* | システムのホスト名 |

### ネットワーク設定

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--interface auto` | `auto` | ネットワークインターフェース (例: `eth0`, `eth1`) |
| `--ip ADDRESS` | *DHCP* | 静的IP: `10.0.0.100`, `1.2.3.4/24`, `2001:db8::1/64` |
| `--static-ipv4` | *DHCP* | 現在のIPv4設定を自動的に使用 |
| `--netmask MASK` | *auto* | ネットマスク: `255.255.255.0`, `ffff:ffff:ffff:ffff::` |
| `--gateway ADDRESS` | *auto* | ゲートウェイIP (`none`でゲートウェイなし) |
| `--dns '8.8.8.8 8.8.4.4'` | `1.1.1.1 1.0.0.1` | IPv4用のDNSサーバー |
| `--dns6 '2001:4860:4860::8888'` | `2606:4700:4700::1111` | IPv6用のDNSサーバー |
| `--ethx` | *予測可能な名前* | `enp0s3`形式の代わりに`eth0`/`eth1`を使用 |
| `--ntp time.google.com` | `time.google.com` | NTPサーバー |

### ネットワークコンソール（リモートインストール）

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--network-console` | *無効* | インストール中にSSHアクセスを有効化 |

**ネットワークコンソールの使い方:**

1.  `--network-console` を付けて有効化し、再起動します
2.  Debianインストーラーがコンポーネントをロードするまで2〜3分待ちます
3.  サーバーにSSH接続します: `ssh installer@YOUR_IP`
4.  複数のターミナルを利用できます:
      - **Alt+F1**: メインのインストーラー画面
      - **Alt+F2**: シェルアクセス
      - **Alt+F3**: 追加のシェル
      - **Alt+F4**: システムログ（自動インストールの進捗を監視）
      - Alt+Left/Alt+Rightで画面を切り替え

**⚠️ 注意事項**

`--authorized-keys-url` を使用した場合、SSHのパスワード認証は無効になります（SSHキーが必須）。**ただし、ユーザーパスワードの設定が必要です（VNCコンソールやsudoでのアクセスのため）。**

### ストレージとパーティショニング

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--disk /dev/sda` | *自動検出* | 対象ディスク（複数ディスクがある場合は**必須**） |
| `--no-disk-partitioning` | *自動パーティション* | コンソールで手動パーティショニングを行う |
| `--filesystem ext4` | `ext4` | ルートファイルシステムのタイプ |
| `--force-gpt` | *有効* | GPTパーティションテーブルを作成 |
| `--no-force-gpt` | *GPTを使用* | 代わりにMBRパーティションテーブルを使用 |
| `--bios` | *自動検出* | BIOSブートを強制（BIOSブートパーティションを作成） |
| `--efi` | *自動検出* | EFIブートを強制（EFIシステムパーティションを作成） |
| `--esp 106` | `106` | EFIシステムパーティションのサイズ (106=100MB, 538=512MB, 1075=1GB) |

### ミラーとリポジトリの設定

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--mirror-protocol https` | `https` | ミラーのプロトコル: `http`, `https`, `ftp` |
| `--https` | *有効* | `--mirror-protocol https` のエイリアス |
| `--mirror-host deb.debian.org` | `deb.debian.org` | ミラーのホスト名 |
| `--mirror-directory /debian` | `/debian` | ミラーのディレクトリパス |
| `--mirror-proxy URL` | *なし* | ダウンロードとAPT用のHTTPプロキシ |
| `--reuse-proxy` | *なし* | 既存の`http_proxy`環境変数を使用 |
| `--security-repository URL` | *auto* | セキュリティアップデート用リポジトリ (`mirror`でメインミラーを使用) |

### APTリポジトリコンポーネント

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--apt-non-free-firmware` | *有効* | non-free-firmwareを含める (Debian 12以降) |
| `--apt-non-free` | *無効* | non-freeリポジトリを有効化 |
| `--apt-contrib` | *無効* | contribリポジトリを有効化 |
| `--apt-src` | *有効* | ソースリポジトリを有効化 |
| `--apt-backports` | *有効* | backportsリポジトリを有効化 |
| `--no-apt-non-free-firmware` | *デフォルトを使用* | non-free-firmwareを無効化 |
| `--no-apt-non-free` | *デフォルトを使用* | non-freeを無効化 |
| `--no-apt-contrib` | *デフォルトを使用* | contribを無効化 |
| `--no-apt-src` | *デフォルトを使用* | ソースリポジトリを無効化 |
| `--no-apt-backports` | *デフォルトを使用* | backportsを無効化 |

### パッケージインストール

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--install 'pkg1 pkg2'` | *最小構成* | 追加パッケージ（スペース区切り、引用符で囲む） |
| `--install-recommends` | *有効* | 推奨パッケージをインストール |
| `--no-install-recommends` | *推奨をインストール* | 推奨パッケージをスキップ |
| `--upgrade safe-upgrade` | `safe-upgrade` | パッケージのアップグレードモード |
| `--safe-upgrade` | *デフォルト* | インストール中に安全なパッケージアップグレードを実行 |
| `--full-upgrade` | *safe upgrade* | フルシステムアップグレード (`dist-upgrade`) |
| `--no-upgrade` | *safe upgrade* | パッケージのアップグレードを完全にスキップ |

### カーネルオプション

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--kernel PACKAGE` | `linux-image-ARCH` | カーネルパッケージ名 |
| `--cloud-kernel` | *標準* | クラウド最適化カーネルを使用 |
| `--bpo-kernel` | *stable* | backportsから新しいカーネルを使用 |
| `--firmware` | *自動検出* | ハードウェア用のnon-freeファームウェアを含める |
| `--hyperv-pci-hotfix` | *無効* | インストーラー内核に一致する Debian kernel パッケージをダウンロードして initrd に組み込み、インストーラー起動初期に `pci-hyperv.ko` を読み込む（Azure NVMe / Hyper-V vPCI のディスク検出向け） |

### 詳細オプション

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--ssh-port 2222` | `22` | カスタムSSHポート |
| `--bbr` | *無効* | TCP BBR輻輳制御アルゴリズムを有効化 |
| `--architecture amd64` | *自動検出* | 対象アーキテクチャ: `amd64`, `arm64`, `i386` など |
| `--force-lowmem 1` | *auto* | 低メモリモードを強制: `0`, `1`, `2` (512MB未満のRAM用) |
| `--no-force-efi-extra-removable` | *有効* | EFIの追加リムーバブルメディアパスを無効化 |
| `--grub-timeout 5` | `5` | GRUBメニューのタイムアウト秒数 |

### Debianインストーラーオプション

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--release-d-i` | *auto* | リリース版のdebian-installerを使用 |
| `--daily-d-i` | *auto* | デイリービルド版のdebian-installerを使用 |

### Cloud-Init連携

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--cidata /path/to/dir` | *なし* | カスタムcloud-initデータディレクトリ |

**Cloud-Initの使い方:**

```bash
# cloud-init設定を作成
mkdir my-cloud-config
echo "instance-id: my-server" > my-cloud-config/meta-data
cat > my-cloud-config/user-data << 'EOF'
#cloud-config
hostname: my-server
packages:
  - htop
  - git
EOF

# インストール時に使用
sudo ./debi.sh --cidata my-cloud-config
```

### 開発とテスト

| オプション | デフォルト値 | 説明 |
|---|---|---|
| `--dry-run` | *実行* | インストールは行わず、設定ファイルのみ生成 |
| `--hold` | *再起動* | インストール後に再起動しない |
| `--power-off` | *再起動* | 再起動の代わりに電源をオフにする |

## 使用例

### Oracle Cloud (Ubuntu → Debian)

```bash
sudo ./debi.sh --cloudflare --user debian
```

### Google Cloud Platform

```bash
# GCPでは手動でのネットワーク設定が必要（お使いのVPC設定に置き換えてください）
sudo ./debi.sh --ip 10.128.0.100/24 --gateway 10.128.0.1
```

### 最小構成でのインストール

```bash
sudo ./debi.sh --no-install-recommends --install 'curl git vim' --no-upgrade
```

### 中国向けデプロイ

```bash
sudo ./debi.sh --ustc --timezone Asia/Shanghai --dns '119.29.29.29'
```

### ネットワークコンソールでのインストール

```bash
# インストール中にリモートアクセスを有効化（ネットワーク接続はSSHキー、VNC/sudoはパスワードが引き続き必要）
sudo ./debi.sh --network-console --authorized-keys-url [https://github.com/yourusername.keys](https://github.com/yourusername.keys)
# 再起動後、SSH接続: ssh installer@YOUR_IP
```

### 静的IPとCloud-Initを使用

```bash
sudo ./debi.sh --ip 192.168.1.100/24 --gateway 192.168.1.1 --cidata ./cloud-config/
```

### 高度なカスタム設定

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

## トラブルシューティング

### 全ての変更を元に戻す

```bash
# 全ての変更を削除し、元のGRUB設定を復元
sudo rm -rf /etc/default/grub.d/zz-debi.cfg /boot/debian-*
sudo update-grub || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### よくある問題

**複数のディスクが検出された場合:**

```bash
# 利用可能なディスクをリスト表示
lsblk
# 対象ディスクを指定
sudo ./debi.sh --disk /dev/sda
```

**低メモリのVPS (\<512MB) の場合:**

```bash
sudo ./debi.sh --force-lowmem 1
```

**ネットワーク設定に失敗する場合:**

```bash
# 現在のネットワーク設定を使用
sudo ./debi.sh --static-ipv4

# または手動で設定
sudo ./debi.sh --ip YOUR_IP/CIDR --gateway YOUR_GATEWAY
```

**ネットワークカードにファームウェアが必要な場合:**

```bash
sudo ./debi.sh --firmware
```

**インストーラーで Azure NVMe ディスクを検出できない場合（Hyper-V vPCI）:**

```bash
sudo ./debi.sh --hyperv-pci-hotfix
```

**インストールのデバッグ:**

```bash
# preseedファイルのみを生成
sudo ./debi.sh --dry-run

# リモートアクセス用にネットワークコンソールを有効化（リモートはSSHキー、VNC/sudoはパスワードが必要）
sudo ./debi.sh --network-console --authorized-keys-url YOUR_KEYS_URL
```

## 動作の仕組み

1.  **Debianインストーラーをダウンロード**し、`/boot/debian-$VERSION/`に配置します
2.  指定された設定で**preseedファイルを生成**します
3.  **GRUBの設定を変更**し、インストーラーのメニューエントリを追加します
4.  インストーラーのinitramfsに**設定を注入**します
5.  **GRUBを更新**し、新しいブートオプションを反映させます

**システムに加えられる変更:**

  - `/boot/debian-*/` にファイルが追加されます
  - `/etc/default/grub.d/zz-debi.cfg` にGRUB設定が追加されます
  - GRUBメニューが更新されます

**これらの変更は安全であり、再起動前であれば上記の「元に戻す」コマンドで取り消すことが可能です。**

-----

*Created by [@bohanyang](https://github.com/bohanyang) • [Issues](https://github.com/bohanyang/debi/issues) • [GitHub](https://github.com/bohanyang/debi)*

</div>
