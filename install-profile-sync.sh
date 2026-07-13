#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
driver_repo="/home/guillemvg/Projectes/Div-Linuwu-Sense"
daemon_src="${repo_dir}/DAMM-Daemon"
daemon_dst="/opt/damx/daemon-profile-sync"
service_src="${repo_dir}/damx-daemon-profile-sync.service"
service_dst="/etc/systemd/system/damx-daemon.service"
backup_root="/var/backups/damx-profile-sync"
backup_dir="${backup_root}/$(date +%Y%m%d-%H%M%S)"
package_name="linuwu-sense"
old_version="25.701.phn16.73.sync1"
new_version="25.701.phn16.73.sync2"
old_source="/usr/src/${package_name}-${old_version}"
new_source="/usr/src/${package_name}-${new_version}"
old_removed=0
backup_complete=0

for path in \
    "${driver_repo}/Makefile" \
    "${driver_repo}/dkms.conf" \
    "${driver_repo}/src/linuwu_sense.c" \
    "${daemon_src}/DAMX-Daemon.py" \
    "${daemon_src}/PowerSourceDetection.py" \
    "${service_src}"; do
    if [[ ! -f ${path} ]]; then
        echo "Missing required file: ${path}" >&2
        exit 1
    fi
done

kernels=()
for build_dir in /lib/modules/*/build; do
    [[ -d ${build_dir} ]] || continue
    kernels+=("$(basename "$(dirname "${build_dir}")")")
done
if [[ ${#kernels[@]} -eq 0 ]]; then
    echo "No installed kernel build directories found." >&2
    exit 1
fi

backup_file() {
    local path=$1
    [[ -e ${path} ]] || return 0
    install -d "${backup_dir}$(dirname "${path}")"
    cp -a "${path}" "${backup_dir}${path}"
}

restore_old_dkms() {
    [[ ${old_removed} -eq 1 ]] || return 0
    echo "Restoring previous DKMS module after failure..." >&2
    dkms remove -m "${package_name}" -v "${new_version}" --all 2>/dev/null || true
    rm -rf "${new_source}"
    if [[ -d ${backup_dir}${old_source} ]]; then
        rm -rf "${old_source}"
        cp -a "${backup_dir}${old_source}" "${old_source}"
        dkms add -m "${package_name}" -v "${old_version}" 2>/dev/null || true
        for kernel in "${kernels[@]}"; do
            dkms build -m "${package_name}" -v "${old_version}" -k "${kernel}" || true
            dkms install -m "${package_name}" -v "${old_version}" -k "${kernel}" --force || true
        done
    fi
}

restore_daemon() {
    [[ -f ${backup_dir}${service_dst} ]] || return 0
    install -m 0644 "${backup_dir}${service_dst}" "${service_dst}"
    install -m 0755 "${backup_dir}/opt/damx/daemon/DAMX-Daemon" /opt/damx/daemon/DAMX-Daemon
    systemctl daemon-reload
    systemctl start damx-daemon.service 2>/dev/null || true
}

restore_optional_config() {
    local path=$1
    rm -f "${path}"
    if [[ -f ${backup_dir}${path} ]]; then
        install -d "$(dirname "${path}")"
        cp -a "${backup_dir}${path}" "${path}"
    fi
}

restore_configuration() {
    restore_optional_config /etc/modules-load.d/linuwu_sense.conf
    restore_optional_config /etc/modprobe.d/blacklist-acer_wmi.conf
    restore_optional_config /etc/systemd/system/linuwu_sense.service
    restore_optional_config /etc/systemd/system/damx-restore-predator-profile.service
    restore_optional_config /etc/systemd/system/damx-restore-predator-profile.timer
    restore_optional_config /usr/local/sbin/damx-restore-predator-profile
    rm -rf /opt/damx/daemon-profile-sync
    systemctl daemon-reload
}

on_error() {
    local status=$?
    if [[ ${status} -ne 0 ]]; then
        restore_old_dkms
        if [[ ${backup_complete} -eq 1 ]]; then
            restore_configuration
            restore_daemon
        fi
    fi
    exit "${status}"
}
trap on_error EXIT

echo "Creating rollback backup at ${backup_dir}..."
install -d -m 0750 "${backup_dir}"
for path in \
    "${service_dst}" \
    /opt/damx/daemon/DAMX-Daemon \
    "${old_source}" \
    /etc/modules-load.d/linuwu_sense.conf \
    /etc/modprobe.d/blacklist-acer_wmi.conf \
    /etc/systemd/system/linuwu_sense.service \
    /etc/systemd/system/damx-restore-predator-profile.service \
    /etc/systemd/system/damx-restore-predator-profile.timer \
    /usr/local/sbin/damx-restore-predator-profile; do
    backup_file "${path}"
done
systemctl is-enabled linuwu_sense.service > "${backup_dir}/linuwu_sense.enabled" 2>/dev/null || true
systemctl is-enabled damx-restore-predator-profile.timer > "${backup_dir}/profile_timer.enabled" 2>/dev/null || true
printf '%s\n' "${backup_dir}" > "${backup_root}/latest"
backup_complete=1

if [[ -e /var/lib/dkms/${package_name}/${new_version} || -e ${new_source} ]]; then
    echo "DKMS revision ${package_name}/${new_version} already exists; refusing a destructive reinstall." >&2
    exit 1
fi

while IFS=',' read -r _ kernel _; do
    kernel="${kernel//[[:space:]]/}"
    [[ -n ${kernel} ]] || continue
    if [[ ! -d /lib/modules/${kernel}/build ]]; then
        echo "Existing DKMS build ${kernel} has no headers; refusing to remove it." >&2
        exit 1
    fi
done < <(dkms status -m "${package_name}" -v "${old_version}" 2>/dev/null || true)

echo "Staging and building ${package_name}/${new_version}..."
install -d "${new_source}/src"
install -m 0644 "${driver_repo}/Makefile" "${new_source}/Makefile"
install -m 0644 "${driver_repo}/dkms.conf" "${new_source}/dkms.conf"
install -m 0644 "${driver_repo}/src/linuwu_sense.c" "${new_source}/src/linuwu_sense.c"
dkms add -m "${package_name}" -v "${new_version}"
for kernel in "${kernels[@]}"; do
    dkms build -m "${package_name}" -v "${new_version}" -k "${kernel}"
done

echo "Replacing the previous DKMS revision only after successful builds..."
dkms remove -m "${package_name}" -v "${old_version}" --all 2>/dev/null || true
old_removed=1
for kernel in "${kernels[@]}"; do
    dkms install -m "${package_name}" -v "${new_version}" -k "${kernel}" --force
done

printf '%s\n' "linuwu_sense" > /etc/modules-load.d/linuwu_sense.conf
printf '%s\n' "blacklist acer_wmi" > /etc/modprobe.d/blacklist-acer_wmi.conf
rm -f /tmp/damx_restart_attempts

echo "Installing patched DAMX daemon sources..."
install -d -o root -g root -m 0755 "${daemon_dst}"
install -o root -g root -m 0755 "${daemon_src}/DAMX-Daemon.py" "${daemon_dst}/DAMX-Daemon.py"
install -o root -g root -m 0644 "${daemon_src}/PowerSourceDetection.py" "${daemon_dst}/PowerSourceDetection.py"
install -o root -g root -m 0644 "${service_src}" "${service_dst}"
systemctl daemon-reload
systemctl restart damx-daemon.service
sleep 2
systemctl is-active --quiet damx-daemon.service

echo "Removing obsolete profile writers and shutdown unload hooks..."
systemctl disable damx-restore-predator-profile.timer 2>/dev/null || true
rm -f /etc/systemd/system/damx-restore-predator-profile.timer
rm -f /etc/systemd/system/damx-restore-predator-profile.service
rm -f /usr/local/sbin/damx-restore-predator-profile
systemctl disable linuwu_sense.service 2>/dev/null || true
printf '%s\n' \
    '[Unit]' \
    'Description=linuwu_sense is managed by DKMS and modules-load.d' \
    '' \
    '[Service]' \
    'Type=oneshot' \
    'ExecStart=/usr/bin/true' \
    'RemainAfterExit=true' \
    > /etc/systemd/system/linuwu_sense.service
systemctl daemon-reload

echo "Installation staged successfully. Reboot to activate the new DKMS module."
echo "Rollback backup: ${backup_dir}"
