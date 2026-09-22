#!/usr/bin/env bash
# Scenario 9: apiserver secure-port changed -> kubectl connection refused on 6443, apiserver itself is Running
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#--secure-port=6443#--secure-port=6444#' $M/kube-apiserver.yaml
echo "[break 9] applied."
