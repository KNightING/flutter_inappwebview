<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Tasks: 2608151157 - 對齊 Flutter 3.47.0 的平台基準

> Q1–Q8 已於 2026-08-15 全數決議，見 `plan.md` 的 `## Key Decisions`。
> 本計畫分兩段，**共用同一分支 `feature/2608151157-flutter-3-47-upgrade`**。

## Phase A：前置（Stage 1）

- [x] A1. 建立 GitHub Issue，編號回填 `plan.md` 的 `- Issue:`
- [x] A2. `gh issue develop` 建立遠端分支並 `git switch` 切換
- [x] A3. 記錄變更前基準（`flutter --version` = 3.47.0 / Dart 3.13.0）

## Phase B：Android 工具鏈（Stage 1，本機可驗證）

- [x] B1. KGP `2.2.20` → `2.4.0`：`flutter_inappwebview/example/android/settings.gradle`
- [x] B2. KGP 同步：`flutter_inappwebview_android/example/android/settings.gradle`
- [x] B3. `flutter_inappwebview_android/android/build.gradle` 的 `minSdk 19` → `24`
- [x] B4. `flutter_inappwebview/example` 建置通過（`flutter build apk --debug` exit 0，703s），
      KGP / minSdk 的版本警告已消失；但浮現 Built-in Kotlin 警告 → Q10
- [x] B5. `flutter_inappwebview_android/example` 建置通過（exit 0，101s）。
      同樣只剩 Built-in Kotlin 警告，且**未點名任何第三方套件**——那份名單
      （`file_picker` / `flutter_downloader`）只出現在另一個 example，屬其自身依賴

## Phase C：套件層的 iOS / macOS 部署目標宣告（Stage 1，**無法**實測）

- [x] C1. `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.swift` → `.iOS("15.0")`
- [x] C2. `flutter_inappwebview_ios/ios/flutter_inappwebview_ios.podspec` → `s.platforms` **與** `core.platform` **兩處**皆 `15.0`
- [x] C3. `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift` → `.macOS("12.0")`
- [x] C4. `flutter_inappwebview_macos/macos/flutter_inappwebview_macos.podspec` → `s.platform = :osx, '12.0'`
- [x] C5. 全 repo grep 複核：套件層無殘留 `12.0` / `10.15`，同套件內各處一致

## Phase D：驗證與文件（Stage 1）

- [x] D1. `flutter analyze` 各套件通過（確認 3.47 未引入新 error）
- [x] D2a. Windows example **建置**通過：`√ Built build\windows\x64\runner\Debug\example.exe`（519s）。
      先前的 `NUGET-NOTFOUND` 已釐清為 `find_program` 只搜 PATH 所致，非環境缺件，見 Q11
- [ ] D2b. Windows example **實跑**：Impeller 預設下 WebView 顯示 / 捲動 / 縮放正常
      → 需人工目視，尚未執行
- [x] D3. `flutter build web` 通過（146s），且 **Wasm dry run succeeded**——
      反證 `package:web` 遷移已完整，套件為 Wasm-ready
- [x] D4. `README.md:58-59` 更新為實際值（minSdk 24、AGP 9.3.0、iOS 15、macOS 12）
- [ ] D5. 整理「已驗證 / 未驗證」清單

## Phase E：Stage 1 收尾

- [ ] E1. 逐項請示 commit（Rule 17）
- [ ] E2. 交棒說明：Stage 2 待辦與接手方式寫入 `plan.md`

---

## Phase F：Stage 2（**macOS 環境接手**，同分支續作）

- [ ] F1. `git switch feature/2608151157-flutter-3-47-upgrade` 並 `git pull`
- [ ] F2. example 的 iOS 部署目標 13.0 → 15.0：`flutter_inappwebview/example/ios` 與
      `flutter_inappwebview_ios/example/ios` 的 `Podfile` + `project.pbxproj`
      （可先跑 `flutter build ios` 讓 migrator 自動改寫，再複核 diff）
- [ ] F3. example 的 macOS 部署目標 10.15 → 12.0：`flutter_inappwebview/example/macos` 與
      `flutter_inappwebview_macos/example/macos`
- [ ] F4. UIScene 採用（Q4/C）：`Info.plist` 的 `UIApplicationSceneManifest` + `AppDelegate` 調整
- [ ] F5. iOS example 實機／模擬器建置與執行驗證
- [ ] F6. macOS example 建置與執行驗證（**含 Impeller 預設下的 WKWebView 呈現**）
- [ ] F7. `pod lib lint` 或等效檢查，確認 podspec 部署目標無矛盾
- [ ] F8. 逐項請示 commit

## Phase G：結案（Stage 2 完成後）

- [ ] G1. `git rebase main` + `git push --force-with-lease --force-if-includes`
- [ ] G2. 開 PR（**確認目標 repo 為 `KNightING/flutter_inappwebview`**）並觸發歸檔 + wikification
