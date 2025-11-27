# GitHub Actions Workflow for Testing debi.sh

## Overview

This workflow tests the Debian Network Reinstall Script (`debi.sh`) using KVM virtualization in GitHub Actions. It validates that the script correctly prepares a system for Debian installation, performs the actual installation, and verifies the newly installed system.

## Test Matrix

The workflow uses a semantic matrix strategy to test ~15 different configurations across:

- **Debian Versions**: 10 (Buster), 11 (Bullseye), 12 (Bookworm)
- **Mirrors**: Default, USTC (China), Cloudflare
- **Network Interface Naming**: Standard (`ethx`) or predictable names
- **User Account**: `root` or `debian`
- **Network Console**: Always enabled for remote installation monitoring

**Key combinations tested:**
- Debian 10 with default mirror (baseline)
- Debian 11 with all mirrors and both naming schemes
- Debian 12 with all mirrors and various user configurations

**Base Image**: All tests use Debian 11 (Bullseye) cloud image as the starting point, regardless of target version.

## How It Works

### 1. Environment Setup
- Enables KVM support on GitHub Actions runner
- Caches APT packages for faster subsequent runs
- Installs QEMU and related tools (qemu-kvm, cloud-utils, sshpass, etc.)

### 2. Base Image Caching
- Downloads Debian 11 cloud image (only once, then cached)
- Reuses cached image across all matrix jobs
- Significantly speeds up workflow execution

### 3. VM Preparation
- Creates a copy-on-write disk image from the cached base image
- Generates cloud-init configuration for initial VM setup
- Configures root SSH access with password `rootpass123`

### 4. VM Execution
- Starts QEMU VM with KVM acceleration
- Waits for SSH to become available
- Uploads `debi.sh` script to the VM

### 5. Script Testing
- **Builds arguments dynamically** from matrix parameters:
  - `--version` from `matrix.version`
  - `--ustc` or `--cloudflare` from `matrix.mirror`
  - `--ethx` from `matrix.ethx`
  - `--network-console` (always enabled)
  - `--user` and `--password` from `matrix.user`
- Executes `debi.sh` with built arguments
- Captures output for debugging

### 6. Installation Validation
The workflow validates that the script:
- Successfully downloads Debian installer components to `/boot/debian-*/`
- Creates the required `linux` and `initrd.gz` files
- Updates GRUB configuration with Debian Installer entry
- Sets GRUB default to boot into the installer

### 7. Full Installation Test
After validation, the workflow:
- Reboots the VM to start the Debian installer
- Waits for the installation to complete (up to 30 minutes)
- Polls for SSH availability with the **new password** (`newpass123`)
- Verifies the newly installed system

### 7. Success Criteria

A test passes if:
- ✓ Script executes without critical errors
- ✓ Installer files exist in `/boot/debian-*/`
- ✓ GRUB configuration contains "Debian Installer" entry
- ✓ VM successfully reboots into installer
- ✓ Installation completes automatically
- ✓ New system boots and is accessible via SSH with new credentials

## Running the Tests

### Automatic Execution
Tests run automatically on:
- Push to `master` or `main` branch
- Pull requests targeting `master` or `main`

### Manual Execution
You can manually trigger the workflow:
1. Go to Actions tab in GitHub
2. Select "Test Debian Installation Script"
3. Click "Run workflow"

## Test Artifacts

Each test run uploads:
- `debi-output.log` - Complete output from script execution
- `serial.log` - VM serial console log

Access artifacts from the workflow run summary page.

## Interpreting Results

### ✅ Success
- All validation checks pass
- New system is accessible with new credentials
- Green checkmark in GitHub Actions UI

### ❌ Failure
Common failure scenarios and debugging:

1. **SSH connection timeout (old credentials)**
   - Check serial console log
   - Verify cloud-init configuration

2. **Installer files not downloaded**
   - Review debi-output.log
   - Check network connectivity
   - Verify mirror availability

3. **GRUB update failed**
   - Check for GRUB installation issues
   - Verify disk partitioning

4. **Installation timeout**
   - Installation may take longer than expected
   - Check serial console for installer progress
   - Verify network connectivity to mirrors

5. **Cannot connect with new credentials**
   - Installation may have failed
   - Check serial console for installation errors
   - Verify preseed configuration

## Password Strategy

The workflow uses two different passwords to verify installation success:

| Phase | User | Password | Purpose |
|-------|------|----------|---------|
| Initial VM (cloud-init) | root | `rootpass123` | Access the base system to run debi.sh |
| New System (installed) | root/debian | `newpass123` | Verify the new system was installed |

If SSH connects with `newpass123`, it proves the new Debian system was installed successfully.

## Limitations

This workflow tests the complete installation process:
- ✓ Script argument parsing
- ✓ Installer file downloads
- ✓ GRUB configuration updates
- ✓ Reboot into installer
- ✓ Unattended installation
- ✓ New system verification

Note: Full installation takes 10-30 minutes per test case.

## Performance Optimization

The workflow includes several optimizations:

1. **APT Package Caching**: Dependencies are cached across workflow runs
2. **Base Image Caching**: Debian 11 cloud image is downloaded once and reused
3. **Single Base Image**: All tests use Debian 11 as starting point (smaller cache footprint)
4. **Matrix Exclusions**: Intelligent filtering reduces redundant test combinations

## Adding New Test Cases

The workflow uses a semantic matrix. To modify test coverage:

**Add a new Debian version:**
```yaml
matrix:
  version: [10, 11, 12, 13]  # Add 13
```

**Test with a new mirror:**
```yaml
matrix:
  mirror: ['default', 'ustc', 'cloudflare', 'tuna']  # Add tuna
```

**Modify exclusions:**
```yaml
exclude:
  # Add exclusions to prevent unwanted combinations
  - version: 13
    mirror: 'ustc'  # Skip USTC for Debian 13
```

The workflow automatically builds command-line arguments from matrix parameters.

## Troubleshooting

### KVM not available
If KVM is not available, the workflow will fail. GitHub Actions runners support KVM, but some self-hosted runners may not.

### Network timeouts
If downloads fail, consider:
- Adding retry logic
- Using alternative mirrors
- Checking GitHub Actions network restrictions

### VM boot failures
Check the serial console log artifact for kernel messages and boot errors.

### Installation hangs
If the installation takes too long:
- Check the serial console for progress
- Verify mirror connectivity
- Consider using a faster mirror (USTC, Cloudflare)

### Cache issues
To clear caches and force fresh downloads:
1. Go to Actions tab → Caches
2. Delete relevant cache entries
3. Re-run the workflow

Cache keys are based on workflow file hash, so modifying the workflow automatically invalidates caches.
