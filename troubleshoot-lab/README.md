# troubleshoot-lab: Control Plane & Node Troubleshooting

10 破壞腳本，各模擬一種真實故障。你跑一個 → 集群壞掉 → 用 `crictl` / `journalctl` / manifest 排錯修好 → `restore.sh` 或直接進下一題。

對照你描述的考題情境：kubectl 不通、`crictl ps -a` 顯示 kube-apiserver / scheduler 等 Exited、kubelet 卻是 active、題目提到外部 etcd —— 對應 Scenario 1、3、5、9。

## 使用方式

```bash
# 在 controlplane 上
sudo -i
cd /root/cka-practice/troubleshoot-lab      # 依你 clone 的路徑
./breaks/01-apiserver-etcd-endpoint.sh      # 破壞
# ... 排錯修復 ...
kubectl get nodes && kubectl get pods -n kube-system   # 確認恢復
./restore.sh                                # 保險起見還原到乾淨狀態，再跑下一個
```

第一次跑任何 break 腳本時會自動備份 `/etc/kubernetes/manifests` 與 kubelet 設定到 `/root/cka-backup`。

Scenario 6、8 要在 **worker 節點**（`ssh node01; sudo -i`）執行。

一次只跑一個 break；混合故障請見 questions.md 最後的 Combo 題。

## 檔案
- `breaks/*.sh` 破壞腳本
- `restore.sh` 還原
- `questions.md` 題目（英文，考試語氣，不告訴你哪裡壞）
- `solutions.md` 排錯流程與修法
- `playbook.md` 無 kubectl 時的通用排錯順序表（考前背這頁）

## 注意
- 這些腳本直接改 `/etc/kubernetes` 與 kubelet 設定，**只在練習環境（Killercoda / kind / 自建 VM）跑**。
- Killercoda 環境 60 分鐘會重置，做不完就重開再跑。
- 修復後 kubelet 最多需要 20 秒重新讀取 manifest，apiserver 起來再等 20–30 秒 kubectl 才通，不要急著再改。
