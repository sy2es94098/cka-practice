#!/usr/bin/env bash
# 清除所有 lab 資源後重新建置
for ns in helm-lab team-a team-b legacy argocd; do
  kubectl delete ns $ns --ignore-not-found >/dev/null 2>&1 &
done
wait
rm -rf "$(dirname "$0")/repo"
exec "$(dirname "$0")/setup.sh"
