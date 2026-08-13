#!/usr/bin/env bash
# Disposable QEMU VM built straight from this flake's own `earth` nixosConfiguration —
# no separate host/hardware.nix needed, NixOS's own qemu-vm module (present in every
# nixosSystem) already swaps disks/boot for VM-friendly ones. Lets changes to session/
# service modules (core/x11-greetd-sessions.nix, greetd, etc.) get a real switch+restart
# test cycle on a throwaway system instead of the real `earth` host.
#
# What it does:
#   1. Builds config.system.build.vm for `earth`, extended (via --impure, not committed
#      anywhere) with an SSH key for this run and passwordless sudo for the VM-only
#      `ryudzyn` account — neither touches the real repo or the real host.
#   2. Boots it headless (-nographic, serial console) with the repo's working tree
#      shared in read-only via 9p at /tmp/shared inside the guest, and an SSH port
#      forwarded to the host.
#   3. Prints the SSH command to drive it.
#
# Confirmed by an actual test run: a plain cold boot (fresh disk, this script's default) is
# reliable and already catches real bugs this way — greetd starting, generated .desktop
# sessions, etc. all get exercised for real (e.g. this is how a real, host-independent
# `systemd-vconsole-setup` console-font failure got found).
#
# A live `sudo nixos-rebuild switch --flake /tmp/shared#earth` *inside* the guest is riskier
# than it looks: the guest's /nix/store and /tmp/shared are 9p mounts injected only for this
# particular boot (that's how build-vm avoids copying the whole store onto the guest disk) —
# they aren't declared in the real `fileSystems` config, so `switch-to-configuration` sees them
# as "obsolete" units and tears them down mid-switch, which killed SSH and the store access in
# testing (not a bug in this repo's config, just build-vm's mount handling not expecting a
# generation change). It DID correctly reproduce the documented `X-RestartIfChanged=false`
# greetd behavior first ("NOT restarting the following changed units: greetd.service") before
# that happened, so it's useful for a one-shot "what would change" check — just expect the VM
# to need a fresh boot afterward, don't try to keep iterating in the same guest. Prefer:
#   sudo /nix/store/.../bin/switch-to-configuration dry-activate
# (build the toplevel first, see below) to see the planned unit actions without touching
# anything, or accept the one-shot `test` action and just re-run this script for the next round.
#
# The guest disk (state dir below) persists across runs, so generations accumulate
# like a real system if you want that; delete the state dir for a clean slate.
#
# Usage: scripts/test-vm.sh [--fresh]
#   --fresh   wipe the persistent guest disk and SSH known_hosts entry first

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nebula-vm-test"
SSH_PORT="${NEBULA_VM_SSH_PORT:-2222}"
VM_MEM="${NEBULA_VM_MEM:-3072}"

mkdir -p "$STATE_DIR"

if [ "${1:-}" = "--fresh" ]; then
  rm -f "$STATE_DIR"/earth.qcow2
  ssh-keygen -q -R "[localhost]:$SSH_PORT" -f "$STATE_DIR/known_hosts" 2>/dev/null || true
fi

if [ ! -f "$STATE_DIR/vm_key" ]; then
  ssh-keygen -t ed25519 -N "" -f "$STATE_DIR/vm_key" -C "nebula-vm-test" -q
fi
PUBKEY="$(cat "$STATE_DIR/vm_key.pub")"

echo "==> Building config.system.build.vm for earth (extended with a throwaway SSH key + passwordless sudo, not committed)..."
VM_PATH="$(nix build --impure --no-link --print-out-paths --expr "
  let
    flake = builtins.getFlake (toString $REPO_ROOT);
  in (flake.nixosConfigurations.earth.extendModules {
    modules = [{
      users.users.ryudzyn.openssh.authorizedKeys.keys = [ \"$PUBKEY\" ];
      security.sudo.wheelNeedsPassword = false;
    }];
  }).config.system.build.vm
")"

echo "==> Booting (serial console, repo shared read-only at /tmp/shared, ssh on 127.0.0.1:$SSH_PORT)..."
NIX_DISK_IMAGE="$STATE_DIR/earth.qcow2" \
SHARED_DIR="$REPO_ROOT" \
QEMU_NET_OPTS="hostfwd=tcp::${SSH_PORT}-:22" \
QEMU_OPTS="-nographic -m ${VM_MEM}" \
  "$VM_PATH/bin/run-earth-vm" &
VM_PID=$!
echo "$VM_PID" > "$STATE_DIR/vm.pid"

echo "==> VM PID $VM_PID. Waiting for SSH..."
for _ in $(seq 1 40); do
  if ssh -i "$STATE_DIR/vm_key" -o UserKnownHostsFile="$STATE_DIR/known_hosts" \
      -o StrictHostKeyChecking=accept-new -o ConnectTimeout=2 -p "$SSH_PORT" \
      ryudzyn@localhost true 2>/dev/null; then
    break
  fi
  sleep 3
done

cat <<EOF

==> Ready. Connect with:
  ssh -i "$STATE_DIR/vm_key" -o UserKnownHostsFile="$STATE_DIR/known_hosts" -p $SSH_PORT ryudzyn@localhost

==> Inside the guest, the repo's working tree (including uncommitted changes) is at
    /tmp/shared (read-only).

==> To see what a switch WOULD do, without the mount-teardown risk (see header comment):
  cd /tmp/shared
  TOPLEVEL=\$(nix build --no-link --print-out-paths .#nixosConfigurations.earth.config.system.build.toplevel)
  sudo "\$TOPLEVEL/bin/switch-to-configuration" dry-activate

==> To actually activate (one-shot — expect to lose the SSH/store mounts afterward, that's the
    known build-vm limitation above, not a config bug; re-run this script fresh for the next round):
  sudo "\$TOPLEVEL/bin/switch-to-configuration" test

==> Stop the VM:
  kill $VM_PID

==> Reset to a clean disk next run:
  scripts/test-vm.sh --fresh
EOF
