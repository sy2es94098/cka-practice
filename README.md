# cka-practice

CKA 考前練習包，包含兩套可在 Killercoda 或本機集群上一鍵佈置的實作題。

| 目錄 | 內容 | 題數 | 建議時間 |
|---|---|---|---|
| `cka-mock/` | 對照 2026 高頻題型的模擬考（Gateway API、HPA、PriorityClass、CRD、排錯、NetworkPolicy…），題目為英文，附自動評分 | 12 | 90 分 |
| `helm-lab/` | Helm 專項練習（repo、template、指定版本安裝、upgrade/rollback、--skip-crds…），題目為英文，附自動檢查 | 12 | 60 分 |
| `troubleshoot-lab/` | 控制平面與節點排錯：跑破壞腳本讓集群壞掉，再用 crictl / journalctl / manifest 修復（apiserver 連不到 etcd、kubelet 設定錯、節點 NotReady…） | 10 + Combo | 90 分 |

## 環境需求

- 一個可用的 Kubernetes 集群（Killercoda CKA playground 推薦，kind / minikube 亦可）
- `kubectl` 已可連線
- 網路（下載 Helm、Gateway API CRD、Bitnami chart）

## 快速開始（Killercoda）

1. 開啟 [CKA playground](https://killercoda.com/playgrounds/scenario/cka)。
2. 在終端機貼上：

```bash
git clone https://github.com/sy2es94098/cka-practice.git && cd cka-practice && chmod +x bootstrap.sh cka-mock/*.sh helm-lab/*.sh && ./bootstrap.sh mock && source ~/.bashrc
```

3. 開題目（英文版純 ASCII，`less` 不會亂碼）：

```bash
less cka-mock/questions.md
```

4. 做完評分：

```bash
./cka-mock/check.sh
```

`bootstrap.sh` 參數：

| 參數 | 動作 |
|---|---|
| `mock`（預設） | 安裝 helm、設定 alias、佈置 cka-mock 情境 |
| `helm` | 安裝 helm、設定 alias、佈置 helm-lab 情境 |
| `all` | 兩套一起佈置（約 2–3 分鐘） |

（troubleshoot-lab 不經過 bootstrap，見下一節。）

Killercoda 免費環境 60 分鐘會被清除，重開 playground 後再貼同一行即可，做到第幾題請自行記錄。

## 快速開始（troubleshoot-lab）

排錯 lab **不需要 bootstrap**（不用 helm、不佈置資源），只要 clone 後以 root 執行破壞腳本：

```bash
git clone https://github.com/sy2es94098/cka-practice.git && cd cka-practice/troubleshoot-lab && chmod +x *.sh breaks/*.sh
sudo -i                                     # Killercoda 預設已是 root 可省略
cd /root/cka-practice/troubleshoot-lab      # 依實際 clone 路徑
./breaks/01-apiserver-etcd-endpoint.sh      # 破壞（第一次會自動備份到 /root/cka-backup）
less questions.md                           # 看 Scenario 1 的題目描述，開始排錯
# ...修好後...
kubectl get nodes && kubectl -n kube-system get pods
./restore.sh                                # 還原，再跑下一個 break
```

- Scenario 6、8 要在 worker 上跑：`ssh node01`、`sudo -i`，再執行對應腳本（腳本需先 `scp` 過去或在 node01 再 clone 一次）。
- 一次只跑一個 break；Combo 題見 `questions.md` 最後。
- 若已跑過 `bootstrap.sh`（例如同一環境先做了 cka-mock），可直接 `cd troubleshoot-lab` 使用，互不影響。
- 考前務必讀 `troubleshoot-lab/playbook.md`：無 kubectl 時的固定排錯順序。

## 手動佈置（不用 bootstrap）

```bash
# 安裝 helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# alias
alias k=kubectl
export do="--dry-run=client -o yaml"

# 佈置情境
./cka-mock/setup.sh
./helm-lab/setup.sh        # 搞砸了用 ./helm-lab/reset.sh 重來
```

## 佈置後確認

```bash
k get nodes                              # controlplane + node01
k version | grep Server                  # 版本對齊考試
helm version
k get crd | grep gateway                 # Gateway API CRD 已安裝
k -n web get ingress                     # cka-mock Q1 情境
helm list -A                             # helm-lab 情境（若已跑 helm setup）
```

Gateway API CRD 下載失敗時手動補：

```bash
k apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

## 使用方式

1. 計時作答，每題上限 10 分鐘，超過就看解答、理解後重做。
2. 每題做完先用題目附的 Verify 指令自我檢查（考場上要養成的習慣）。
3. 全部做完後執行自動評分：

```bash
./cka-mock/check.sh      # 每題 PASS/FAIL + 總分，66 分及格
./helm-lab/check.sh      # 逐項 PASS/FAIL + 通過數
```

FAIL 的那一行會指出哪個要求沒達到，修正後可重跑。cka-mock 一題要所有檢查點都 PASS 才計分。
4. 對照 `solutions.md` 看陷阱說明與復習建議。
5. 重開環境、不看提示再跑一輪，目標每題 < 8 分鐘。

注意：`check.sh` 只看最終狀態，請在同一個環境內做完再檢查，中途重開環境會全部 FAIL。

## 本機使用（kind / minikube）

```bash
kind create cluster --name cka           # 或 minikube start
./bootstrap.sh all
```

限制：kind 節點是容器，無法 ssh 到節點、無法練 kubeadm 升級；cka-mock Q11 的 drain 步驟在單節點時略過。

## 已知限制

- 2GB 節點跑 helm-lab Task 10（ArgoCD）較吃資源，做到 `helm template --skip-crds` 驗證即可，不必等 Pod 全 Running。
- 題目要求寫入 `/opt/*.txt` 的檔案在環境清除後消失，屬正常現象。
- cka-mock Q1 的 GatewayClass `nginx-class` 沒有真實 controller，Gateway 會停在 Unknown/Pending 狀態，這不影響 YAML 正確性的驗證。
- troubleshoot-lab 會直接修改 `/etc/kubernetes` 與 kubelet 設定，只在練習環境執行；修復後 kubelet 最多需 20 秒重讀 manifest，apiserver 起來後再等 20–30 秒 kubectl 才會通。

## 檔案結構

```
cka-practice/
├── README.md
├── bootstrap.sh
├── .gitattributes
├── cka-mock/
│   ├── setup.sh        # 佈置情境
│   ├── check.sh        # 自動評分
│   ├── questions.md    # 題目（英文）
│   ├── solutions.md    # 解答與陷阱
│   └── README.md
├── helm-lab/
│   ├── setup.sh
│   ├── reset.sh        # 清除後重建
│   ├── check.sh        # 自動檢查
│   ├── tasks.md        # 題目（英文）
│   ├── solutions.md
│   ├── README.md
│   └── charts/webapp/
└── troubleshoot-lab/
    ├── breaks/*.sh     # 10 個破壞腳本
    ├── restore.sh      # 還原到破壞前
    ├── lib.sh
    ├── playbook.md     # 無 kubectl 時的排錯順序（考前必讀）
    ├── questions.md    # 題目（英文）
    ├── solutions.md
    └── README.md
```

## Windows 使用者

若 `git add` 出現 LF/CRLF 警告，repo 已含 `.gitattributes` 強制 LF，執行一次即可：

```bash
git add --renormalize .
```

在 Linux 環境若 script 出現 `$'\r': command not found`，表示帶有 CRLF，修正：

```bash
sed -i 's/\r$//' bootstrap.sh cka-mock/*.sh helm-lab/*.sh troubleshoot-lab/*.sh troubleshoot-lab/breaks/*.sh
```
