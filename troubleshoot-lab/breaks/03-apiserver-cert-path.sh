#!/usr/bin/env bash
# Scenario 3: apiserver etcd client cert path wrong
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt#--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.pem#' $M/kube-apiserver.yaml
echo "[break 3] applied."
