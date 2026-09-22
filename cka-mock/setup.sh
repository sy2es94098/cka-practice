#!/usr/bin/env bash
# CKA 模擬題環境佈置（在 Killercoda Kubernetes playground 或 kind 上執行）
set -e
k() { kubectl "$@"; }

echo "==> namespaces"
for ns in web storage sched rbac-lab net-lab hpa-lab crd-lab; do
  k create ns $ns --dry-run=client -o yaml | k apply -f - >/dev/null
done

echo "==> Q1: 既有 Ingress（供 Gateway API 轉換）"
k -n web create deploy web --image=nginx:1.25 --port=80 --dry-run=client -o yaml | k apply -f - >/dev/null
k -n web expose deploy web --port=80 --name=web-svc --dry-run=client -o yaml | k apply -f - >/dev/null
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -subj "/CN=shop.example.com" \
  -keyout /tmp/tls.key -out /tmp/tls.crt >/dev/null 2>&1
k -n web create secret tls shop-tls --cert=/tmp/tls.crt --key=/tmp/tls.key --dry-run=client -o yaml | k apply -f - >/dev/null
cat <<Y | k apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ingress
  namespace: web
spec:
  tls:
  - hosts: [shop.example.com]
    secretName: shop-tls
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
Y
# 安裝 Gateway API CRD（standard channel）
k apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml >/dev/null 2>&1 || echo "   (Gateway API CRD 安裝失敗，Q1 需手動安裝)"
cat <<Y | k apply -f - >/dev/null
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx-class
spec:
  controllerName: example.com/nginx-gateway
Y

echo "==> Q3: 既有 PriorityClass"
cat <<Y | k apply -f - >/dev/null
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 100000
globalDefault: false
description: "Existing high priority class"
Y
k -n sched create deploy batch-worker --image=busybox --replicas=1 --dry-run=client -o yaml \
  | sed 's/resources: {}/command: ["sleep","3600"]/' | k apply -f - >/dev/null

echo "==> Q4: Pending 的 Deployment（request 過大）"
cat <<Y | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
  namespace: sched
spec:
  replicas: 3
  selector: {matchLabels: {app: resource-hog}}
  template:
    metadata: {labels: {app: resource-hog}}
    spec:
      containers:
      - name: app
        image: nginx:1.25
        resources:
          requests: {cpu: "1500m", memory: "1500Mi"}
Y

echo "==> Q5: 既有 PV（供 PVC 綁定）"
cat <<Y | k apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  capacity: {storage: 2Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /mnt/data-pv}
Y

echo "==> Q6: CRD 環境（模擬 cert-manager 類 CRD）"
for n in certificates issuers clusterissuers; do
cat <<Y | k apply -f - >/dev/null
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: $n.cert-manager.io
spec:
  group: cert-manager.io
  scope: Namespaced
  names: {plural: $n, singular: ${n%s}, kind: $(echo ${n%s} | sed 's/./\U&/')}
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              secretName: {type: string, description: "Name of the secret to store the cert"}
              dnsNames: {type: array, items: {type: string}}
              issuerRef:
                type: object
                properties:
                  name: {type: string}
                  kind: {type: string}
Y
done

echo "==> Q7: HPA 目標 Deployment"
cat <<Y | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: hpa-lab
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - name: api
        image: nginx:1.25
        resources:
          requests: {cpu: "100m"}
Y

echo "==> Q8: NetworkPolicy 環境"
k -n net-lab run frontend --image=nginx:1.25 -l tier=frontend >/dev/null
k -n net-lab run backend --image=nginx:1.25 -l tier=backend --port=80 >/dev/null
k -n net-lab run db --image=nginx:1.25 -l tier=db --port=80 >/dev/null
k -n net-lab expose pod backend --port=80 >/dev/null
k -n net-lab expose pod db --port=80 >/dev/null

echo "==> Q9: 壞掉的 Deployment"
cat <<Y | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: web
spec:
  replicas: 2
  selector: {matchLabels: {app: broken-app}}
  template:
    metadata: {labels: {app: broken-app}}
    spec:
      containers:
      - name: app
        image: nginx:1.25
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef: {name: app-config, key: db_host}
        ports: [{containerPort: 80}]
Y
cat <<Y | k apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: broken-svc
  namespace: web
spec:
  selector: {app: broken-ap}
  ports: [{port: 80, targetPort: 8080}]
Y

echo "==> Q10: RBAC 環境"
k -n rbac-lab create sa deploy-viewer >/dev/null

echo
echo "佈置完成。開啟 questions.md 開始計時作答。"
