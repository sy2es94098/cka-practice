# cka-practice

CKA 考前練習包，包含兩套可在 Killercoda 或本機集群上一鍵佈置的實作題。

| 目錄 | 內容 | 題數 | 建議時間 |
|---|---|---|---|
| `cka-mock/` | 對照 2026 高頻題型的模擬考（Gateway API、HPA、PriorityClass、CRD、排錯、NetworkPolicy…） | 12 | 90 分 |
| `helm-lab/` | Helm 專項練習（repo、template、指定版本安裝、upgrade/rollback、--skip-crds…） | 12 | 60 分 |

## 環境需求

- 一個可用的 Kubernetes 集群（Killercoda CKA playground 推薦，kind / minikube 亦可）
- `kubectl` 已可連線
- 網路（下載 Helm、Gateway API CRD、Bitnami chart）

## 快速開始（Killercoda）

1. 開啟 [CKA playground](https://killercoda.com/playgrounds/scenario/cka)。
2. 在終端機貼上：

```bash
git clone https://github.com/<你的帳號>/cka-practice.git && cd cka-practice && ./bootstrap.sh mock && source ~/.bashrc
```

3. 開題目：

```bash
less cka-mock/questions.md
```

`bootstrap.sh` 參數：

| 參數 | 動作 |
|---|---|
| `mock`（預設） | 安裝 helm、設定 alias、佈置 cka-mock 情境 |
| `helm` | 安裝 helm、設定 alias、佈置 helm-lab 情境 |
| `all` | 兩套一起佈置（約 2–3 分鐘） |

Killercoda 免費環境 60 分鐘會被清除，重開 playground 後再貼同一行即可，做到第幾題請自行記錄。

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
2. 每題做完用題目附的驗證指令自我檢查。
3. 對照 `solutions.md` 評分（cka-mock 100 分制，66 分及格）。
4. 全部做完後重開環境、不看提示再跑一輪，目標每題 < 8 分鐘。

## 本機使用（kind / minikube）

```bash
kind create cluster --name cka           # 或 minikube start
./bootstrap.sh all
```

限制：kind 節點是容器，無法 ssh 到節點、無法練 kubeadm 升級；cka-mock Q11 的 drain 步驤在單節點時略過。

## 已知限制

- 2GB 節點跑 helm-lab Task 10（ArgoCD）較吃資源，做到 `helm template --skip-crds` 驗證即可，不必等 Pod 全 Running。
- 題目要求寫入 `/opt/*.txt` 的檔案在環境清除後消失，屬正常現象。
- cka-mock Q1 的 GatewayClass `nginx-class` 沒有真實 controller，Gateway 會停在 Unknown/Pending 狀態，這不影響 YAML 正確性的驗證。

## 檔案結構

```
cka-practice/
├── README.md
├── bootstrap.sh
├── .gitattributes
├── cka-mock/
│   ├── setup.sh
│   ├── questions.md
│   ├── solutions.md
│   └── README.md
└── helm-lab/
    ├── setup.sh
    ├── reset.sh
    ├── tasks.md
    ├── solutions.md
    ├── README.md
    └── charts/webapp/
```

## Windows 使用者

若 `git add` 出現 LF/CRLF 警告，repo 已含 `.gitattributes` 強制 LF，執行一次即可：

```bash
git add --renormalize .
```

在 Linux 環境若 script 出現 `$'\r': command not found`，表示帶有 CRLF，修正：

```bash
sed -i 's/\r$//' bootstrap.sh cka-mock/setup.sh helm-lab/setup.sh helm-lab/reset.sh
```