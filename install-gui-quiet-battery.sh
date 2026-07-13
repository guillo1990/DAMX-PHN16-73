#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifact="${repo_dir}/DivAcerManagerMax/bin/Release/net9.0/linux-x64/publish/DivAcerManagerMax"
target="/opt/damx/gui/DivAcerManagerMax"
backup_root="/var/backups/damx-profile-sync"
backup_dir="${backup_root}/gui-$(date +%Y%m%d-%H%M%S)"

if [[ ! -x ${artifact} ]]; then
    echo "Missing compiled GUI artifact: ${artifact}" >&2
    exit 1
fi

if [[ ! -f ${target} ]]; then
    echo "Installed DAMX GUI not found: ${target}" >&2
    exit 1
fi

install -d -m 0750 "${backup_dir}"
cp -a "${target}" "${backup_dir}/DivAcerManagerMax"
printf '%s\n' "${backup_dir}" > "${backup_root}/latest-gui"

install -o root -g root -m 0755 "${artifact}" /opt/damx/gui/.DivAcerManagerMax.new
mv -f /opt/damx/gui/.DivAcerManagerMax.new "${target}"

echo "Patched DAMX GUI installed. Backup: ${backup_dir}"
echo "Close every open DAMX window and launch it again."
