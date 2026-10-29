#!/usr/bin/env bash
# Tests of the Linux nearby radio (the BlueZ backend in raven-node), run from the raven-core
# submodule. No Bluetooth adapter is used.
#
#   scripts/check.sh            the backend's tests (its pure part builds and runs on any OS;
#                               on glibc Linux the D-Bus part is compiled too)
#   scripts/check.sh --btvirt   also the end-to-end test on two emulated BlueZ controllers
#                               (Linux only; needs root for modprobe hci_vhci and btvirt, a
#                               running bluetoothd, and both controllers powered: see README.md)
#
# The tests use throwaway profiles with the file-backed test stores, never ~/.raven.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$REPO/core/node"
if [[ ! -f "$NODE/Cargo.toml" ]]; then
  echo "core/ is empty: run 'git submodule update --init' first" >&2
  exit 1
fi
BTVIRT=0
case "${1:-}" in
  "") ;;
  --btvirt) BTVIRT=1 ;;
  *) echo "usage: $0 [--btvirt]" >&2; exit 2 ;;
esac

export RAVEN_IDENTITY_BACKEND=locked-file RAVEN_SESSION_BACKEND=locked-file \
  RAVEN_PREKEY_BACKEND=locked-file RAVEN_CHAT_HISTORY_BACKEND=locked-file \
  RAVEN_ALLOW_EPHEMERAL_DATA_DIR=1
cd "$NODE"
cargo test --locked -p raven-node --features nearby-radio --bin raven-node -- nearby::bluez
if [[ "$BTVIRT" == 1 ]]; then
  if [[ "$(uname -s)" != Linux ]]; then
    echo "--btvirt runs on Linux only" >&2
    exit 1
  fi
  RAVEN_LAB_BLUEZ_BTVIRT=1 cargo test --locked -p raven-node --features nearby-radio \
    --bin raven-node -- nearby::bluez::dbus::tests::btvirt --ignored --nocapture
fi
echo "raven-mesh-linux checks passed"
