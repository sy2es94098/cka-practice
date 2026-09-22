# CKA Mock Exam (12 tasks, 90 minutes recommended)

Original tasks modeled on frequently reported 2026 exam patterns and the CKA v1.35 curriculum.
Run `./setup.sh` first, then start the timer. `k` = `kubectl`. Verify each task yourself before opening solutions.md.

Scoring: points in parentheses, 100 total, 66 to pass.

---

## Q1 (10) Gateway API: migrate an Ingress to Gateway + HTTPRoute
Context: An Ingress named `shop-ingress` exists in the `web` namespace. The Gateway API CRDs are installed and a GatewayClass named `nginx-class` is available.

Task:
1. Create a Gateway named `shop-gateway` in the `web` namespace using GatewayClass `nginx-class`, with a single HTTPS listener: name `https`, port `443`, hostname `shop.example.com`, TLS mode `Terminate`, using the existing Secret `shop-tls`.
2. Create an HTTPRoute named `shop-route` in the `web` namespace attached to `shop-gateway`, matching hostname `shop.example.com` and path `/` (prefix), routing to Service `web-svc` on port `80`.
3. After the Gateway and HTTPRoute are created, delete the Ingress `shop-ingress`.

Verify: `k -n web get gateway,httproute`; `k -n web get ingress` should return no resources.

---

## Q2 (8) Helm: render manifests and install a specific chart version
Task:
1. Add the Helm repository `bitnami` with URL `https://charts.bitnami.com/bitnami`.
2. Using the **second-newest** version of the `bitnami/nginx` chart (the second row of `helm search repo --versions`), render the manifests with release name `edge`, namespace `web`, `replicaCount=2` and `service.type=ClusterIP`, and save the output to `/opt/edge.yaml`.
3. Install the release with the same parameters.

Verify: `helm list -n web`; `k -n web get deploy edge-nginx -o jsonpath='{.spec.replicas}'` returns `2`.

---

## Q3 (8) PriorityClass
Context: A PriorityClass named `high-priority` exists in the cluster.

Task:
1. Create a new PriorityClass named `batch-priority` whose value is exactly **10000 lower** than `high-priority`. It must not be the global default. Any description is acceptable.
2. Update the Deployment `batch-worker` in the `sched` namespace so that its Pods use `batch-priority`.

Verify: `k get pc batch-priority -o jsonpath='{.value}'` returns `90000`; `k -n sched get pod -l app=batch-worker -o jsonpath='{.items[0].spec.priorityClassName}'` returns `batch-priority`.

---

## Q4 (8) Resource scheduling
Context: The Deployment `resource-hog` in the `sched` namespace has 3 replicas. Some Pods remain in `Pending` because the container resource requests exceed the available node capacity.

Task: Inspect the allocatable resources on the nodes and adjust the container resource **requests** so that all 3 replicas are scheduled, while leaving at least **200m CPU and 256Mi memory** available on each node for system processes. Do **not** change the replica count and do **not** modify the nodes.

Verify: all Pods with label `app=resource-hog` in `sched` are `Running`; `k describe node` shows allocated resources within limits.

---

## Q5 (6) Bind a PVC to an existing PV
Context: A PersistentVolume named `data-pv` exists in the cluster.

Task:
1. Create a PersistentVolumeClaim named `data-pvc` in the `storage` namespace that binds to `data-pv`. Do not modify the PV.
2. Create a Pod named `data-pod` (image `nginx:1.25`) in the `storage` namespace that mounts `data-pvc` at `/data`.

Verify: `k -n storage get pvc data-pvc` shows `Bound`; `k -n storage get pod data-pod` shows `Running`.

---

## Q6 (6) CRDs
Task:
1. List all CustomResourceDefinitions whose name contains `cert-manager` and save the names to `/opt/cert-manager-crds.txt`.
2. Use `kubectl explain` to output the structure of the `spec` field (including nested fields) of the `Certificate` custom resource, and save it to `/opt/crd-spec.txt`.

Verify: `/opt/cert-manager-crds.txt` has 3 lines; `/opt/crd-spec.txt` contains `secretName`, `dnsNames` and `issuerRef`.

---

## Q7 (7) HorizontalPodAutoscaler
Task: Create an HPA named `api-hpa` in the `hpa-lab` namespace targeting the Deployment `api`, with a minimum of `2` and maximum of `6` replicas, scaling on an average CPU utilization of `70%`. Additionally, set the scale-down stabilization window to `120` seconds.

Verify: `k -n hpa-lab get hpa api-hpa`; `k -n hpa-lab get hpa api-hpa -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}'` returns `120`.
(TARGETS showing `<unknown>` is expected when metrics-server is not installed.)

---

## Q8 (10) NetworkPolicy
Context: The `net-lab` namespace contains Pods `frontend` (label `tier=frontend`), `backend` (`tier=backend`) and `db` (`tier=db`).

Task: Create two NetworkPolicies in `net-lab`:
1. `db-policy`: allow ingress to Pods with `tier=db` on TCP port `80` **only** from Pods with `tier=backend`. All other ingress must be denied.
2. `backend-policy`: allow ingress to Pods with `tier=backend` on TCP port `80` from Pods with `tier=frontend`, **and additionally** from any Pod in a namespace labeled `team=ops`. These two sources must be combined with OR semantics.

Verify: `k -n net-lab describe netpol`. Make sure you understand the difference between two selectors inside one `from` item (AND) and two separate `from` items (OR).

---

## Q9 (10) Troubleshoot a Deployment and Service
Context: In the `web` namespace, the Deployment `broken-app` has no running Pods and the Service `broken-svc` is unreachable.

Task: Identify and fix **all** issues so that the following command returns the nginx welcome page:
```
k -n web run t --rm -it --image=busybox --restart=Never -- wget -qO- broken-svc
```
Hint: there are at least three independent problems. Do not delete and recreate the Deployment or Service; fix them in place using edit or patch.

---

## Q10 (8) RBAC and ServiceAccount
Context: A ServiceAccount named `deploy-viewer` exists in the `rbac-lab` namespace.

Task:
1. Create a Role named `deploy-reader` in `rbac-lab` that allows `get`, `list` and `watch` on `deployments` (apps API group), and `get` and `list` on `pods`.
2. Create a RoleBinding named `deploy-viewer-binding` in `rbac-lab` that binds the Role to the ServiceAccount.
3. Using `kubectl auth can-i`, verify that the ServiceAccount **can** list deployments and **cannot** delete deployments in `rbac-lab`. Write the two results (`yes`/`no`), in that order, one per line, to `/opt/rbac-check.txt`.

---

## Q11 (9) Static Pod and node maintenance
Task:
1. On the controlplane node, create a static Pod named `static-web` (image `nginx:1.25`) by placing a manifest in the kubelet's static Pod directory.
2. Determine the kubelet's static Pod directory path and write it to `/opt/static-path.txt`.
3. Drain the worker node (skip this step if the cluster has only one node), then make it schedulable again with `uncordon`.

Verify: `k get pod static-web-<node-name>`; `cat /opt/static-path.txt`.

---

## Q12 (10) Native sidecar and in-cluster API access
Task: Create a Pod named `api-checker` in the `rbac-lab` namespace using the ServiceAccount `deploy-viewer`, with:
- A main container `app` (image `busybox`) that appends the current date to `/var/log/app/app.log` every 10 seconds.
- A **native sidecar** container `log` (image `busybox`) that runs `tail -F` on that file.
- Both containers share an `emptyDir` volume.

After the Pod is running, from inside the `app` container, call the Kubernetes API server using the mounted ServiceAccount token to list the Deployments in the `rbac-lab` namespace. Save the HTTP response body to `/opt/api-response.txt` (for example via `k exec ... > /opt/api-response.txt`).

Verify: `k -n rbac-lab get pod api-checker` shows READY `2/2`; `/opt/api-response.txt` contains `"kind": "DeploymentList"`.

---

## Final checklist
- [ ] Correct namespace on every task
- [ ] File paths and names exactly as specified
- [ ] Every task verified with `get` / `describe`
- [ ] No leftover temporary resources
