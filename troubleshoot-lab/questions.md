# Troubleshooting Scenarios

Run the matching break script as root on the indicated node, then solve. Do not read the break script before solving. Suggested time per scenario in parentheses.

---

## Scenario 1 (10 min) — `breaks/01-apiserver-etcd-endpoint.sh` on controlplane
Context: Last night the platform team migrated this cluster to a dedicated external etcd. Since then every `kubectl` command fails with `connection refused`. The team insists etcd itself is healthy and reachable at `https://127.0.0.1:2379`.

Task: Identify the failing control plane component, find the root cause, fix the configuration, and restore cluster operation. Do not reboot the node.

Verify: `kubectl get nodes` returns Ready; `kubectl -n kube-system get pod -l component=kube-apiserver` shows Running.

---

## Scenario 2 (8 min) — `breaks/02-scheduler-typo.sh` on controlplane
Context: Developers report that newly created Pods stay in `Pending` forever. Existing Pods run fine and `kubectl` works.

Task: Find the broken component and fix it so that new Pods get scheduled.

Verify: `kubectl run test --image=nginx` becomes Running; `kubectl -n kube-system get pod -l component=kube-scheduler` shows Running with no further restarts.

---

## Scenario 3 (10 min) — `breaks/03-apiserver-cert-path.sh` on controlplane
Context: A certificate rotation job ran on the controlplane. Afterwards `kubectl` returns `connection refused`. `crictl ps -a` shows the kube-apiserver container exiting repeatedly while the kubelet service is active.

Task: Restore the API server.

Verify: `kubectl get --raw='/readyz'` returns `ok`.

---

## Scenario 4 (10 min) — `breaks/04-kubelet-static-path.sh` on controlplane
Context: After a kubelet configuration change, `kubectl` fails and `crictl ps -a` shows **no** control plane containers at all, not even exited ones. The kubelet service is active.

Task: Find out why the kubelet is not starting the control plane and fix it.

Verify: `crictl ps` lists etcd, kube-apiserver, kube-controller-manager and kube-scheduler; `kubectl get nodes` works.

---

## Scenario 5 (12 min) — `breaks/05-etcd-data-dir.sh` on controlplane
Context: A colleague performed an etcd "restore" this morning. Now `kubectl` either fails or the cluster appears to have lost all its workloads.

Task: Investigate the etcd static Pod, identify what changed, and bring the cluster back with its original data. The original data must not be lost.

Verify: `kubectl get pods -A` shows the workloads that existed before (e.g. CoreDNS, kube-proxy); `kubectl -n kube-system get pod -l component=etcd` is Running.

---

## Scenario 6 (6 min) — `breaks/06-kubelet-stopped-worker.sh` on **node01**
Context: Node `node01` reports `NotReady`.

Task: Find the cause and make the node Ready again. Ensure the fix survives a node reboot.

Verify: `kubectl get nodes` shows node01 Ready; on node01 `systemctl is-enabled kubelet` returns `enabled`.

---

## Scenario 7 (8 min) — `breaks/07-controller-manager-image.sh` on controlplane
Context: `kubectl create deployment` succeeds but no ReplicaSet or Pods are ever created. `kubectl` itself works normally.

Task: Identify the failing component and fix it.

Verify: `kubectl create deploy probe --image=nginx` produces a Running Pod within a minute.

---

## Scenario 8 (6 min) — `breaks/08-containerd-stopped.sh` on **node01**
Context: `node01` is `NotReady`. The kubelet service on the node is active, but its logs are full of errors.

Task: Fix the node.

Verify: `kubectl get nodes` shows node01 Ready.

---

## Scenario 9 (8 min) — `breaks/09-apiserver-port.sh` on controlplane
Context: `kubectl` fails with `connection refused` to `:6443`, but `crictl ps` shows kube-apiserver **Running** and its logs show no errors.

Task: Explain why kubectl cannot connect and fix it (the kubeconfig must not be changed).

Verify: `kubectl get nodes` works with the unchanged `/etc/kubernetes/admin.conf`.

---

## Scenario 10 (10 min) — `breaks/10-kubelet-client-ca.sh` on controlplane
Context: `kubectl` fails. `systemctl status kubelet` shows the service is **not** running and keeps restarting.

Task: Fix the kubelet so that the control plane comes back.

Verify: `systemctl is-active kubelet` returns `active`; `kubectl get nodes` works.

---

## Combo (15 min) — run `01`, `02` and `06` together
Context: Multiple things broke during a maintenance window. `kubectl` is down, and once it is back you will find more problems.

Task: Restore the cluster to a fully healthy state: API reachable, all control plane Pods Running, all nodes Ready, new Pods schedulable.

Verify: `kubectl get nodes` all Ready; `kubectl run c --image=nginx` becomes Running.

---

## Exam-day checklist for this task type
- [ ] Checked `systemctl status kubelet` first
- [ ] Used `crictl ps -a` (with `-a`, to see Exited containers)
- [ ] Read the **last lines** of `crictl logs` or `/var/log/pods/...` before touching anything
- [ ] Changed exactly one thing, then waited 30s and re-checked
- [ ] Verified the full chain: nodes Ready, kube-system Pods Running, a test Pod schedules
