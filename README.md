# Raven mesh for Linux: Bluetooth nearby over BlueZ

Bluetooth nearby lets two laptops exchange [Raven](https://raven-messager.com) messages over
Bluetooth LE when there is no Wi-Fi, cable, hotspot or Internet between them: verified contacts
only, one hop, in radio range. The message is the same end-to-end encrypted object as on any other
way; Bluetooth is only one more carrier. This repository is the Linux part: what the BlueZ backend
needs from a Linux system, how to test it, and where its code lives.

## Status: held, lab only

- **Off in every build.** Bluetooth nearby is held by a gate in the code
  (`NEARBY_PRODUCTION_ENABLED = false` in raven-core) until its release record
  (`core/docs/WAIVER_NEARBY_DRAFT.md`, unsigned) is signed after the hardware test rows
  (rows N1-N12, run from an unpublished test checklist), which have not been run yet. In a release
  build `raven nearby status` says "held in this build" and nothing touches Bluetooth.
- **What exists:** a complete BlueZ backend in `raven-node` (central and peripheral roles, GATT
  service and advertising over D-Bus, the address-privacy check), tested in CI without a radio, and
  end to end on two emulated controllers (`btvirt`) where the CI runner allows it.
- **Not verified yet:** real adapters between real laptops (hardware rows N1-N12),
  and whether every distribution lets a normal user read the adapter's privacy setting.
- Nothing here is packaged. There is nothing to download.

## Where the code lives

The backend cannot be split out of `raven-node` without breaking its build and tests, so the code
stays in [`raven-core`](https://github.com/Raven-ASHCO/raven-core) (the git submodule at `core/`
here). There is no separate helper program on Linux: raven-node talks to BlueZ itself.

| What | Where (in `core/`) |
|---|---|
| The BlueZ backend: its state machine and GATT objects (tested on every OS) | `node/crates/raven-node/src/nearby/bluez.rs` |
| Its D-Bus part (zbus 1.9.3, glibc Linux only) and the `btvirt` end-to-end test | `node/crates/raven-node/src/nearby/bluez/dbus.rs` |
| The address-privacy check (the kernel's Bluetooth management socket, no root) | `node/crates/raven-node/src/nearby/bluez_mgmt.rs` |
| The radio-independent engine (pair keys, scanning, advertising, the knock, the pipes) | `node/crates/raven-node/src/nearby/` |
| The wire format (RNL1) and its vectors | `protocol/RAVEN_NEARBY_LINK_V1.md`, `shared-vectors/rvn1/nearby/` |
| The user guide (what others can see, troubleshooting) | `docs/NEARBY.md` (section 6 is Linux) |

The backend is compiled only for glibc Linux with cargo feature `nearby-radio`; a static (musl)
build says "no Bluetooth support in this build of raven-node".

## What the system needs

- **BlueZ running.** `bluetoothd` started (`sudo systemctl enable --now bluetooth`) and the adapter
  powered (`bluetoothctl show` says `Powered: yes`). raven-node tries again by itself every 30
  seconds when BlueZ is missing.
- **Access to BlueZ on the system bus.** raven-node runs as you (the user service from
  `core/node/scripts/install/linux_systemd_user.sh`), never as root. Desktop distributions allow the
  logged-in user to use `org.bluez`; on others the distribution's D-Bus policy decides (often
  membership of a `bluetooth` group). When it refuses, `raven nearby status` says `not allowed`.
- **A private Bluetooth address.** Raven advertises and connects only from a random address. BlueZ
  uses the adapter's fixed public address unless an administrator sets, in
  `/etc/bluetooth/main.conf`:

  ```ini
  [General]
  Privacy = device
  ```

  and restarts Bluetooth (`sudo systemctl restart bluetooth`). Without it the computer neither
  advertises nor connects, and `raven nearby status` says nearby is inactive. Raven reads the
  setting through the kernel's Bluetooth management interface without root; when it cannot be read,
  Raven assumes the public address and stays inactive.

**Disclosed limitation:** BlueZ sends a notification to every device subscribed to a service, so a
stranger that connects and subscribes to the service for one contact sees that link's encrypted
traffic (sizes and timing, never content). macOS and Windows send to the one contact only.

## Test

```sh
git clone --recurse-submodules https://github.com/Raven-ASHCO/raven-mesh-linux.git
cd raven-mesh-linux
scripts/check.sh
```

This runs the backend's tests from `core/node` (Rust via [rustup](https://rustup.rs); raven-core CI
uses 1.98.0). No adapter is used, and the tests use throwaway profiles with file-backed test stores.

End to end on two emulated controllers (Linux, root for the kernel module and `btvirt`; the package
names are Ubuntu's):

```sh
sudo apt-get install bluez bluez-test-tools "linux-modules-extra-$(uname -r)"
sudo modprobe hci_vhci
sudo systemctl restart bluetooth
sudo "$(command -v btvirt || echo /usr/lib/bluetooth/btvirt)" -L -l2 &
sudo btmgmt --index 0 power on && sudo btmgmt --index 1 power on
scripts/check.sh --btvirt
```

## Try it (developers, lab only)

A debug build with Bluetooth support and both lab switches, on a test profile, never `~/.raven`:

```sh
cd core/node
cargo build --locked -p ash -p raven-node --features raven-node/nearby-radio
export RAVEN_LAB_TEST_A=1 RAVEN_LAB_NEARBY=1 RAVEN_DATA_DIR="$HOME/raven-nearby-test"
```

Then `raven nearby enable` and `raven nearby status`. `core/docs/NEARBY.md` explains every status
line and what other people in radio range can see.

## Planned

- Run the hardware rows on real laptops: N2 (Mac to Linux, `Privacy = device` on and off), N4
  (Linux to Windows), the rows for any pair (range, throughput, sleep, carrier order, Wi-Fi
  coexistence), N7 (privacy capture) and N8 (the systemd user service; reading the privacy setting
  without root on each distribution).
- Then decide on the release gate (`core/docs/WAIVER_NEARBY_DRAFT.md`).

## License

Copyright (C) 2026 ASHCO. GNU Affero General Public License v3.0 (`LICENSE`; notice and pending
additional terms in `NOTICE`). Security issues: please write to
security@raven-messager.com (`SECURITY.md`), not a public issue.
