# 參考解答

---

## Q1 Gateway API
```bash
k -n web get ingress shop-ingress -o yaml    # 先看 host、tls secret、backend
```
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gateway
  namespace: web
spec:
  gatewayClassName: nginx-class
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: shop.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: shop-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
  namespace: web
spec:
  parentRefs:
  - name: shop-gateway
  hostnames: ["shop.example.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-svc
      port: 80
```
```bash
k apply -f gw.yaml
k -n web delete ingress shop-ingress
```
陷阱：Gateway API 的 path type 是 `PathPrefix`（Ingress 是 `Prefix`）；`certificateRefs` 是陣列；HTTP listener 用 `protocol: HTTP` port 80 且無 tls 區塊。文件搜尋 "Gateway API" → gateway-api.sigs.k8s.io 的 HTTPRoute 範例可直接改。

---

## Q2 Helm
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
helm search repo bitnami/nginx --versions | head -3      # 第 3 行（第 2 個資料列）是次新版
V=$(helm search repo bitnami/nginx --versions | awk 'NR==3{print $2}')
helm template edge bitnami/nginx --version $V -n web --set replicaCount=2 --set service.type=ClusterIP > /opt/edge.yaml
helm install edge bitnami/nginx --version $V -n web --set replicaCount=2 --set service.type=ClusterIP
```

---

## Q3 PriorityClass
```bash
k get pc high-priority -o jsonpath='{.value}'    # 100000
```
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-priority
value: 90000
globalDefault: false
description: "Batch workloads"
```
```bash
k apply -f pc.yaml
k -n sched patch deploy batch-worker -p '{"spec":{"template":{"spec":{"priorityClassName":"batch-priority"}}}}'
# 或 k -n sched edit deploy batch-worker，在 template.spec 加 priorityClassName
```
陷阱：`priorityClassName` 在 `spec.template.spec`，不是 `spec`；PriorityClass 是 cluster-scoped，沒有 namespace。

---

## Q4 資源排程
```bash
k describe node | grep -A6 "Allocatable"        # 例如 cpu: 2, memory: 1900Mi
k describe node | grep -A8 "Allocated resources" # 已用量
```
計算：可用 = Allocatable − 已用 − 保留(200m/256Mi)，再除以要放在該節點的 Pod 數。
以兩節點各 2 CPU/2Gi、3 個 Pod 為例（一節點 2 個、一節點 1 個），單 Pod request 需 ≤ (2000m − 已用 − 200m)/2 。保守設定：
```bash
k -n sched set resources deploy resource-hog -c app --requests=cpu=400m,memory=300Mi
k -n sched get pod -l app=resource-hog -w
```
陷阱：controlplane 節點通常有 taint，Pending 的 Pod 只能靠 worker；`k describe pod <pending>` 的 Events 會直接說 Insufficient cpu/memory。

---

## Q5 PVC
```bash
k get pv data-pv    # 2Gi, RWO, storageClassName manual
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: storage
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
  namespace: storage
spec:
  containers:
  - name: web
    image: nginx:1.25
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
```
陷阱：storageClassName 必須完全一致（PV 沒設時 PVC 也要不設或設 `""`）；請求容量 ≤ PV 容量；accessMode 必須是 PV 支援的子集。

---

## Q6 CRD
```bash
k get crd | grep cert-manager | awk '{print $1}' > /opt/cert-manager-crds.txt
# 或 k get crd -o name | grep cert-manager
k explain certificates.cert-manager.io.spec --recursive > /opt/crd-spec.txt
# 或 k explain certificate.spec --recursive
```
陷阱：同名 kind 有多個 group 時用完整 `<plural>.<group>` 避免歧義；`--recursive` 才會展開子欄位。

---

## Q7 HPA
```bash
k -n hpa-lab autoscale deploy api --name=api-hpa --min=2 --max=6 --cpu-percent=70
k -n hpa-lab edit hpa api-hpa       # 加入 behavior
```
```yaml
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120
```
完整 YAML 版本：
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120
```
陷阱：`autoscaling/v2` 才有 `behavior`；目標 Deployment 的容器必須有 CPU request，否則 HPA 算不出百分比。

---

## Q8 NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: net-lab
spec:
  podSelector:
    matchLabels: {tier: db}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels: {tier: backend}
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: net-lab
spec:
  podSelector:
    matchLabels: {tier: backend}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels: {tier: frontend}
    - namespaceSelector:
        matchLabels: {team: ops}
    ports:
    - protocol: TCP
      port: 80
```
AND / OR 關鍵：
```yaml
# OR：兩個 list 項目（各有 -）
- from:
  - podSelector: {...}
  - namespaceSelector: {...}

# AND：同一個項目內兩個 selector（只有一個 -）
- from:
  - podSelector: {...}
    namespaceSelector: {...}
```
陷阱：沒寫 `policyTypes` 時只有出現的區塊生效；`ingress: []` 與不寫 `ingress` 意義不同（前者全拒）。

---

## Q9 排錯
```bash
k -n web get pod -l app=broken-app          # CreateContainerConfigError
k -n web describe pod <pod> | tail          # configmap "app-config" not found
```
問題 1：ConfigMap 不存在
```bash
k -n web create cm app-config --from-literal=db_host=db.web.svc
```
問題 2：Service selector 打錯（`broken-ap`）
```bash
k -n web patch svc broken-svc -p '{"spec":{"selector":{"app":"broken-app"}}}'
```
問題 3：targetPort 8080，容器聽 80
```bash
k -n web patch svc broken-svc -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```
驗證：
```bash
k -n web get ep broken-svc                  # 應有兩個 Pod IP
k -n web run t --rm -it --image=busybox --restart=Never -- wget -qO- broken-svc
```
排錯順序：Pod 狀態 → describe Events → Service selector 對 Pod labels → endpoints 是否為空 → port/targetPort。

---

## Q10 RBAC
```bash
k -n rbac-lab create role deploy-reader \
  --verb=get,list,watch --resource=deployments.apps \
  --verb=get,list --resource=pods
```
`create role` 不能對不同資源給不同 verb，上面會把所有 verb 套到兩種資源。題目嚴格要求時用 YAML：
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deploy-reader
  namespace: rbac-lab
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get","list","watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list"]
```
```bash
k -n rbac-lab create rolebinding deploy-viewer-binding --role=deploy-reader --serviceaccount=rbac-lab:deploy-viewer
k auth can-i list deployments -n rbac-lab --as=system:serviceaccount:rbac-lab:deploy-viewer > /opt/rbac-check.txt
k auth can-i delete deployments -n rbac-lab --as=system:serviceaccount:rbac-lab:deploy-viewer >> /opt/rbac-check.txt
cat /opt/rbac-check.txt   # yes / no
```
陷阱：deployments 屬 `apps` group，apiGroups 寫 `""` 會無效；`can-i` 回 no 時 exit code 為 1，用 `>>` 仍會寫入。

---

## Q11 靜態 Pod + drain
```bash
ssh controlplane; sudo -i
grep staticPodPath /var/lib/kubelet/config.yaml        # /etc/kubernetes/manifests
echo /etc/kubernetes/manifests > /opt/static-path.txt   # 若 /opt 在 base，回 base 再寫
k run static-web --image=nginx:1.25 --dry-run=client -o yaml > /etc/kubernetes/manifests/static-web.yaml
exit
k get pod -A | grep static-web        # static-web-controlplane
k drain node01 --ignore-daemonsets --delete-emptydir-data
k get node                             # SchedulingDisabled
k uncordon node01
```
陷阱：靜態 Pod 名稱會自動加上 `-<node>`；刪除靜態 Pod 只能刪 manifest 檔；drain 卡住通常是 DaemonSet 或 emptyDir。

---

## Q12 Sidecar + API 呼叫
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-checker
  namespace: rbac-lab
spec:
  serviceAccountName: deploy-viewer
  initContainers:
  - name: log
    image: busybox
    restartPolicy: Always
    command: ['sh','-c','touch /var/log/app/app.log; tail -F /var/log/app/app.log']
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  containers:
  - name: app
    image: busybox
    command: ['sh','-c','while true; do date >> /var/log/app/app.log; sleep 10; done']
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```
```bash
k apply -f pod.yaml
k -n rbac-lab exec api-checker -c app -- sh -c '
  SA=/var/run/secrets/kubernetes.io/serviceaccount
  wget -qO- --ca-certificate=$SA/ca.crt \
    --header="Authorization: Bearer $(cat $SA/token)" \
    https://kubernetes.default.svc/apis/apps/v1/namespaces/rbac-lab/deployments' > /opt/api-response.txt
grep kind /opt/api-response.txt      # "kind": "DeploymentList"
```
陷阱：deployments 的 API 路徑是 `/apis/apps/v1/...`，pods 才是 `/api/v1/...`；busybox 用 `wget` 沒有 `curl`；`--ca-certificate` 是 wget 的參數（curl 是 `--cacert`）；若回 403 代表 Q10 的 RBAC 沒做對。

---

## 評分後的復習建議
| 失分題 | 回頭複習 |
|---|---|
| Q1 | gateway-api.sigs.k8s.io 的 HTTPRoute / Gateway 範例，練到不看文件寫出骨架 |
| Q4 | `k describe node` 的 Allocatable vs Allocated，練心算 |
| Q8 | 官方 NetworkPolicy 文件的 AND/OR 範例段落 |
| Q9 | 排錯順序表：Pod → Events → Service selector → Endpoints → port |
| Q12 | SA token 路徑、API 路徑 /api vs /apis |
