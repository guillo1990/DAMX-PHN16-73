#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

backup_root="/var/backups/damx-profile-sync"
latest_file="${backup_root}/latest-gui"
target="/opt/damx/gui/DivAcerManagerMax"

if [[ ! -r ${latest_file} ]]; then
    echo "No GUI backup pointer found." >&2
    exit 1
fi

backup_dir="$(<"${latest_file}")"
if [[ ! -f ${backup_dir}/DivAcerManagerMax ]]; then
    echo "GUI backup not found: ${backup_dir}/DivAcerManagerMax" >&2
    exit 1
fi

install -o root -g root -m 0755 "${backup_dir}/DivAcerManagerMax" /opt/damx/gui/.DivAcerManagerMax.old
mv -f /opt/damx/gui/.DivAcerManagerMax.old "${target}"

echo "Original DAMX GUI restored. Close DAMX and launch it again."
