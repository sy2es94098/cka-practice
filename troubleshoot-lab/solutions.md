# Solutions

每題都遵循 playbook 的順序：kubelet → crictl ps -a → logs → manifest → 改一處 → 等 → 驗證。

---

## Scenario 1 — apiserver 指向錯誤的 etcd 位址
```bash
systemctl status kubelet                              # active，排除 kubelet
crictl ps -a | grep kube-apiserver                    # Exited，反覆重啟
crictl logs $(crictl ps -a --name kube-apiserver -q | head -1) | tail -20
# → "context deadline exceeded" / "dial tcp 10.99.99.99:2379: connect: connection refused"
grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
# 對照題目：etcd 在 127.0.0.1:2379
sed -i 's#https://10.99.99.99:2379#https://127.0.0.1:2379#' /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 30; crictl ps | grep kube-apiserver; kubectl get nodes
```
外部 etcd 版本的差異：位址會是另一台機器的 IP，先 `curl -k --cert ... https://<ip>:2379/health` 確認 etcd 真的活著，再判斷是 apiserver 設定錯還是 etcd 端真的掛。題目說「etcd 是好的」通常就是暗示要改 apiserver 這邊。

---

## Scenario 2 — scheduler kubeconfig typo
```bash
kubectl -n kube-system get pods                        # kube-scheduler CrashLoopBackOff
kubectl -n kube-system logs kube-scheduler-controlplane
# → "open /etc/kubernetes/schedular.conf: no such file or directory"
ls /etc/kubernetes/*.conf                              # 正確檔名是 scheduler.conf
sed -i 's#schedular.conf#scheduler.conf#' /etc/kubernetes/manifests/kube-scheduler.yaml
kubectl run test --image=nginx && kubectl get pod test -w
```
kubectl 能用時，`kubectl logs` 比 crictl 方便；但 Pod 若卡在 CreateContainerError 沒 log，就回到 `crictl ps -a` + `crictl logs`。

---

## Scenario 3 — apiserver etcd client cert 路徑錯
```bash
crictl logs $(crictl ps -a --name kube-apiserver -q | head -1) | tail -5
# → "open /etc/kubernetes/pki/apiserver-etcd-client.pem: no such file or directory"
ls /etc/kubernetes/pki/ | grep etcd-client             # 實際是 .crt
grep -n -- '--etcd-certfile' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i 's#apiserver-etcd-client.pem#apiserver-etcd-client.crt#' /etc/kubernetes/manifests/kube-apiserver.yaml
```
憑證類錯誤的通則：錯誤訊息裡的路徑拿去 `ls -l`，不存在就是 typo，存在就用 `openssl x509 -in <file> -noout -dates` 看是否過期。

---

## Scenario 4 — kubelet staticPodPath 錯
```bash
systemctl status kubelet                               # active
crictl ps -a                                            # 空的或只有非 control plane 容器
journalctl -u kubelet -n 50 --no-pager | grep -i static
# 或直接：
grep staticPodPath /var/lib/kubelet/config.yaml        # /etc/kubernetes/manifest（少了 s）
ls /etc/kubernetes/manifest                             # 不存在
sed -i 's#staticPodPath: .*#staticPodPath: /etc/kubernetes/manifests#' /var/lib/kubelet/config.yaml
systemctl restart kubelet
sleep 30; crictl ps
```
記法：`crictl ps -a` **完全沒有** kube-* 容器 = kubelet 沒讀到 manifest，直接查 `staticPodPath`。有 Exited 的容器 = manifest 有讀到但內容有錯。

---

## Scenario 5 — etcd data-dir 被改到空目錄
症狀可能兩種：etcd 起來但是全新空集群（kubectl 通，但什麼都沒有）；或 etcd 因目錄權限/掛載問題起不來。
```bash
crictl ps -a | grep etcd
crictl logs $(crictl ps -a --name etcd -q | head -1) | tail
grep -n -- '--data-dir\|hostPath\|mountPath' /etc/kubernetes/manifests/etcd.yaml
# --data-dir=/var/lib/etcd-old，但 volume hostPath 仍是 /var/lib/etcd
ls /var/lib/etcd/member                                 # 原始資料還在
sed -i 's#--data-dir=/var/lib/etcd-old#--data-dir=/var/lib/etcd#' /etc/kubernetes/manifests/etcd.yaml
sleep 30; kubectl get pods -A                           # 原有 workload 回來
```
關鍵是 `--data-dir` 與 volume 的 `hostPath.path` / `mountPath` 三者要一致。真實還原題正好相反：restore 到新目錄後要把三者一起改到新目錄。

---

## Scenario 6 — worker kubelet 停止且 disabled
```bash
kubectl describe node node01 | grep -A8 Conditions     # Kubelet stopped posting node status
ssh node01; sudo -i
systemctl status kubelet                               # inactive (dead), disabled
systemctl enable --now kubelet
systemctl is-enabled kubelet                           # enabled
exit; exit
kubectl get nodes -w
```
題目說「要能撐過重開機」就是提示要 `enable`，不只 `start`。

---

## Scenario 7 — controller-manager image 錯
```bash
kubectl -n kube-system get pods                        # kube-controller-manager ImagePullBackOff / ErrImagePull
kubectl -n kube-system describe pod kube-controller-manager-controlplane | grep -i image
kubectl -n kube-system get pod kube-apiserver-controlplane -o jsonpath='{.spec.containers[0].image}'   # 拿正確版本號
sed -i -E 's#(kube-controller-manager:v[0-9.]+)-broken#\1#' /etc/kubernetes/manifests/kube-controller-manager.yaml
kubectl create deploy probe --image=nginx; kubectl get pods -w
```
其他控制平面元件的 image tag 就是正確版本，直接對照。

---

## Scenario 8 — worker containerd 停止
```bash
ssh node01; sudo -i
systemctl status kubelet                               # active，但 journal 一直報 runtime 錯
journalctl -u kubelet -n 20 --no-pager
# → "failed to get container runtime status" / "connect: no such file or directory /run/containerd/containerd.sock"
systemctl status containerd                            # inactive
systemctl enable --now containerd
crictl ps                                               # 可用了
```
kubelet active 但節點 NotReady，先懷疑 runtime。

---

## Scenario 9 — apiserver 監聽 port 改了
```bash
crictl ps | grep kube-apiserver                        # Running
ss -tlnp | grep kube-apiserver                          # 監聽 6444
grep -n -- '--secure-port' /etc/kubernetes/manifests/kube-apiserver.yaml
grep server /etc/kubernetes/admin.conf                  # https://<ip>:6443，題目不准改它
sed -i 's#--secure-port=6444#--secure-port=6443#' /etc/kubernetes/manifests/kube-apiserver.yaml
```
排錯關鍵：容器 Running 且無錯誤 + connection refused = 沒在聽那個 port，用 `ss -tlnp` 或 `netstat` 看實際監聯的 port。也要注意 livenessProbe 的 port 與 `--secure-port` 一致，否則 kubelet 會一直重啟它。

---

## Scenario 10 — kubelet config 憑證路徑錯
```bash
systemctl status kubelet                               # activating (auto-restart) / failed
journalctl -u kubelet -n 30 --no-pager
# → "failed to load ... client CA file /etc/kubernetes/pki/CA.crt: no such file"
ls /etc/kubernetes/pki/ca.crt                           # 小寫存在
grep -n clientCAFile /var/lib/kubelet/config.yaml
sed -i 's#/etc/kubernetes/pki/CA.crt#/etc/kubernetes/pki/ca.crt#' /var/lib/kubelet/config.yaml
systemctl restart kubelet; systemctl is-active kubelet
```
kubelet 起不來的三個檔案：`/var/lib/kubelet/config.yaml`、`/etc/kubernetes/kubelet.conf`（server 位址與憑證）、`/var/lib/kubelet/kubeadm-flags.env`。`journalctl -u kubelet` 會直接說是哪一個。

---

## Combo
順序就是依賴順序：
1. 先讓 kubectl 通（Scenario 1：apiserver etcd 位址）。
2. kubectl 通後 `kubectl get pods -n kube-system` 看誰還 CrashLoop（Scenario 2：scheduler）。
3. `kubectl get nodes` 看 NotReady（Scenario 6：node01 kubelet）。
4. 最後 `kubectl run` 測 Pod 能排程且 Running。

考試中若一題有多個故障，修好一個就立刻重新 `get nodes` / `get pods -A`，用新的症狀決定下一步，不要憑猜測一次改完。

---

## 你描述的那題可能是什麼

「kubectl 壞、crictl 看 apiserver/scheduler 都 Exited、kubelet active、提到外部 etcd」——最可能是 **Scenario 1 或 3 的外部 etcd 版本**：apiserver 的 `--etcd-servers` 指到錯的位址/port，或 `--etcd-cafile/certfile/keyfile` 路徑錯，導致 apiserver 起不來；scheduler 與 controller-manager 因為連不到 apiserver 也跟著 Exited（它們是**受害者**不是根因）。修好 apiserver 後另外兩個會自己恢復。

解法一句話：`crictl logs` 看 apiserver 最後幾行 → 對照 manifest 的 `--etcd-*` 旗標 → 用題目給的 etcd 位址/憑證修正 → 等 30 秒。
