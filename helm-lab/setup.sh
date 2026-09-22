#!/usr/bin/env bash
# Helm 練習 lab 環境建置腳本
# 前提：已有可用的 kubectl 連線到集群（kind / minikube / killercoda 皆可），且已安裝 helm
set -e

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> 檢查工具"
command -v kubectl >/dev/null || { echo "缺少 kubectl"; exit 1; }
command -v helm >/dev/null || { echo "缺少 helm，請先安裝: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"; exit 1; }
kubectl cluster-info >/dev/null || { echo "無法連線到集群"; exit 1; }

echo "==> 加入 Bitnami / Argo repo（需要網路）"
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "==> 打包本地 chart 的三個版本，模擬 chart repo"
mkdir -p "$LAB_DIR/repo"
rm -f "$LAB_DIR"/repo/*.tgz
cp -r "$LAB_DIR/charts/webapp" /tmp/webapp-pkg
for v in 1.0.0 1.1.0 1.2.0; do
  sed -i "s/^version: .*/version: $v/" /tmp/webapp-pkg/Chart.yaml
  case $v in
    1.1.0) sed -i 's/^appVersion: .*/appVersion: "1.26"/; s/tag: .*/tag: "1.26"/' /tmp/webapp-pkg/Chart.yaml /tmp/webapp-pkg/values.yaml ;;
    1.2.0) sed -i 's/^appVersion: .*/appVersion: "1.27"/; s/tag: .*/tag: "1.27"/' /tmp/webapp-pkg/Chart.yaml /tmp/webapp-pkg/values.yaml ;;
  esac
  helm package /tmp/webapp-pkg -d "$LAB_DIR/repo" >/dev/null
done
rm -rf /tmp/webapp-pkg
helm repo index "$LAB_DIR/repo"
# 以本地檔案路徑當作 repo（Helm 支援 file:// 有限制，改用 --repo 或直接用 tgz 路徑）
echo "   本地 chart 套件位於 $LAB_DIR/repo/"

echo "==> 建立情境用 namespace"
for ns in helm-lab team-a team-b legacy; do
  kubectl create ns $ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

echo "==> 情境 A：已存在一個舊版 release（供升級/回滾練習）"
helm upgrade --install shop "$LAB_DIR/repo/webapp-1.0.0.tgz" -n team-a --set replicaCount=2 --set configMessage="shop v1" >/dev/null
helm upgrade shop "$LAB_DIR/repo/webapp-1.1.0.tgz" -n team-a --set replicaCount=2 --set configMessage="shop v2" >/dev/null

echo "==> 情境 B：一個壞掉的 release（image tag 不存在）"
helm upgrade --install broken "$LAB_DIR/repo/webapp-1.0.0.tgz" -n team-b --set image.tag=does-not-exist >/dev/null

echo "==> 情境 C：legacy namespace 裡有一個要被移除的 release，以及一個非 helm 管理的 deployment"
helm upgrade --install old-api "$LAB_DIR/repo/webapp-1.0.0.tgz" -n legacy >/dev/null
kubectl -n legacy create deployment manual-app --image=nginx:1.25 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo
echo "==> 建置完成。請開啟 tasks.md 開始練習。"
echo "    本地 chart 路徑：$LAB_DIR/charts/webapp"
echo "    打包版本：$LAB_DIR/repo/webapp-{1.0.0,1.1.0,1.2.0}.tgz"
