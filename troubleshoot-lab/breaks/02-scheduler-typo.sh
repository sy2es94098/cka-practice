#!/usr/bin/env bash
# Scenario 2: scheduler flag typo -> CrashLoop, new pods stay Pending
source "$(dirname "$0")/../lib.sh"; need_root; backup
sed -i 's#--kubeconfig=/etc/kubernetes/scheduler.conf#--kubeconfig=/etc/kubernetes/schedular.conf#' $M/kube-scheduler.yaml
echo "[break 2] applied."
