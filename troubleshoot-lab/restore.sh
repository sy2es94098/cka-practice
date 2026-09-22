#!/usr/bin/env bash
# Restore the control plane to the pre-break state.
source "$(dirname "$0")/lib.sh"; need_root
[ -d $BK ] || { echo "no backup found at $BK"; exit 1; }
systemctl start containerd 2>/dev/null || true
cp -a $BK/manifests/* $M/
cp -a $BK/kubelet-config.yaml /var/lib/kubelet/config.yaml
[ -f $BK/kubelet.conf ] && cp -a $BK/kubelet.conf /etc/kubernetes/kubelet.conf
systemctl daemon-reload
systemctl enable --now kubelet >/dev/null 2>&1
systemctl restart kubelet
echo "restored. wait ~30-60s then: kubectl get nodes"
