#!/usr/bin/env bash
# Shared helpers. Run everything as root on the controlplane node.
M=/etc/kubernetes/manifests
BK=/root/cka-backup
backup() {
  if [ ! -d $BK ]; then
    mkdir -p $BK
    cp -a $M $BK/manifests
    cp -a /var/lib/kubelet/config.yaml $BK/kubelet-config.yaml
    cp -a /etc/kubernetes/kubelet.conf $BK/kubelet.conf 2>/dev/null || true
    echo "[backup] saved to $BK"
  fi
}
need_root() { [ "$(id -u)" = 0 ] || { echo "run as root (sudo -i)"; exit 1; }; }
