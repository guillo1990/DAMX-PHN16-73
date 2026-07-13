#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

backup_root="/var/backups/damx-profile-sync"
latest_file="${backup_root}/latest"
package_name="linuwu-sense"
old_version="25.701.phn16.73.sync1"
new_version="25.701.phn16.73.sync2"
old_source="/usr/src/${package_name}-${old_version}"
new_source="/usr/src/${package_name}-${new_version}"
daemon_stopped=0
dkms_transition_started=0

if [[ ! -r ${latest_file} ]]; then
    echo "No profile-sync backup pointer found." >&2
    exit 1
fi

backup_dir="$(<"${latest_file}")"
if [[ ! -d ${backup_dir} ]]; then
    echo "Backup directory is missing: ${backup_dir}" >&2
    exit 1
fi

kernels=()
for build_dir in /lib/modules/*/build; do
    [[ -d ${build_dir} ]] || continue
    kernels+=("$(basename "$(dirname "${build_dir}")")")
done

on_error() {
    local status=$?
    if [[ ${status} -ne 0 && ${dkms_transition_started} -eq 1 && -d ${new_source} ]]; then
        echo "Rollback failed; restoring the profile-sync DKMS revision..." >&2
        dkms add -m "${package_name}" -v "${new_version}" 2>/dev/null || true
        for kernel in "${kernels[@]}"; do
            dkms build -m "${package_name}" -v "${new_version}" -k "${kernel}" 2>/dev/null || true
            dkms install -m "${package_name}" -v "${new_version}" -k "${kernel}" --force 2>/dev/null || true
        done
    fi
    if [[ ${status} -ne 0 && ${daemon_stopped} -eq 1 ]]; then
        systemctl start damx-daemon.service 2>/dev/null || true
    fi
    exit "${status}"
}
trap on_error EXIT

if [[ -d ${backup_dir}${old_source} ]]; then
    echo "Building the previous DKMS revision before switching back..."
    dkms remove -m "${package_name}" -v "${old_version}" --all 2>/dev/null || true
    rm -rf "${old_source}"
    cp -a "${backup_dir}${old_source}" "${old_source}"
    dkms add -m "${package_name}" -v "${old_version}"
    for kernel in "${kernels[@]}"; do
        dkms build -m "${package_name}" -v "${old_version}" -k "${kernel}"
    done

    dkms_transition_started=1
    dkms remove -m "${package_name}" -v "${new_version}" --all 2>/dev/null || true
    for kernel in "${kernels[@]}"; do
        dkms install -m "${package_name}" -v "${old_version}" -k "${kernel}" --force
    done
    dkms_transition_started=0
    rm -rf "${new_source}"
else
    echo "No previous DKMS source existed; removing the profile-sync revision..."
    dkms remove -m "${package_name}" -v "${new_version}" --all 2>/dev/null || true
    rm -rf "${new_source}"
fi

echo "Restoring DAMX service and configuration..."
systemctl stop damx-daemon.service 2>/dev/null || true
daemon_stopped=1
install -m 0755 "${backup_dir}/opt/damx/daemon/DAMX-Daemon" /opt/damx/daemon/DAMX-Daemon
install -m 0644 "${backup_dir}/etc/systemd/system/damx-daemon.service" /etc/systemd/system/damx-daemon.service
rm -rf /opt/damx/daemon-profile-sync

restore_optional_file() {
    local path=$1
    rm -f "${path}"
    if [[ -f ${backup_dir}${path} ]]; then
        install -d "$(dirname "${path}")"
        cp -a "${backup_dir}${path}" "${path}"
    fi
}

restore_optional_file /etc/modules-load.d/linuwu_sense.conf
restore_optional_file /etc/modprobe.d/blacklist-acer_wmi.conf
restore_optional_file /etc/systemd/system/linuwu_sense.service
restore_optional_file /etc/systemd/system/damx-restore-predator-profile.service
restore_optional_file /etc/systemd/system/damx-restore-predator-profile.timer
restore_optional_file /usr/local/sbin/damx-restore-predator-profile

systemctl daemon-reload
if [[ $(<"${backup_dir}/linuwu_sense.enabled") == enabled ]]; then
    systemctl enable linuwu_sense.service
else
    systemctl disable linuwu_sense.service 2>/dev/null || true
fi
if [[ $(<"${backup_dir}/profile_timer.enabled") == enabled ]]; then
    systemctl enable damx-restore-predator-profile.timer
else
    systemctl disable damx-restore-predator-profile.timer 2>/dev/null || true
fi

systemctl start damx-daemon.service
daemon_stopped=0
echo "Rollback installed. Reboot to activate the restored kernel module."
