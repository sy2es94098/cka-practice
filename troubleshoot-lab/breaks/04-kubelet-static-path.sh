#!/usr/bin/env bash
# Scenario 4: kubelet staticPodPath changed -> ALL control plane pods disappear
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#^staticPodPath: .*#staticPodPath: /etc/kubernetes/manifest#' /var/lib/kubelet/config.yaml
systemctl restart kubelet
echo "[break 4] applied."
