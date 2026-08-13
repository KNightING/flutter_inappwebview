# 2608130815 - project-md-per-machine-setup

- Created: 2026-08-13 08:15 / Archived: 2026-08-13 08:40
- Issue: KNightING/flutter_inappwebview#2

## Summary

`project.md` 中兩項每機獨立的本機設定由「既成事實」改寫為「首次 clone 後必做」的 checklist。

原文記載 `gh repo set-default` 已執行、`upstream` remote 已接上，但兩者都存於各 clone 自己的
`.git/config`，不隨帳號或 repo 傳遞——2026-08-13 在本機實查皆為**未設定**。其中 `gh` 未收斂時
`gh pr create` 會指向上游 parent，誤射會把變更送進他人的公開 repo；`upstream` 缺席則讓
`git diff upstream/master` 的 delta 檢查直接失敗（計畫 2608111609 的 E1 因此必須臨時補建）。
新增 `## 每台開發機首次 clone 後必做` 章節，附可執行指令與驗證方式。影響 `.kn-project/project.md`。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **就地改寫，不另開 wiki 頁**（Q1）— 只有兩條，且與既有保留鐵則同屬「動手前必讀」，
  抽出去多一次跳轉。日後每機設定變多再抽。
- **建立並綁定 issue**（Q2）— 本 repo 實查 `has_issues = true`，追蹤基準可用；
  已歸檔的 2608111609 記載「Issues 已停用」已過時，不沿用該記載。

## Deviations

- tasks 第 3 項（依 Q1 可能需建立 `wiki/features/dev-machine-setup.md`）因 Q1 決議為 A 而無需執行。

## Impact Files

- `.kn-project/project.md:24` — 「PR 一律指向」條目保留但刪去已失效的「已執行 set-default」狀態描述。
- `.kn-project/project.md:28` — 新增 `## 每台開發機首次 clone 後必做` 章節，
  含 `gh repo set-default` 與 `git remote add upstream` 兩項 checklist、指令與驗證方式。

## Details

全檔以 `grep -nE "已執行|已接上|已設定|已安裝|已配置"` 掃過，確認無其他同類的既成事實式描述。
