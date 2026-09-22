#!/usr/bin/env bash
# Scenario 6: run this ON THE WORKER NODE (ssh node01; sudo -i). Node goes NotReady.
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
systemctl stop kubelet
systemctl disable kubelet >/dev/null 2>&1
echo "[break 6] applied on $(hostname). Go back to controlplane and check 'kubectl get nodes' in ~40s."
