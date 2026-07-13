# DAMX PHN16-73

Private fork of [Div Acer Manager Max](https://github.com/PXDiv/Div-Acer-Manager-Max) and [Linuwu Sense](https://github.com/PXDiv/Div-Linuwu-Sense) for the Acer Predator Helios Neo 16 AI `PHN16-73` on CachyOS with KDE Plasma.

It packages the patched Linuwu Sense driver in `driver/`, a DAMX daemon that uses the driver-specific thermal-profile interface, and a DAMX GUI that follows profile changes made outside the application.

> [!WARNING]
> This fork was developed and tested only on `Acer Predator PHN16-73`. It changes low-level WMI/EC settings. Keep the rollback backup, do not use it on another model without adapting and testing the driver, and reboot after installing or rolling back the DKMS module.

## What This Fork Changes

- Adds native DMI support for `Acer Predator PHN16-73` using the Predator v4 quirk.
- Does not enable four-zone keyboard RGB for this model.
- Adds `damx_thermal_profile` and `damx_thermal_profile_choices` sysfs interfaces for DAMX.
- Keeps KDE Power Profiles and DAMX thermal profiles synchronized.
- Shows Quiet in DAMX on both battery and AC.
- Refreshes the DAMX GUI every second while it is open, without writing an externally selected profile back to KDE.
- Builds the module through DKMS for every installed kernel with headers. CachyOS kernels are built with LLVM.

## Profile Mapping

| KDE Power Profiles | DAMX on battery | DAMX on AC |
| --- | --- | --- |
| Power Save | Quiet | Quiet |
| Balanced | Balanced | Balanced |
| Performance | Balanced | Performance |

DAMX Turbo maps to KDE Performance. Turbo is intentionally available only from DAMX while connected to AC.

## Clean CachyOS Installation

These steps assume a fresh CachyOS KDE installation and an active Internet connection.

### 1. Check the machine and kernel

Confirm the model and running kernel before making any change:

```bash
cat /sys/class/dmi/id/product_name
uname -r
```

The product name must be `Predator PHN16-73`. Install headers matching every kernel that you intend the DKMS module to support. For the default CachyOS kernel:

```bash
sudo pacman -Syu --needed base-devel dkms git python power-profiles-daemon linux-cachyos-headers
```

If `uname -r` does not belong to the default CachyOS kernel, install the corresponding headers for that kernel instead. Reboot after a kernel update before continuing.

### 2. Install DAMX upstream without its driver

This fork patches an existing DAMX installation. Download and install DAMX from the [upstream releases](https://github.com/PXDiv/Div-Acer-Manager-Max/releases), selecting **Install without Drivers** in its installer. This creates the GUI installation that `install-gui-quiet-battery.sh` replaces.

Do not install the upstream Linuwu Sense driver: this repository supplies its own patched DKMS driver.

### 3. Clone this fork and build the GUI

Install a .NET 9 SDK from the CachyOS/Arch repositories or the official Microsoft packages, then clone the repository:

```bash
git clone https://github.com/guillo1990/DAMX-PHN16-73.git
cd DAMX-PHN16-73
dotnet publish DivAcerManagerMax/DivAcerManagerMax.csproj \
  -c Release \
  -f net9.0 \
  -r linux-x64 \
  --self-contained true \
  /p:PublishSingleFile=true \
  /p:IncludeNativeLibrariesForSelfExtract=true \
  /p:IncludeAllContentForSelfExtract=true
```

The publish command creates `DivAcerManagerMax/bin/Release/net9.0/linux-x64/publish/DivAcerManagerMax`, which is intentionally not committed to Git.

### 4. Install the profile synchronization and GUI

Run the installers from the repository root:

```bash
sudo ./install-profile-sync.sh
sudo ./install-gui-quiet-battery.sh
```

`install-profile-sync.sh` installs the DKMS source, replaces the DAMX daemon service, blacklists the stock `acer_wmi` module, and creates a backup in `/var/backups/damx-profile-sync`. `install-gui-quiet-battery.sh` backs up and replaces the existing DAMX GUI.

Do not manually unload or reload `linuwu_sense`; reboot instead.

### 5. Reboot and validate

Reboot to load the new DKMS module, then verify the driver and service:

```bash
cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/damx_thermal_profile
systemctl status damx-daemon.service
```

Run the complete profile test once on AC and once on battery:

```bash
./validate-profile-sync.sh
```

The test changes profiles temporarily and restores the initial profile on exit.

## Daily Use

- Use KDE Power Profiles for Power Save, Balanced, and Performance.
- Use DAMX for Quiet, Balanced, Performance, fan controls, and Turbo on AC.
- DAMX updates its selected thermal-profile button within about one second after a KDE profile change.
- DAMX does not need to remain open for KDE and daemon synchronization to work.

## Rollback

The installers preserve the previous DAMX and DKMS state. To restore it:

```bash
sudo ./rollback-profile-sync.sh
sudo ./rollback-gui-quiet-battery.sh
sudo reboot
```

The profile rollback uses the path recorded in `/var/backups/damx-profile-sync/latest`. The GUI rollback uses `/var/backups/damx-profile-sync/latest-gui`.

## Troubleshooting

- Check daemon logs: `journalctl -u damx-daemon.service -b`.
- Confirm the active module: `modinfo linuwu_sense | grep -E 'version|srcversion'`.
- Confirm the interface exists: `cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/damx_thermal_profile_choices`.
- If DKMS fails, ensure headers exist for the affected kernel under `/lib/modules/<kernel>/build`.
- If DAMX reports `UNKNOWN`, confirm that the system DMI product name is exactly `Predator PHN16-73` and reboot rather than attempting a module hot reload.

## Upstream and License

This fork retains the GPL-3.0 license of the upstream projects. It preserves the original DAMX history and imports Linuwu Sense under `driver/` with its upstream history. See [LICENSE](LICENSE) for the complete license text.
