#!/usr/bin/env bash
# Scenario 8: run ON THE WORKER NODE. containerd stopped -> node NotReady, kubelet running but complaining.
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
systemctl stop containerd
echo "[break 8] applied on $(hostname)."
