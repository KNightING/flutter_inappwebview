<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608140054 - macos-spm-deployment-target
- Created: 2026-08-14
- Branch: fix/2608140054-macos-spm-deployment-target
- Issue: KNightING/flutter_inappwebview#6
- Status: Awaiting Archive
- Completed: [Wait for Finish]

## Goals

讓 macOS example app 在新版 Xcode（macOS SDK 26.4）下能夠建置與執行。
修正 `flutter_inappwebview_macos` 宣告的部署目標（macOS 10.14）與
`ASWebAuthenticationPresentationContextProviding`（需 macOS 10.15+）之間的可用性衝突——
新版 Swift 編譯器強制 protocol witness 的可用性不得低於部署目標，導致目前建置直接失敗。

## Architecture

**根因（Code Evidence Scan 佐證）：**

- 建置錯誤：`WebAuthenticationSession.swift:85:17: error: protocol 'ASWebAuthenticationPresentationContextProviding' requires 'presentationAnchor(for:)' to be available in macOS 10.14 and newer`
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift:9` — SPM 部署目標宣告 `.macOS("10.14")`，Flutter 目前選用 SPM 路徑建置（編譯指令含 `-target arm64-apple-macos10.14`）。
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Sources/flutter_inappwebview_macos/WebAuthenticationSession/WebAuthenticationSession.swift:13` — 類別**無條件**遵循 `ASWebAuthenticationPresentationContextProviding`。
- 同檔 `:84-85` — witness `presentationAnchor(for:)` 標註 `@available(macOS 10.15, *)`，高於部署目標 10.14 → 新版編譯器報錯。
- 對照 iOS 無此問題：`flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.swift:9` 部署目標 `.iOS("12.0")`，witness（`WebAuthenticationSession.swift:92-93`）標 `@available(iOS 12.0, *)` 等於部署目標，可通過。

**修法：** 把 macOS 部署目標升為 `10.15`。理由：

1. `ASWebAuthenticationSession` 型別本身即 macOS 10.15+，維持 10.14 需把遵循移入可用性受限的 extension，但 witness 簽章引用的型別仍是 10.15+，在 10.14 部署目標下無法乾淨表達——高成本且高 delta。
2. Flutter 3.44 stable 對 macOS app 的最低部署目標即為 10.15（example 的 `flutter_inappwebview/example/macos/Podfile:1` 亦為 `platform :osx, '10.15'`），升版不縮減任何實際支援面。
3. 類別內所有 `ASWebAuthenticationSession` 用法本就以 `#available(macOS 10.15, *)` 保護（`WebAuthenticationSession.swift:31,42,55,66,79`），行為不變。

**Fork delta 資產評估（project.md 鐵則）：** 本 repo 對 `flutter_inappwebview_macos` 目前與 upstream 零 diff；`upstream/master` 的 `Package.swift` 同為 `.macOS("10.14")` 且 `main...upstream/master` 為 23/0（上游無新 commit），確認**上游尚未修**、無法以拉取上游取代自修。本計畫花費 1–2 行 delta，屬「上游 bug、不修就無法建置」的必要支出；後續上游若修復同一處，拉取時衝突面極小。

**不動的東西：** 不改版本號、不改 CHANGELOG（fork 不發佈 pub.dev）；不處理建置 log 中的 CocoaPods integration 遷移提示（僅為 Flutter 工具的建議訊息，非錯誤，且 podspec/SPM 並存是 project.md 明載的刻意設計）。

**Code Style（Rule 14）：** 實作將符合 `kn:project:code-style` 規範；Phase 3 動手前調用該技能。本次變更為兩個 manifest 的版本字串，不涉及邏輯程式碼。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift:9`（`.macOS("10.14")`）— SPM 部署目標升為 `"10.15"`，解除與 10.15+ protocol witness 的可用性衝突（本次建置失敗的直接原因）。
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos.podspec:25`（`s.platform = :osx, '10.14'`）— CocoaPods 路徑同步升為 `'10.15'`，否則改用 CocoaPods 建置時會以 pod 自身部署目標 10.14 編譯、觸發同一錯誤（依 Q1 決議）。

## Open Questions / 待確認事項

> 尚未確認、會影響實作方向的行為或決策。**全部釐清前不得進入 Phase 3。**

### Q1. 修改範圍 — 影響範圍：`flutter_inappwebview_macos`
- [x] 選項 A：`Package.swift` 與 `.podspec` 一併升 10.15　(建議，理由：兩條建置路徑（SPM／CocoaPods）一致修復；Flutter 3.44 對 macOS 最低要求本就是 10.15，支援面無縮減；delta 僅 2 行)
- [ ] 選項 B：只改 `Package.swift`（目前 Flutter 實際走 SPM 路徑；delta 少 1 行，但 CocoaPods 路徑在新 Xcode 下仍會以同樣方式建置失敗）
- **決議**：選項 A　狀態：✅ 已確認

## Key Decisions

- **[Q1]** `Package.swift` 與 `.podspec` 一併升 10.15 — 理由：本次錯誤來自 SPM 路徑，但 podspec 是同一問題在 CocoaPods 路徑的潛伏版；兩邊宣告一致、一勞永逸。使用者於 2026-08-14 勾選確認。

## Git Completion Policy
- Issue 綁定時，PR body 必須含 `Closes #${N}`（`${N}` 取自上方 `- Issue:`，**不是** `${ID}`），歸檔完成後於該 issue 張貼由 archive 蒸餾的結案留言 (Rule 20)。
- After user-approved commits, completion will run `git rebase main` and update the remote work branch with `git push --force-with-lease --force-if-includes`（`main` 由本 repo 的 `refs/remotes/origin/HEAD` 判定）。
- PR/archive order: Archive automatically triggered on PR request。
- PR 目標一律為 `KNightING/flutter_inappwebview`（本 repo 為 fork，`gh pr create` 預設指向 parent，開 PR 前必須確認，見 project.md 鐵則）。

## References
- 建置失敗完整 log：`flutter build macos --debug`（2026-08-14 本機重現，Xcode macOS SDK 26.4）
- 先前計畫（`2608121003` / `2608121440`）記載「GitHub Issues 已停用」，實測 `gh repo view --json hasIssuesEnabled` 回傳 `true`，已與現況不符——本計畫依現況綁定 issue，落差已於 Phase 2 回報使用者。
