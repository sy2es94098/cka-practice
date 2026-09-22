#!/usr/bin/env bash
# Scenario 5: etcd static pod points at an empty data dir -> apiserver up but cluster "empty" / or etcd fails
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#--data-dir=/var/lib/etcd#--data-dir=/var/lib/etcd-old#' $M/etcd.yaml
echo "[break 5] applied. Story: someone 'restored' etcd this morning."
