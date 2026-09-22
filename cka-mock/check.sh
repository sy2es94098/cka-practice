#!/usr/bin/env bash
# Auto-grader for cka-mock. Run after finishing: ./check.sh
k() { kubectl "$@" 2>/dev/null; }
TOTAL=0; SCORE=0
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; }
grade() { # $1=task name $2=points $3..=checks (each "desc|command")
  local name=$1 pts=$2; shift 2
  local ok=1
  echo "== $name ($pts pts)"
  for c in "$@"; do
    local desc=${c%%|*} cmd=${c#*|}
    if bash -c "$cmd" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; ok=0; fi
  done
  TOTAL=$((TOTAL+pts)); [ $ok = 1 ] && SCORE=$((SCORE+pts))
  echo
}

grade "Q1 Gateway API" 10 \
  "Gateway shop-gateway exists|kubectl -n web get gateway shop-gateway" \
  "uses nginx-class|[ \"\$(kubectl -n web get gateway shop-gateway -o jsonpath='{.spec.gatewayClassName}')\" = nginx-class ]" \
  "HTTPS listener on 443 with shop-tls|kubectl -n web get gateway shop-gateway -o json | grep -q '\"port\": *443' && kubectl -n web get gateway shop-gateway -o json | grep -q shop-tls && kubectl -n web get gateway shop-gateway -o json | grep -q Terminate" \
  "HTTPRoute shop-route -> web-svc:80|kubectl -n web get httproute shop-route -o json | grep -q '\"name\": *\"web-svc\"' && kubectl -n web get httproute shop-route -o json | grep -q '\"port\": *80'" \
  "HTTPRoute attached to shop-gateway|kubectl -n web get httproute shop-route -o json | grep -q '\"name\": *\"shop-gateway\"'" \
  "Ingress deleted|! kubectl -n web get ingress shop-ingress"

grade "Q2 Helm" 8 \
  "/opt/edge.yaml exists with 2 replicas|grep -q 'replicas: 2' /opt/edge.yaml" \
  "release edge installed in web|helm list -n web -q | grep -qx edge" \
  "deploy edge-nginx has 2 replicas|[ \"\$(kubectl -n web get deploy edge-nginx -o jsonpath='{.spec.replicas}')\" = 2 ]"

grade "Q3 PriorityClass" 8 \
  "batch-priority value 90000|[ \"\$(kubectl get pc batch-priority -o jsonpath='{.value}')\" = 90000 ]" \
  "not global default|[ \"\$(kubectl get pc batch-priority -o jsonpath='{.globalDefault}')\" != true ]" \
  "batch-worker uses it|[ \"\$(kubectl -n sched get deploy batch-worker -o jsonpath='{.spec.template.spec.priorityClassName}')\" = batch-priority ]"

grade "Q4 Resource scheduling" 8 \
  "3 replicas kept|[ \"\$(kubectl -n sched get deploy resource-hog -o jsonpath='{.spec.replicas}')\" = 3 ]" \
  "3 pods Running|[ \"\$(kubectl -n sched get pod -l app=resource-hog --field-selector=status.phase=Running --no-headers | wc -l)\" = 3 ]" \
  "no Pending pods|[ \"\$(kubectl -n sched get pod -l app=resource-hog --field-selector=status.phase=Pending --no-headers | wc -l)\" = 0 ]"

grade "Q5 PVC" 6 \
  "data-pvc Bound|[ \"\$(kubectl -n storage get pvc data-pvc -o jsonpath='{.status.phase}')\" = Bound ]" \
  "bound to data-pv|[ \"\$(kubectl -n storage get pvc data-pvc -o jsonpath='{.spec.volumeName}')\" = data-pv ]" \
  "data-pod Running with mount /data|[ \"\$(kubectl -n storage get pod data-pod -o jsonpath='{.status.phase}')\" = Running ] && kubectl -n storage get pod data-pod -o json | grep -q '\"mountPath\": *\"/data\"'"

grade "Q6 CRDs" 6 \
  "cert-manager-crds.txt has 3 lines|[ \"\$(grep -c cert-manager /opt/cert-manager-crds.txt)\" = 3 ]" \
  "crd-spec.txt has nested fields|grep -q secretName /opt/crd-spec.txt && grep -q dnsNames /opt/crd-spec.txt && grep -q issuerRef /opt/crd-spec.txt"

grade "Q7 HPA" 7 \
  "api-hpa exists targeting api|[ \"\$(kubectl -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.scaleTargetRef.name}')\" = api ]" \
  "min 2 max 6|[ \"\$(kubectl -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.minReplicas}')\" = 2 ] && [ \"\$(kubectl -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.maxReplicas}')\" = 6 ]" \
  "cpu 70%|kubectl -n hpa-lab get hpa api-hpa -o json | grep -q '\"averageUtilization\": *70'" \
  "scaleDown window 120|[ \"\$(kubectl -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}')\" = 120 ]"

grade "Q8 NetworkPolicy" 10 \
  "db-policy selects tier=db|[ \"\$(kubectl -n net-lab get netpol db-policy -o jsonpath='{.spec.podSelector.matchLabels.tier}')\" = db ]" \
  "db-policy from tier=backend only|[ \"\$(kubectl -n net-lab get netpol db-policy -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.tier}')\" = backend ] && [ \"\$(kubectl -n net-lab get netpol db-policy -o jsonpath='{.spec.ingress[0].from[1]}')\" = '' ]" \
  "backend-policy has 2 OR sources|[ \"\$(kubectl -n net-lab get netpol backend-policy -o jsonpath='{.spec.ingress[0].from[1]}')\" != '' ]" \
  "backend-policy has namespaceSelector team=ops|kubectl -n net-lab get netpol backend-policy -o json | grep -q '\"team\": *\"ops\"'" \
  "both on TCP 80|kubectl -n net-lab get netpol db-policy -o json | grep -q '\"port\": *80' && kubectl -n net-lab get netpol backend-policy -o json | grep -q '\"port\": *80'"

grade "Q9 Troubleshooting" 10 \
  "configmap app-config exists|kubectl -n web get cm app-config" \
  "2 pods Running|[ \"\$(kubectl -n web get pod -l app=broken-app --field-selector=status.phase=Running --no-headers | wc -l)\" = 2 ]" \
  "service selector fixed|[ \"\$(kubectl -n web get svc broken-svc -o jsonpath='{.spec.selector.app}')\" = broken-app ]" \
  "targetPort 80|[ \"\$(kubectl -n web get svc broken-svc -o jsonpath='{.spec.ports[0].targetPort}')\" = 80 ]" \
  "endpoints populated|[ -n \"\$(kubectl -n web get ep broken-svc -o jsonpath='{.subsets[0].addresses[0].ip}')\" ]"

grade "Q10 RBAC" 8 \
  "role deploy-reader exists|kubectl -n rbac-lab get role deploy-reader" \
  "rolebinding binds SA|kubectl -n rbac-lab get rolebinding deploy-viewer-binding -o json | grep -q deploy-viewer" \
  "SA can list deployments|kubectl auth can-i list deployments -n rbac-lab --as=system:serviceaccount:rbac-lab:deploy-viewer | grep -q yes" \
  "SA cannot delete deployments|kubectl auth can-i delete deployments -n rbac-lab --as=system:serviceaccount:rbac-lab:deploy-viewer | grep -q no" \
  "rbac-check.txt is yes/no|[ \"\$(sed -n 1p /opt/rbac-check.txt)\" = yes ] && [ \"\$(sed -n 2p /opt/rbac-check.txt)\" = no ]"

grade "Q11 Static Pod" 9 \
  "static-web pod exists|kubectl get pod -A --no-headers | grep -q '^default *static-web-'" \
  "static-path.txt has manifests dir|grep -q '/etc/kubernetes/manifests' /opt/static-path.txt" \
  "all nodes schedulable (uncordoned)|! kubectl get nodes --no-headers | grep -q SchedulingDisabled"

grade "Q12 Sidecar + API" 10 \
  "api-checker READY 2/2|kubectl -n rbac-lab get pod api-checker --no-headers | grep -q ' 2/2 '" \
  "uses SA deploy-viewer|[ \"\$(kubectl -n rbac-lab get pod api-checker -o jsonpath='{.spec.serviceAccountName}')\" = deploy-viewer ]" \
  "sidecar in initContainers with restartPolicy Always|[ \"\$(kubectl -n rbac-lab get pod api-checker -o jsonpath='{.spec.initContainers[?(@.name==\"log\")].restartPolicy}')\" = Always ]" \
  "api-response.txt has DeploymentList|grep -q DeploymentList /opt/api-response.txt"

echo "=================================="
echo "SCORE: $SCORE / $TOTAL   (pass >= 66)"
[ $SCORE -ge 66 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
