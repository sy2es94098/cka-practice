#!/usr/bin/env bash
# Scenario 10: kubelet config clientCAFile wrong -> kubelet fails to start on controlplane
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#clientCAFile: /etc/kubernetes/pki/ca.crt#clientCAFile: /etc/kubernetes/pki/CA.crt#' /var/lib/kubelet/config.yaml
systemctl restart kubelet
echo "[break 10] applied."
