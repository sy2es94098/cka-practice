#!/usr/bin/env bash
# Killercoda 開環境後的一鍵初始化
set -e
cd "$(dirname "$0")"

echo "==> install helm"
command -v helm >/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "==> alias / completion"
grep -q 'alias k=kubectl' ~/.bashrc || cat >> ~/.bashrc << 'B'
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"
B

case "${1:-mock}" in
  mock) ./cka-mock/setup.sh ;;
  helm) ./helm-lab/setup.sh ;;
  all)  ./cka-mock/setup.sh; ./helm-lab/setup.sh ;;
esac

echo
echo "完成。執行 source ~/.bashrc 啟用 alias。"
echo "cka-mock 題目：cat cka-mock/questions.md | less"
echo "helm-lab 題目：cat helm-lab/tasks.md | less"