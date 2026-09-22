# Helm 練習 Lab（CKA 導向）

## 環境準備（三選一）

**選項 1：kind（推薦，本機）**
```bash
# 安裝 kind：https://kind.sigs.k8s.io/docs/user/quick-start/#installation
kind create cluster --name helm-lab
```

**選項 2：minikube**
```bash
minikube start
```

**選項 3：Killercoda 免費 Playground（瀏覽器，不用安裝）**
https://killercoda.com/playgrounds/scenario/kubernetes
（已預裝 kubectl；helm 需自己裝，見下方）

## 安裝 Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

## 建置 lab
```bash
git clone 或把 helm-lab 目錄放到機器上
cd helm-lab
./setup.sh
```
搞砸了想重來：`./reset.sh`

## 檔案說明
| 檔案 | 用途 |
|---|---|
| `tasks.md` | 12 道練習題，依難度排序，每題有驗證方式 |
| `solutions.md` | 參考解答（先自己做完再看） |
| `charts/webapp/` | 本地範例 chart，可 `helm install` 或改寫 |
| `repo/` | setup.sh 打包出的三個版本 `.tgz`，模擬「指定版本安裝」 |
| `setup.sh` / `reset.sh` | 建置 / 重置環境 |

## 建議練法
1. 每題計時，目標 3–5 分鐘內完成。
2. 只用 `helm --help` 與 https://helm.sh/docs 查資料（考試允許的官方文件）。
3. 做完用題目內的「驗證」指令自我檢查，再對照 solutions.md。
4. 所有題目做過兩輪後，跑 `./reset.sh`，不看任何提示從頭做一遍。
