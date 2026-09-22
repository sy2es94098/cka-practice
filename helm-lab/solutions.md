# 參考解答

`LAB` 請換成實際路徑，例如 `~/helm-lab`。

---

## Task 1
```bash
helm repo list
helm repo update
helm search repo bitnami/nginx --versions | awk 'NR>1{print $2}' | head -3 > /tmp/t1-versions.txt
```
重點：`--versions` 才會列出所有版本；第二欄是 CHART VERSION，第三欄才是 APP VERSION。

---

## Task 2
```bash
helm show values bitnami/nginx > /tmp/t2-values.yaml
grep -A3 "^service:" /tmp/t2-values.yaml
```
Bitnami nginx 的 `service.type` 預設是 `LoadBalancer`。

---

## Task 3
```bash
helm install frontend LAB/repo/webapp-1.1.0.tgz -n helm-lab \
  --set replicaCount=3 \
  --set configMessage="frontend ready"
```
若題目給的是 repo 內的 chart，則是 `helm install frontend <repo>/webapp --version 1.1.0 -n helm-lab ...`。
namespace 不存在時加 `--create-namespace`。

---

## Task 4
```bash
cat > /tmp/t4-values.yaml << 'YAML'
service:
  type: NodePort
image:
  tag: "1.26"
resources:
  requests:
    memory: 128Mi
YAML
helm install backend LAB/charts/webapp -n helm-lab -f /tmp/t4-values.yaml
```
`-f` 可重複，後面的覆蓋前面的；`--set` 優先權高於 `-f`。

---

## Task 5
```bash
helm template render-test LAB/repo/webapp-1.2.0.tgz -n team-a --set replicaCount=5 > /tmp/t5-manifest.yaml
```
- `helm template` 純本地渲染，不會建立 release，`helm list` 看不到。
- 多數 chart 的模板不寫 `metadata.namespace`，因為 Helm 安裝時會自動帶上 `-n` 的 namespace；所以渲染出的檔案裡可能沒有 namespace 欄位，之後若要 `kubectl apply` 需自己加 `-n`。
- 若題目要求「輸出包含 namespace」，可加 `--namespace team-a` 並確認 chart 有使用 `.Release.Namespace`，否則需手動補。

---

## Task 6
```bash
helm list -n team-a                        # CHART: webapp-1.1.0
helm history shop -n team-a                # 2 個 revision
helm get values shop -n team-a > /tmp/t6-old-values.yaml

helm upgrade shop LAB/repo/webapp-1.2.0.tgz -n team-a \
  --reuse-values \
  --set configMessage="shop v3"
```
關鍵：不加 `--reuse-values` 的話，`replicaCount` 會退回 chart 預設值 1。另一種做法是 `-f /tmp/t6-old-values.yaml --set configMessage="shop v3"`。

---

## Task 7
```bash
helm rollback shop 1 -n team-a
helm history shop -n team-a
```
回滾會產生新的 revision（例如 revision 4），內容等同 revision 1。不指定數字則回到上一版。

---

## Task 8
```bash
k -n team-b get pods                      # ImagePullBackOff / ErrImagePull
k -n team-b describe pod <pod> | tail     # Failed to pull image "nginx:does-not-exist"
helm get values broken -n team-b          # image.tag: does-not-exist

helm upgrade broken LAB/repo/webapp-1.0.0.tgz -n team-b --reuse-values --set image.tag=1.25
# 或直接不帶 --reuse-values 讓 tag 回到 chart 預設值 1.25：
# helm upgrade broken LAB/repo/webapp-1.0.0.tgz -n team-b
```
考試若不知道 release 用哪個 chart：`helm list -n team-b` 的 CHART 欄告訴你 chart 名與版本。

---

## Task 9
```bash
# 方法一：看 label
k -n legacy get deploy -L app.kubernetes.io/managed-by
# 方法二：看 helm 有哪些 release，反推
helm list -n legacy
echo manual-app > /tmp/t9-manual.txt

helm uninstall old-api -n legacy --keep-history
helm list -n legacy --all                 # STATUS: uninstalled
```
Helm 管理的資源會帶 label `app.kubernetes.io/managed-by=Helm` 以及 annotation `meta.helm.sh/release-name`。

---

## Task 10
```bash
helm repo update
helm search repo argo/argo-cd --versions | head
k create ns argocd

helm template argocd argo/argo-cd -n argocd --version <最新版> --skip-crds > /tmp/t10-argocd.yaml
grep -c CustomResourceDefinition /tmp/t10-argocd.yaml     # 0

helm install argocd argo/argo-cd -n argocd --version <最新版> --skip-crds
```
- `--skip-crds` 跳過 chart `crds/` 目錄裡的 CRD。
- argo-cd chart 另外有 values `crds.install`，若題目用 values 描述，則 `--set crds.install=false`。兩者都做最保險。
- 真實考題通常會給 namespace、release 名、chart 版本，並要求先 `helm template` 存檔再 install。

---

## Task 11
```bash
cp -r LAB/charts/webapp /tmp/webapp-v2
sed -i 's/^version: .*/version: 2.0.0/' /tmp/webapp-v2/Chart.yaml

cat >> /tmp/webapp-v2/values.yaml << 'YAML'

ingress:
  enabled: false
  host: webapp.local
YAML

cat > /tmp/webapp-v2/templates/ingress.yaml << 'YAML'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "webapp.fullname" . }}
  labels:
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "webapp.fullname" . }}
            port:
              number: {{ .Values.service.port }}
{{- end }}
YAML

helm lint /tmp/webapp-v2
helm template x /tmp/webapp-v2 --set ingress.enabled=true | grep -A5 "kind: Ingress"
helm install custom /tmp/webapp-v2 -n helm-lab --set ingress.enabled=true --set ingress.host=custom.local
```
`{{- if }}` 包住整個檔案時，`enabled: false` 會渲染成空檔，Helm 會自動略過。

---

## Task 12
```bash
helm install api LAB/repo/webapp-1.2.0.tgz -n team-b --set replicaCount=2 --set service.type=NodePort
helm get manifest api -n team-b > /tmp/t12-manifest.yaml
helm upgrade api LAB/repo/webapp-1.2.0.tgz -n team-b --reuse-values --set replicaCount=4
helm list -A > /tmp/t12-releases.txt
```

---

## 常見錯誤回顧
| 症狀 | 原因 | 解法 |
|---|---|---|
| `Error: release: not found` | 沒帶 `-n` 或 namespace 錯 | `helm list -A` 找到正確 namespace |
| `chart "x" not found in repo` | 索引舊或 repo 沒加 | `helm repo update` / `helm repo add` |
| upgrade 後設定全消失 | 沒 `--reuse-values` 或 `-f` | 加回去，或先 `helm get values` 存檔 |
| `cannot re-use a name that is still in use` | release 名已存在 | 換名字或改用 `helm upgrade --install` |
| `namespaces "x" not found` | namespace 不存在 | `--create-namespace` 或先 `k create ns` |
| Pod 在但 helm list 看不到 | 資源不是 Helm 管的，或 release 在別的 ns | 看 label `app.kubernetes.io/managed-by` |
