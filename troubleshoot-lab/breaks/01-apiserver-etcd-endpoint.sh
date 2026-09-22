#!/usr/bin/env bash
# Scenario 1: apiserver cannot reach etcd ("external etcd" style)
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#--etcd-servers=https://127.0.0.1:2379#--etcd-servers=https://10.99.99.99:2379#' $M/kube-apiserver.yaml
echo "[break 1] applied. Story: the cluster was migrated to an external etcd last night."
