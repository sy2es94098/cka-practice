# CKA 模擬練習（12 題，建議 90 分鐘）

原創題目，題型對照 2026 考生回報的高頻類型與官方 curriculum。
執行 `./setup.sh` 後開始計時。慣例 `k` = `kubectl`。每題請自行驗證再看 solutions.md。

計分建議：每題滿分依 (分數) 標示，總分 100，66 分及格。

---

## Q1 (10) Gateway API：Ingress 轉 Gateway + HTTPRoute
namespace `web` 有一個 Ingress `shop-ingress`，集群已安裝 Gateway API CRD 與 GatewayClass `nginx-class`。
1. 建立 Gateway `shop-gateway`（namespace `web`），使用 GatewayClass `nginx-class`，一個 HTTPS listener：name `https`、port 443、hostname `shop.example.com`，TLS 模式 Terminate，使用既有 Secret `shop-tls`。
2. 建立 HTTPRoute `shop-route`（namespace `web`），掛在 `shop-gateway`，hostname `shop.example.com`，path `/` Prefix，導向 Service `web-svc` port 80。
3. 完成後刪除 Ingress `shop-ingress`。

驗證：`k -n web get gateway,httproute`；`k -n web get ingress` 應為空。

---

## Q2 (8) Helm：渲染存檔 + 指定版本安裝
1. 加入 repo `bitnami https://charts.bitnami.com/bitnami`。
2. 用 `bitnami/nginx` chart 的**次新**版本（`helm search repo --versions` 列表的第二個），以 release 名 `edge`、namespace `web`、`replicaCount=2`、`service.type=ClusterIP` 渲染 manifest 存到 `/opt/edge.yaml`。
3. 用相同參數安裝。

驗證：`helm list -n web`；`k -n web get deploy edge-nginx -o jsonpath='{.spec.replicas}'` → 2。

---

## Q3 (8) PriorityClass
集群有 PriorityClass `high-priority`。建立新的 PriorityClass `batch-priority`，value 比 `high-priority` **低 10000**，不設為 global default，description 任意。
然後讓 namespace `sched` 的 Deployment `batch-worker` 使用 `batch-priority`。

驗證：`k get pc batch-priority -o jsonpath='{.value}'` → 90000；`k -n sched get pod -l app=batch-worker -o jsonpath='{.items[0].spec.priorityClassName}'` → batch-priority。

---

## Q4 (8) 資源排程排錯
namespace `sched` 的 Deployment `resource-hog` 有 3 個 replica，部分 Pod Pending。
檢查節點可分配資源，調整容器 `requests`，使 3 個 Pod 都能排上，同時每個節點至少保留 **200m CPU、256Mi memory** 給系統。**不要修改 replicas 數、不要修改節點。**

驗證：`k -n sched get pod -l app=resource-hog` 全 Running；`k describe node` 檢查 Allocated resources 未超過上限。

---

## Q5 (6) PVC 綁定既有 PV
集群有一個 PV `data-pv`。在 namespace `storage` 建立 PVC `data-pvc`，使其成功綁定到 `data-pv`（不得修改 PV）。
再建立 Pod `data-pod`（image `nginx:1.25`），把該 PVC 掛到 `/data`。

驗證：`k -n storage get pvc data-pvc` → Bound；`k -n storage get pod data-pod` → Running。

---

## Q6 (6) CRD 查詢
1. 列出所有名稱含 `cert-manager` 的 CRD，存到 `/opt/cert-manager-crds.txt`。
2. 用 `kubectl explain` 顯示 `Certificate` 資源 `spec` 欄位的結構（含子欄位），存到 `/opt/crd-spec.txt`。

驗證：`cat /opt/cert-manager-crds.txt` 三行；`/opt/crd-spec.txt` 含 `secretName`、`dnsNames`、`issuerRef`。

---

## Q7 (7) HPA
為 namespace `hpa-lab` 的 Deployment `api` 建立 HPA `api-hpa`：min 2、max 6、CPU 平均使用率目標 70%。
另外設定 scale-down 的 stabilization window 為 120 秒。

驗證：`k -n hpa-lab get hpa api-hpa`；`k -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}'` → 120。
（metrics-server 未安裝時 TARGETS 顯示 unknown 是正常的。）

---

## Q8 (10) NetworkPolicy
namespace `net-lab` 有 Pod `frontend`(tier=frontend)、`backend`(tier=backend)、`db`(tier=db)。
建立 NetworkPolicy：
1. `db-policy`：只允許 `tier=backend` 的 Pod 存取 `tier=db` 的 Pod TCP 80，其他 ingress 全拒。
2. `backend-policy`：允許 `tier=frontend` 的 Pod 存取 `tier=backend` TCP 80；**同時**允許來自 namespace label `team=ops` 的任何 Pod 存取（兩條件為 OR）。

驗證：`k -n net-lab describe netpol`；思考 `- from:` 一個項目內寫兩個 selector（AND）與兩個 `- from:` 項目（OR）的差異。

---

## Q9 (10) 排錯 Deployment + Service
namespace `web` 的 Deployment `broken-app` Pod 起不來，Service `broken-svc` 也連不到。找出並修正**所有**問題，使 `k -n web run t --rm -it --image=busybox --restart=Never -- wget -qO- broken-svc` 能回傳 nginx 頁面。

提示：至少有三個獨立問題。不要刪除重建 Deployment/Service，用 edit/patch 修。

---

## Q10 (8) RBAC + SA
namespace `rbac-lab` 有 SA `deploy-viewer`。
1. 建立 Role `deploy-reader`：可對 `deployments`（apps）做 get/list/watch，對 `pods` 做 get/list。
2. 建立 RoleBinding `deploy-viewer-binding` 綁定該 SA。
3. 用 `kubectl auth can-i` 驗證該 SA 可 list deployments，**不可** delete deployments，將兩個結果（yes/no）依序寫入 `/opt/rbac-check.txt`。

---

## Q11 (9) 節點維護 + 靜態 Pod
1. 在 controlplane 節點建立靜態 Pod `static-web`（image `nginx:1.25`），manifest 放在 kubelet 的 static pod 目錄。
2. 找出 kubelet 的 static pod 目錄路徑，寫到 `/opt/static-path.txt`。
3. 將 worker 節點（若只有一個節點則略過此步）drain 後再 uncordon。

驗證：`k get pod static-web-<node>`；`cat /opt/static-path.txt`。

---

## Q12 (10) Sidecar + Pod 呼叫 API
在 namespace `rbac-lab` 建立 Pod `api-checker`，使用 SA `deploy-viewer`：
- 主容器 `app`：`busybox`，每 10 秒把日期 append 到 `/var/log/app/app.log`。
- 原生 sidecar `log`：`busybox`，`tail -F` 該檔案。
- 兩容器共享 emptyDir。
建立後，從 `app` 容器內用 SA token 呼叫 API server，列出 `rbac-lab` 的 deployments，將 HTTP 回應存到 `/opt/api-response.txt`（在 Pod 內取得後複製出來，或直接用 `k exec ... > /opt/api-response.txt`）。

驗證：`k -n rbac-lab get pod api-checker` → READY 2/2；`/opt/api-response.txt` 含 `"kind": "DeploymentList"`。

---

## 作答完畢檢查
- [ ] 每題的 namespace 都對
- [ ] 檔案路徑與檔名完全照題目
- [ ] 每題都用 get/describe 驗證過狀態
- [ ] 沒有留下測試用的暫時資源
