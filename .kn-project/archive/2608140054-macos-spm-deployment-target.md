# 2608140054 - macos-spm-deployment-target

- Created: 2026-08-14 00:54 / Archived: 2026-08-14 09:45
- Issue: KNightING/flutter_inappwebview#6

## Summary

將 `flutter_inappwebview_macos` 的部署目標由 macOS 10.14 升至 10.15（SPM 與 podspec 各 1 行），修復新版 Xcode 下 macOS 完全無法建置的問題。根因：`WebAuthenticationSession` 無條件遵循 `ASWebAuthenticationPresentationContextProviding`（10.15+），witness 標註 `@available(macOS 10.15, *)` 高於部署目標，新版 Swift 編譯器（Xcode macOS SDK 26.4）強制 witness 可用性不得低於部署目標而報錯。上游 `pichillilorenzo/flutter_inappwebview` master 同為 10.14 未修，故屬上游 bug 的本地必要修復；iOS 不受影響（witness 標註等於部署目標 12.0）。Flutter 3.44 對 macOS app 的最低部署目標即為 10.15，支援面無縮減。驗證：`flutter build macos --debug` 成功，example app 啟動、載入網頁、導航與事件遞送皆正常。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** `Package.swift` 與 `.podspec` 一併升 10.15 — 理由：本次錯誤來自 SPM 路徑（Flutter 3.44 預設以 SPM 編譯外掛），但 podspec 是同一問題在 CocoaPods 路徑的潛伏版；兩邊宣告一致、一勞永逸。使用者於 2026-08-14 勾選確認。
- **[執行中]** 不動版本號與 CHANGELOG — fork 不發佈 pub.dev；不處理 Flutter 工具的 CocoaPods 遷移提示（僅為建議訊息，且 podspec/SPM 並存是 project.md 明載的刻意設計）。
- **[執行中]** fork delta 資產評估：本 repo 對 `flutter_inappwebview_macos` 原為零 diff，此修花費 2 行 delta，屬「上游 bug、不修就無法建置」的必要支出；上游日後若修同一處，衝突面極小。

## Deviations

None。

## Impact Files

- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift:9` — `.macOS("10.14")` → `"10.15"`（本次 SPM 建置失敗的直接原因）
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos.podspec:25` — `s.platform = :osx, '10.14'` → `'10.15'`（CocoaPods 路徑同一問題的預防）

## Details

- 根因錨點：`flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Sources/flutter_inappwebview_macos/WebAuthenticationSession/WebAuthenticationSession.swift:13`（無條件遵循）、`:84-85`（witness `@available(macOS 10.15, *)`）。類別內所有 `ASWebAuthenticationSession` 用法本就有 `#available(macOS 10.15, *)` 保護，升版不改變行為。
- 治理紀錄修正：先前計畫（2608121003、2608121440）記載「GitHub Issues 已停用」；本次實測 `gh repo view --json hasIssuesEnabled` 為 `true`，Issues 實際可用，本計畫已依現況綁定 issue #6。後續計畫的 Rule 20 偵測以實測為準。
