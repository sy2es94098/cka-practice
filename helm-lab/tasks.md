# Helm Practice Tasks (12 tasks)

Conventions: `k` = `kubectl`; `LAB` = path to the helm-lab directory. Decide which subcommand you need before typing.

---

## Part 1: Fundamentals

### Task 1 — Repositories and search
1. Ensure the `bitnami` repository is added and its index is up to date.
2. Find the **3 newest chart versions** of `bitnami/nginx` and write them to `/tmp/t1-versions.txt`, one per line.

Verify: `cat /tmp/t1-versions.txt` shows three version numbers.

---

### Task 2 — Inspect default values
Export the default values of `bitnami/nginx` to `/tmp/t2-values.yaml`. What is the default value of `service.type`?

Verify: `grep -n "type:" /tmp/t2-values.yaml | head`

---

### Task 3 — Install with a specific namespace and chart version
Using `LAB/repo/webapp-1.1.0.tgz`, install a release named `frontend` in the `helm-lab` namespace with:
- `replicaCount` = `3`
- `configMessage` = `"frontend ready"`

Verify:
```bash
helm list -n helm-lab
k -n helm-lab get deploy frontend-webapp -o jsonpath='{.spec.replicas}'   # 3
k -n helm-lab get cm frontend-webapp -o jsonpath='{.data.message}'        # frontend ready
```

---

### Task 4 — Install with a values file
Install the local chart directory `LAB/charts/webapp` as a release named `backend` in `helm-lab`, using a values file `/tmp/t4-values.yaml` that sets:
- `service.type: NodePort`
- `image.tag: "1.26"`
- `resources.requests.memory: 128Mi`

Verify:
```bash
k -n helm-lab get svc backend-webapp -o jsonpath='{.spec.type}'                                  # NodePort
k -n helm-lab get deploy backend-webapp -o jsonpath='{.spec.template.spec.containers[0].image}'  # nginx:1.26
```

---

## Part 2: Exam-style tasks

### Task 5 — Render manifests with `helm template` (exam pattern)
Without contacting the cluster, render `LAB/repo/webapp-1.2.0.tgz` with release name `render-test`, namespace `team-a` and `replicaCount=5`, and save the output to `/tmp/t5-manifest.yaml`.

Verify:
```bash
grep -c "kind:" /tmp/t5-manifest.yaml        # 3 (Deployment, Service, ConfigMap)
grep "replicas:" /tmp/t5-manifest.yaml       # replicas: 5
grep "namespace:" /tmp/t5-manifest.yaml      # Think: why might there be no namespace field?
helm list -A | grep render-test              # must return nothing
```

---

### Task 6 — Inspect an existing release and upgrade it
A release named `shop` exists in the `team-a` namespace.
1. Determine its current **chart version** and **number of revisions**, and save the user-supplied values to `/tmp/t6-old-values.yaml`.
2. Upgrade it to chart version `1.2.0` (`LAB/repo/webapp-1.2.0.tgz`), **preserving the existing values**, and additionally set `configMessage` to `"shop v3"`.

Verify:
```bash
helm list -n team-a                                                  # CHART column shows webapp-1.2.0
k -n team-a get deploy shop-webapp -o jsonpath='{.spec.replicas}'    # still 2
k -n team-a get cm shop-webapp -o jsonpath='{.data.message}'         # shop v3
```

---

### Task 7 — Rollback
The upgrade of `shop` caused problems. Roll it back to **revision 1** (the original installation).

Verify:
```bash
helm history shop -n team-a                                          # latest entry description contains "Rollback to 1"
k -n team-a get cm shop-webapp -o jsonpath='{.data.message}'         # shop v1
```

---

### Task 8 — Fix a broken release
The Pods of release `broken` in the `team-b` namespace fail to start. Find the cause and fix it with `helm upgrade` so that the image tag becomes `1.25`, leaving all other settings unchanged.

Verify:
```bash
k -n team-b get pods           # Running
helm history broken -n team-b  # revision 2 deployed
```

---

### Task 9 — Uninstall with history; identify non-Helm resources
In the `legacy` namespace:
1. Determine which Deployments are managed by Helm and which are not. Write the name(s) of the non-Helm Deployment(s) to `/tmp/t9-manual.txt`.
2. Uninstall the Helm release `old-api` while keeping its release history.

Verify:
```bash
cat /tmp/t9-manual.txt                    # manual-app
helm list -n legacy --all                 # old-api status uninstalled
k -n legacy get deploy                    # only manual-app remains
```

---

### Task 10 — Install Argo CD without CRDs (exam pattern)
Using the `argo/argo-cd` chart, install a release named `argocd` in the `argocd` namespace (create it if it does not exist). Use the newest chart version listed by `helm search repo argo/argo-cd --versions`. The CRDs must **not** be installed.
Before installing, render the final manifests with `helm template` to `/tmp/t10-argocd.yaml` for review.

Verify:
```bash
grep -c "CustomResourceDefinition" /tmp/t10-argocd.yaml    # 0
helm list -n argocd
```
(This chart is large; on a small single-node cluster image pulls may be slow. The goal is correct flags, not all Pods Running.)

---

## Part 3: Advanced

### Task 11 — Modify the chart
Copy `LAB/charts/webapp` to `/tmp/webapp-v2` and make the following changes, then install it as release `custom` in `helm-lab`:
1. Set the chart version in `Chart.yaml` to `2.0.0`.
2. Add a value `ingress.enabled` (default `false`). When `true`, render an Ingress whose host comes from `ingress.host`.
3. Run `helm lint` and ensure there are no errors.
4. Install with ingress enabled and host `custom.local`.

Verify:
```bash
helm lint /tmp/webapp-v2
k -n helm-lab get ingress custom-webapp -o jsonpath='{.spec.rules[0].host}'   # custom.local
helm list -n helm-lab | grep custom                                          # webapp-2.0.0
```

---

### Task 12 — Timed combined task (target: 5 minutes)
1. In the `team-b` namespace, install release `api` from `LAB/repo/webapp-1.2.0.tgz` with `replicaCount=2` and `service.type=NodePort`.
2. Export the manifests actually deployed for that release to `/tmp/t12-manifest.yaml`.
3. Upgrade `api` changing **only** `replicaCount` to `4`; all other values must remain unchanged.
4. List the releases in **all namespaces** and save the output to `/tmp/t12-releases.txt`.

Verify:
```bash
k -n team-b get deploy api-webapp -o jsonpath='{.spec.replicas}'   # 4
k -n team-b get svc api-webapp -o jsonpath='{.spec.type}'          # NodePort
grep -c "kind:" /tmp/t12-manifest.yaml                             # 3
cat /tmp/t12-releases.txt
```

---

## Self-check
- [ ] Every helm command includes `-n`
- [ ] You know `--version` refers to the chart version, not the app version
- [ ] You know when `upgrade` needs `--reuse-values`
- [ ] You can distinguish `helm template` (offline), `--dry-run` (server-side validation) and `helm get manifest` (deployed)
- [ ] First reaction to "chart not found" is `helm repo update`
