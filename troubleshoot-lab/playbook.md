# Playbook: when kubectl is dead

考前把這一頁背起來。順序固定，從外到內。

## 0. Confirm the symptom
```bash
kubectl get nodes                       # connection refused / timeout / unauthorized ?
```
- `connection refused` → apiserver 沒在聽（沒起來，或 port 變了）
- `timeout` → 網路 / IP / 防火牆
- `Unauthorized` / cert error → kubeconfig 或憑證問題，不是 apiserver 掛
- 正常回應但 Pod 都 Pending → scheduler；Deployment 不建 Pod → controller-manager；Node NotReady → 該節點 kubelet/containerd

## 1. Is kubelet alive?  (kubelet runs the static pods)
```bash
systemctl status kubelet
journalctl -u kubelet -f          # 或 -n 100 --no-pager
```
- inactive/failed → `journalctl` 看為什麼；常見是 `/var/lib/kubelet/config.yaml` 錯、`/etc/kubernetes/kubelet.conf` 錯、憑證路徑錯
- active 但 log 一直報錯 → 讀 log 內容，常見 "failed to get container runtime" → containerd

## 2. Are the control plane containers running?
```bash
crictl ps -a                                  # 看 STATE：Running / Exited
crictl ps -a --name kube-apiserver
crictl logs <id>                              # 剛退出的容器最後幾行就是答案
crictl logs --tail 30 $(crictl ps -a --name kube-apiserver -q | head -1)
```
容器被 GC 掉找不到 → 讀磁碟上的 log：
```bash
ls /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/
tail -50 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
```
`crictl ps -a` 完全沒有 kube-* 容器 → kubelet 沒讀到 manifest → 檢查 `staticPodPath`

## 3. Read the manifest the error message names
```bash
ls /etc/kubernetes/manifests/
grep -n -- '--etcd' /etc/kubernetes/manifests/kube-apiserver.yaml
grep -n -- '--kubeconfig' /etc/kubernetes/manifests/kube-scheduler.yaml
```
逐字對照錯誤訊息裡的路徑 / 位址 / 旗標名。常見：
| 元件 | 常見錯 |
|---|---|
| kube-apiserver | `--etcd-servers` 位址、`--etcd-certfile/keyfile/cafile` 路徑、`--secure-port`、`--advertise-address` |
| etcd | `--data-dir`、憑證路徑、`--listen-client-urls` |
| kube-scheduler / controller-manager | `--kubeconfig` 路徑 typo、image tag、不存在的旗標 |
| kubelet | `staticPodPath`、`clientCAFile`、kubelet.conf 裡的 server 位址 |

檔案是否存在：`ls -l /etc/kubernetes/pki/ | grep etcd`、`ls /etc/kubernetes/*.conf`

## 4. Fix in place, then wait
```bash
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# kubelet 每 20s 重掃 manifests，不必手動重啟；想快一點：
systemctl restart kubelet
watch crictl ps                                # 等新容器 Running 且不再重啟
```

## 5. Verify the whole chain
```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl get --raw='/readyz?verbose'            # apiserver 各檢查項
kubectl -n kube-system get pods -l tier=control-plane
```

## etcd specifics
```bash
# 本地 static etcd
crictl ps -a --name etcd; crictl logs <id>
grep -n -- '--data-dir\|--listen-client\|cert' /etc/kubernetes/manifests/etcd.yaml
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key endpoint health

# 外部 etcd（題目說 external / 不在 manifests 裡）
grep -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml   # 抓位址
curl -k --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
        --key  /etc/kubernetes/pki/apiserver-etcd-client.key \
        https://<etcd-ip>:2379/health
ssh <etcd-node>; systemctl status etcd; journalctl -u etcd     # 外部 etcd 是 systemd 服務
```

## Node NotReady (worker)
```bash
kubectl describe node node01 | grep -A10 Conditions
ssh node01; sudo -i
systemctl status kubelet containerd
journalctl -u kubelet -n 50 --no-pager
systemctl enable --now kubelet   # 或 containerd
```

## Do NOT
- 不要 reboot（考試禁止重開 base，控制平面重開也浪費時間）
- 不要 `kubeadm init/reset`
- 不要一次改多個檔案；改一處、等 30 秒、看結果
