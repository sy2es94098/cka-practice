# Helm 練習題（12 題）

慣例：`k` = `kubectl`，`LAB` = helm-lab 目錄路徑。每題請先想清楚要用哪個子指令，再動手。

---

## 第一部分：基礎操作

### Task 1 — repo 與搜尋
1. 確認 `bitnami` repo 已加入並更新索引。
2. 找出 `bitnami/nginx` chart 目前最新的 **3 個 chart 版本**，把版本號寫到 `/tmp/t1-versions.txt`（一行一個）。

驗證：`cat /tmp/t1-versions.txt` 應有三行版本號。

---

### Task 2 — 查看 chart 預設值
把 `bitnami/nginx` 的預設 values 匯出到 `/tmp/t2-values.yaml`，並回答：`service.type` 的預設值是什麼？

驗證：`grep -n "type:" /tmp/t2-values.yaml | head`

---

### Task 3 — 基本安裝（指定 namespace、指定 chart 版本）
使用 `LAB/repo/webapp-1.1.0.tgz`，在 namespace `helm-lab` 安裝一個名為 `frontend` 的 release，要求：
- `replicaCount` = 3
- `configMessage` = `"frontend ready"`

驗證：
```bash
helm list -n helm-lab
k -n helm-lab get deploy frontend-webapp -o jsonpath='{.spec.replicas}'   # 3
k -n helm-lab get cm frontend-webapp -o jsonpath='{.data.message}'        # frontend ready
```

---

### Task 4 — 用 values 檔安裝
在 namespace `helm-lab` 用 `LAB/charts/webapp`（本地目錄）安裝名為 `backend` 的 release，透過一個 values 檔 `/tmp/t4-values.yaml` 設定：
- `service.type: NodePort`
- `image.tag: "1.26"`
- `resources.requests.memory: 128Mi`

驗證：
```bash
k -n helm-lab get svc backend-webapp -o jsonpath='{.spec.type}'                                  # NodePort
k -n helm-lab get deploy backend-webapp -o jsonpath='{.spec.template.spec.containers[0].image}'  # nginx:1.26
```

---

## 第二部分：真實考題類型

### Task 5 — helm template 存檔（真實考題）
不接觸集群，把 `LAB/repo/webapp-1.2.0.tgz` 以 release 名 `render-test`、namespace `team-a`、`replicaCount=5` 渲染成 manifest，存到 `/tmp/t5-manifest.yaml`。

驗證：
```bash
grep -c "kind:" /tmp/t5-manifest.yaml        # 3（Deployment、Service、ConfigMap）
grep "replicas:" /tmp/t5-manifest.yaml       # replicas: 5
grep "namespace:" /tmp/t5-manifest.yaml      # 思考：為什麼可能沒有 namespace 欄位？
helm list -A | grep render-test              # 應該沒有任何輸出
```

---

### Task 6 — 找出既有 release 資訊並升級
namespace `team-a` 有一個 release `shop`。
1. 找出它目前的 **chart 版本**、**revision 數**、以及安裝時使用者設定的 values，將 values 存到 `/tmp/t6-old-values.yaml`。
2. 將它升級到 chart 版本 `1.2.0`（`LAB/repo/webapp-1.2.0.tgz`），**保留原本的 values**，並額外把 `configMessage` 改為 `"shop v3"`。

驗證：
```bash
helm list -n team-a                                                  # CHART 欄為 webapp-1.2.0
k -n team-a get deploy shop-webapp -o jsonpath='{.spec.replicas}'    # 仍為 2
k -n team-a get cm shop-webapp -o jsonpath='{.data.message}'         # shop v3
```

---

### Task 7 — 回滾
升級後發現 `shop` 有問題，把它回滾到 **revision 1**（最初安裝的版本）。

驗證：
```bash
helm history shop -n team-a                                          # 最新一筆 description 含 Rollback to 1
k -n team-a get cm shop-webapp -o jsonpath='{.data.message}'         # shop v1
```

---

### Task 8 — 排錯壞掉的 release
namespace `team-b` 的 release `broken` Pod 起不來。找出原因並用 `helm upgrade` 修正，使 image tag 改回 `1.25`，其他設定不變。

驗證：
```bash
k -n team-b get pods           # Running
helm history broken -n team-b  # revision 2 deployed
```

---

### Task 9 — 移除 release 但保留紀錄；辨識非 helm 資源
namespace `legacy` 中：
1. 找出哪些 Deployment 是 Helm 管理、哪些不是。把非 Helm 管理的 Deployment 名稱寫到 `/tmp/t9-manual.txt`。
2. 解除安裝 Helm release `old-api`，但保留 release 歷史記錄。

驗證：
```bash
cat /tmp/t9-manual.txt                    # manual-app
helm list -n legacy --all                 # old-api 狀態 uninstalled
k -n legacy get deploy                    # 只剩 manual-app
```

---

### Task 10 — 安裝 ArgoCD 但不安裝 CRD（真實考題）
使用 `argo/argo-cd` chart，在 namespace `argocd`（不存在需建立）安裝名為 `argocd` 的 release，chart 版本請用 `helm search repo argo/argo-cd --versions` 列出的最新版，要求 **不要安裝 CRD**。
安裝前先用 `helm template` 把最終 manifest 存到 `/tmp/t10-argocd.yaml` 做確認。

驗證：
```bash
grep -c "CustomResourceDefinition" /tmp/t10-argocd.yaml    # 0
helm list -n argocd
```
（資源較大，kind 單節點可能拉 image 較久；本題重點在 flag 正確，Pod 是否全部 Running 不強求。）

---

## 第三部分：進階

### Task 11 — 修改 chart 本身
複製 `LAB/charts/webapp` 到 `/tmp/webapp-v2`，做以下修改後以 release 名 `custom` 安裝到 `helm-lab`：
1. `Chart.yaml` 版本改為 `2.0.0`。
2. 新增 values `ingress.enabled`（預設 `false`），當為 `true` 時渲染一個 Ingress（host 使用 values `ingress.host`）。
3. 用 `helm lint` 確認無錯誤。
4. 安裝時啟用 ingress，host 設為 `custom.local`。

驗證：
```bash
helm lint /tmp/webapp-v2
k -n helm-lab get ingress custom-webapp -o jsonpath='{.spec.rules[0].host}'   # custom.local
helm list -n helm-lab | grep custom                                          # webapp-2.0.0
```

---

### Task 12 — 綜合計時題（模擬考試，目標 5 分鐘）
1. 在 namespace `team-b` 用 `LAB/repo/webapp-1.2.0.tgz` 安裝 release `api`，`replicaCount=2`、`service.type=NodePort`。
2. 把該 release 實際部署的 manifest 匯出到 `/tmp/t12-manifest.yaml`。
3. 將 `api` 升級，只把 `replicaCount` 改為 4，其他值不變。
4. 列出集群中**所有 namespace** 的 release，存到 `/tmp/t12-releases.txt`。

驗證：
```bash
k -n team-b get deploy api-webapp -o jsonpath='{.spec.replicas}'   # 4
k -n team-b get svc api-webapp -o jsonpath='{.spec.type}'          # NodePort
grep -c "kind:" /tmp/t12-manifest.yaml                             # 3
cat /tmp/t12-releases.txt
```

---

## 自我檢核清單
- [ ] 每個 helm 指令都有帶 `-n`
- [ ] 知道 `--version` 是 chart 版本不是 app 版本
- [ ] `upgrade` 時知道要不要 `--reuse-values`
- [ ] 分得清 `helm template`（不碰集群）、`--dry-run`（會連集群驗證）、`helm get manifest`（已部署的）
- [ ] 找不到 chart 第一反應是 `helm repo update`
