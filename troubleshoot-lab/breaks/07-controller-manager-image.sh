#!/usr/bin/env bash
# Scenario 7: controller-manager image tag wrong -> Deployments don't create pods
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i -E 's#(image: registry.k8s.io/kube-controller-manager:v[0-9.]+)#\1-broken#' $M/kube-controller-manager.yaml
echo "[break 7] applied."
