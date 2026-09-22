# CKA 模擬練習包

原創模擬題 12 題，題型對照 2026 考生回報高頻類型與 CKA v1.35 curriculum。

## 使用
1. 開一個 Killercoda Kubernetes playground（2 節點）或本機 kind 集群。
2. 把本目錄放進去，執行 `./setup.sh`（約 1 分鐘，需要網路下載 Gateway API CRD）。
3. 開 `questions.md`，計時 90 分鐘作答。
4. 對照 `solutions.md` 評分，66 分及格。

## 檔案
- `setup.sh`：佈置所有情境（既有 Ingress、PriorityClass、壞掉的 Deployment、CRD 等）
- `questions.md`：題目與驗證方式
- `solutions.md`：解答、陷阱與復習建議

## 提醒
Killercoda 免費環境 60 分鐘會被清除；若做不完，記下做到哪題，重開環境後 `setup.sh` 再跑一次，從該題繼續。
