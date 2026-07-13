#!/usr/bin/env bash
set -euo pipefail

damx_base="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense"
damx_profile="${damx_base}/damx_thermal_profile"
damx_choices="${damx_base}/damx_thermal_profile_choices"
platform_profile="/sys/firmware/acpi/platform_profile"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

expect_file() {
    local path=$1 expected=$2 actual
    actual="$(<"${path}")"
    [[ ${actual} == "${expected}" ]] || fail "${path}: expected ${expected}, got ${actual}"
}

await_command() {
    local expected=$1
    shift
    local actual=""

    for _ in {1..20}; do
        actual="$("$@" 2>/dev/null || true)"
        [[ ${actual} == "${expected}" ]] && return 0
        sleep 0.25
    done

    fail "$*: expected ${expected}, got ${actual}"
}

damx_set() {
    python - "$1" <<'PY'
import json
import socket
import sys

request = {
    "command": "set_thermal_profile",
    "params": {"profile": sys.argv[1]},
}

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect("/var/run/DAMX.sock")
    client.sendall(json.dumps(request).encode("utf-8"))
    response = json.loads(client.recv(4096).decode("utf-8"))

if not response.get("success"):
    raise SystemExit(response)
PY
}

[[ -r ${damx_profile} ]] || fail "missing ${damx_profile}"
[[ -r ${damx_choices} ]] || fail "missing ${damx_choices}"

original_profile="$(<"${damx_profile}")"
[[ -n ${original_profile} ]] || fail "DAMX returned an empty initial profile"
restore_profile() {
    if damx_set "${original_profile}" >/dev/null 2>&1; then
        return
    fi

    case "${original_profile}" in
        quiet) powerprofilesctl set power-saver >/dev/null 2>&1 || true ;;
        balanced) powerprofilesctl set balanced >/dev/null 2>&1 || true ;;
        *) powerprofilesctl set performance >/dev/null 2>&1 || true ;;
    esac
}
trap restore_profile EXIT

ac_online=""
for online_path in /sys/class/power_supply/*/online; do
    [[ -r ${online_path} ]] || continue
    type_path="$(dirname "${online_path}")/type"
    [[ -r ${type_path} && $(<"${type_path}") == Mains ]] || continue
    ac_online="$(<"${online_path}")"
    break
done

battery_status="$(cat /sys/class/power_supply/BAT*/status 2>/dev/null || true)"
if [[ ${ac_online} == 0 || ( -z ${ac_online} && ${battery_status} == *Discharging* ) ]]; then
    power_source="battery"
elif [[ ${ac_online} == 1 || ${battery_status} == *Charging* || ${battery_status} == *Full* ]]; then
    power_source="ac"
else
    fail "unable to determine power source (AC=${ac_online:-unknown}, battery=${battery_status:-unknown})"
fi

echo "Power source: ${power_source}"
echo "DAMX choices: $(<"${damx_choices}")"

echo "Testing KDE power-saver -> DAMX quiet..."
powerprofilesctl set power-saver
await_command power-saver powerprofilesctl get
expect_file "${platform_profile}" low-power
expect_file "${damx_profile}" quiet

echo "Testing KDE balanced -> DAMX balanced..."
powerprofilesctl set balanced
await_command balanced powerprofilesctl get
expect_file "${platform_profile}" balanced
expect_file "${damx_profile}" balanced

echo "Testing KDE performance mapping..."
powerprofilesctl set performance
await_command performance powerprofilesctl get
expect_file "${platform_profile}" performance
if [[ ${power_source} == ac ]]; then
    expect_file "${damx_profile}" balanced-performance
else
    expect_file "${damx_profile}" balanced
fi

echo "Testing DAMX quiet -> KDE power-saver..."
damx_set quiet
await_command power-saver powerprofilesctl get
expect_file "${platform_profile}" low-power

echo "Testing DAMX balanced -> KDE balanced..."
damx_set balanced
await_command balanced powerprofilesctl get
expect_file "${platform_profile}" balanced

if [[ ${power_source} == ac ]]; then
    echo "Testing DAMX performance -> KDE performance..."
    damx_set balanced-performance
    await_command performance powerprofilesctl get
    expect_file "${platform_profile}" performance
    expect_file "${damx_profile}" balanced-performance

    echo "Testing DAMX Turbo -> KDE performance..."
    damx_set performance
    await_command performance powerprofilesctl get
    expect_file "${platform_profile}" performance
    expect_file "${damx_profile}" performance
fi

echo "PASS: KDE and DAMX profile synchronization is correct on ${power_source}."
