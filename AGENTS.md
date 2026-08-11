# AI Agents 治理與協作指南 (AGENTS.md)

這個資料夾 `.kn-project` 用於存放由 AI Agents 產生的開發文件，協助追蹤專案進度、設計決策與技術規格。

## 強制技能調度：kn:project:precision-workflow-manager

本專案將 **`kn:project:precision-workflow-manager`** 設為核心治理技能。Agent 在執行**任何**任務時，**必須優先啟動此技能**以進行精準工作流 (Phase 0-5) 管理。**不存在任何規模豁免**：純錯字、純註解、純格式、只改一行的變更同樣要走完 Phase 1 分類與 Phase 2 核准閘，沒有直接動手的捷徑。

### 1. 技能啟動條件 (Skill Activation)
當 Agent 接收到包含以下指令或意圖時，**必須主動讀取並調用** `kn:project:precision-workflow-manager`：
- **關鍵行為 (英文)**：`build`, `create`, `modify`, `fix`, `add`, `implement`, `refactor`, `setup`, `optimize`, `change`, `rework`, `debug`.
- **關鍵行為 (中文)**：新增、增加、建立、實作、開發、撰寫、修改、調整、更新、修正、修復、除錯、重構、優化、設定、改寫、串接、整合、規劃、計畫。
- **中文口語**：如「幫我改一下」「這裡怪怪的」「順便加個…」「幫我看看能不能…」，同樣視為觸發。
- **檔案變更**：涉及 `.dart`, `.java`, `.swift`, `.kt`, `.cc`, `.ts` 等邏輯檔案，或 `.kn-project/` 目錄下的文件。

### 2. 治理審核閘口 (Governance Gates)
啟動技能後，Agent 必須遵循技能規範中的審核點：
- **Phase 2 鎖定**：初始化計畫後，Agent **必須停止**並請求使用者核准任務清單，嚴禁跳過。
- **Phase 5 結案**：任務完成後，Agent **必須請求**歸檔許可，未經同意不得自行清理計畫。

程式碼撰寫另需遵守 `kn:project:code-style` 技能。

---

## ⚠️ 本 repo 特有的三條紅線

1. **這是 `pichillilorenzo/flutter_inappwebview` 的 GitHub fork，且不回貢上游。**
   所有 PR 一律指向 `KNightING/flutter_inappwebview`。但 `gh pr create` 預設會指向 parent repo，
   已設定 `gh repo set-default KNightING/flutter_inappwebview` 收斂，**每次開 PR 前仍須確認目標
   repo**——誤射會把變更送進他人的公開 repo。
2. **與上游零分歧是刻意維持的資產。** delta 要保持極小，任何超出計畫範圍的「順手改一下」
   都在花掉它。**動機是讓「拉取上游更新」保持 fast-forward，與回貢無關**（見第 1 點）。
3. **不改套件名、命名空間、JS 橋接名。** 改了就等於放棄第 2 點，且使用端要付出遷移成本。

## 📂 目錄結構

- `.kn-project/`: AI 治理與知識根目錄。
  - `project.md`: 專案入口 (Portal)，含架構總覽與保留鐵則。
  - `wiki/`: 專案百科 (Graph 關聯系統)，由 `kn:project:wikification` 維護。
  - `plans/`: 進行中計畫（資料夾即索引；各計畫的 `plan.md` 內含 `- Status:` 行作為生命週期唯一真相來源，無獨立索引檔）。
  - `archive/`: 已完成計畫的歷史紀錄；資料夾即索引（檔名 = 時間戳 + 描述），無獨立索引檔。

---
[📈 專案入口](./.kn-project/project.md)
