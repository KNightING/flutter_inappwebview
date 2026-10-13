# 2610131552 - drop-inappwebview-overrides

- Created: 2026-10-13 15:52 / Archived: 2026-10-13 16:40
- Issue: KNightING/flutter_inappwebview#24
- Milestone: 6.2.0-beta.3.6 / Base Branch: 6.2.0-beta.3.6

## Summary
使用端現在只需一個 `flutter_inappwebview` 的 git 依賴即可取得 fork 的全部平台實作，不再需要 `dependency_overrides`。
做法是把 7 個 pubspec（主套件與 android、ios、macos、windows、web、linux 六個平台實作）對同 repo 套件的 `^版本` 依賴改為相對 `path:`；只改主套件不夠，平台實作仍依賴 hosted 的 platform_interface 會造成來源衝突。`project.md` 補上新的使用端寫法與同步上游衝突時重做這 7 處的規則。未改任何程式碼、套件名、命名空間與 JS 橋接名。

## Cross-Repo Scope
- 共用計畫 ID `2610131552-drop-inappwebview-overrides`、共用分支名 `feature/2610131552-drop-inappwebview-overrides`。
- `flutter_inappwebview`（本計畫，A）：改 7 個 pubspec；issue `KNightING/flutter_inappwebview#24`。
- `nuxt-flutter-app`（B）：改為單一 git 依賴、刪 `dependency_overrides`、驗證建置。
- **執行順序**：A 先、B 後。B 的前提是 tag `6.2.0-beta.3.6` 已存在於本 repo（合併後由人打 tag／建立 Release）。

## Key Decisions
- **[Phase 0]** Milestone `6.2.0-beta.3.6`（沿用既有 tag 序列 `.1`–`.5`，pre-release 格式不計入版本推導，由使用者輸入指定）；Base Branch 同名，自 `main` 切出。分支與日後要打的 tag 同名，指令一律用完整 ref。milestone 為非標準格式，版本檔同步與 Version Gate 跳過。
- **[Phase 0]** 整合主幹：遠端僅 `main`，無 dev 類分支，不詢問。
- **[Phase 0]** 使用者決定採用「拿掉 override」並接受維護成本：往後同步上游時，上游若碰到這 7 處 pubspec 會有小衝突。
- **[Q1]** 同步上游衝突時的重做方式只寫在 `project.md`，不新增腳本 — 理由：不新增檔案、不擴大與上游的 delta。
- **[規劃]** 僅驗證依賴解析，不跑各平台建置 — 理由：只改 pubspec 來源，不改程式碼；建置驗證在使用端 B 計畫。
- **[核准閘]** 完成後：commit + 開 PR；PR 必須指定 `--repo KNightING/flutter_inappwebview`，避免誤射上游。

## Deviations
- 計畫核准後的驗證，改用「指向真實工作分支（file:// git URL）的 scratch consumer」，8 個套件皆解析為 `from git`、`resolved-ref` 為本分支 commit；與計畫的驗證項目一致，僅方式為實際分支而非 clone 副本。
- 發現既有問題（與本計畫無關，未處理）：`wiki-lint.py` 對現有 wiki 回報硬閘違規 31 項（如 `index.md` 最後一行導覽列、頁面骨架），`wiki.html`／`wiki-data/` 從未建置。本計畫未動任何 wiki 頁，故未修、未建置。

## Impact Files
- `flutter_inappwebview/pubspec.yaml:23-35` — 對 platform_interface 與 6 個平台實作改 `path:`
- `flutter_inappwebview_android/pubspec.yaml:23` — 對 platform_interface 改 `path:`
- `flutter_inappwebview_ios/pubspec.yaml:23` — 同上
- `flutter_inappwebview_macos/pubspec.yaml:23` — 同上
- `flutter_inappwebview_windows/pubspec.yaml:23` — 同上
- `flutter_inappwebview_web/pubspec.yaml:26` — 同上
- `flutter_inappwebview_linux/pubspec.yaml:23` — 同上
- `.kn-project/project.md:22-23` — 補上使用端免 override 的依賴寫法與同步上游的重做規則
