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
- [x] D5. 整理「已驗證 / 未驗證」清單

## Phase E：Stage 1 收尾

- [x] E1. 逐項請示 commit（Rule 17）
- [x] E2. 交棒說明：Stage 2 待辦與接手方式寫入 `plan.md`

---

## Phase F：Stage 2（**macOS 環境接手**，同分支續作）

> 2026-08-15 於 macOS 展開為可執行粒度。Q12–Q15 待核准後才進 F3。
> 環境基準與 Code Evidence Scan 複核結果見 `plan.md` 的 `## Stage 2 開工基準`。

### F0：接手與基準（已完成）

- [x] F1. `git switch feature/2608151157-flutter-3-47-upgrade` + `git fetch`，工作區乾淨
- [x] F1a. 環境實測：Flutter 3.47.0 / **Xcode 26.4.1** / macOS 26.5.2 / CocoaPods 1.17.0
- [x] F1b. Code Evidence Scan 複核 Stage 1 的全部錨點 → **零漂移**
- [x] F1c. 本機 SDK migrator 取代值直接讀出確認（15.0 / 12.0）
- [x] F2. Q12–Q15 提出並寫入 `plan.md`（**待核准**）

### F-A0：解除阻礙（Q17，執行中浮現）

- [x] F2a. 查證 `pub get` 失敗成因：來源衝突（hosted vs path），非版本問題
- [x] F2b. 於 `main` 乾淨 worktree 重現 → 確認**既有問題**，與本分支/3.47 無關
- [x] F2c. 於拋棄式 worktree 驗證修法可行，事後移除
- [ ] F2d. `flutter_inappwebview_ios/example/pubspec.yaml` 補 `dependency_overrides`
- [ ] F2e. `flutter_inappwebview_macos/example/pubspec.yaml` 補 `dependency_overrides`
- [ ] F2f. 三個 example 的 `pub get` 全數通過
- [ ] F2g. 請示 commit（**獨立 commit**，不與基準對齊混同）

### F-A1：解除阻礙（Q18，執行中浮現）

- [x] F2h. 抓出真實錯誤（`-v`）：SPM traits 衝突，非部署目標／UIScene 造成
- [x] F2i. 確認 Flutter 3.47 stable 預設啟用 SPM（`features.dart:233-240`）
- [x] F2j. 定位真正的釘選來源：套件本體**已版控**的 `Package.resolved` = 1.3.0
- [x] F2k. 四次建置實測矩陣，確認 `Package.swift` **無需變更**
- [x] F2l. ~~重新解析 Package.resolved~~ → **經複測推翻**：還原為上游 1.3.0 後乾淨重建**通過**
- [x] F2m. 確認 macOS 子 example 以 1.3.0 建置成功，反證非版本問題
- [x] F2n. **結論：本 repo 零變更**，套件本體與上游 delta 為零；成因為首次 SPM 整合的冷快取壞解析

### F-A：部署目標（低風險，migrator 自動改寫）

- [ ] F3. iOS 部署目標 13.0 → 15.0：跑 `flutter build ios --simulator --debug`
      讓 migrator 改寫兩個 example 的 `Podfile` + `project.pbxproj`，**逐行複核 diff**
- [ ] F4. macOS 部署目標 10.15 → 12.0：跑 `flutter build macos --debug`，同樣複核 diff
- [ ] F5. 複核 migrator **未**動到套件層（`.podspec` / `Package.swift` 應維持 Stage 1 的值）
- [ ] F6. 建置驗證（此時尚未動 UIScene，確立乾淨基準）：
      - [ ] F6a. `flutter_inappwebview/example` iOS 模擬器建置
      - [ ] F6b. `flutter_inappwebview_ios/example` iOS 模擬器建置
      - [ ] F6c. `flutter_inappwebview/example` macOS 建置
      - [ ] F6d. `flutter_inappwebview_macos/example` macOS 建置
- [ ] F7. 請示 commit（部署目標，與 UIScene 分開）

### F-B：UIScene 採用（Q4/C，做法已依 Q16 大幅簡化）

> **2026-08-15 修訂**：查證發現 Flutter 3.47 內建 UIScene 自動遷移器且 stable 預設啟用（Q16）。
> 原訂的「新增 `SceneDelegate.swift` + 手動改 pbxproj 四處」**整段作廢**——
> 遷移器用 engine 內建的 `FlutterSceneDelegate`，不新增檔案、不碰 pbxproj。
> Q14（`@main`）與 Q15（`FlutterImplicitEngineDelegate`）由遷移器的輸出自動達成。

- [ ] F8. `flutter_inappwebview_ios/example`：**倚賴自動遷移**（AppDelegate 已驗證命中範本 #4）。
      跑 iOS 建置後複核遷移器實際寫入的 `Info.plist` 與 `AppDelegate.swift`
- [ ] F9. `flutter_inappwebview/example`：**手動套用**（AppDelegate 不命中範本，只會印警告）
      - [ ] F9a. `AppDelegate.swift` 改為遷移器的 `newSwiftAppDelegate` 形狀
            （`@main` + `FlutterImplicitEngineDelegate` + `didInitializeImplicitFlutterEngine`）
      - [ ] F9b. **保留** `flutter_downloader` 的既有註解區塊，不順手清理
      - [ ] F9c. `Info.plist` 加 `UIApplicationSceneManifest`，內容與遷移器
            `uiscene_migration.dart:270-283` **逐鍵一致**（`UISceneDelegateClassName` = `FlutterSceneDelegate`）
- [ ] F10. 複核兩個 example 的 UIScene 設定**彼此一致**（自動 vs 手動不得產生差異）
- [ ] F11. UIScene 採用後重新建置兩個 iOS example
- [ ] F12. 確認建置輸出不再出現 `flutter.dev/to/uiscene-migration` 警告
- [ ] F13. 請示 commit（UIScene）

### F-C：實跑驗證（人工目視，不可用建置成功代替）

- [ ] F14. iOS 模擬器實跑：WebView 顯示 / 捲動 / 縮放 / 鍵盤（keyboardAvoidance 為本 repo 既有功能）
      **UIScene 採用後的 app 生命週期需一併觀察**（背景/前景切換、視窗重建）
- [ ] F15. macOS 實跑：**Impeller 預設下**的 WKWebView 呈現、視窗縮放、捲動
- [ ] F16. `pod lib lint`（或 `pod install` + 部署目標一致性檢查）確認 podspec 無矛盾

### F-D：收尾

- [ ] F17. 更新 `plan.md` 的「已驗證 / 未驗證」表，明列**實體 iOS 裝置**為未驗證；
      UIScene 的結論措辭**不得**宣稱「為了 Xcode 27」（Q12 更正）
- [ ] F18. 逐項請示 commit（Rule 17）

## Phase G：結案（Stage 2 完成後）

- [ ] G1. `git rebase main` + `git push --force-with-lease --force-if-includes`
- [ ] G2. 開 PR（**確認目標 repo 為 `KNightING/flutter_inappwebview`**）並觸發歸檔 + wikification
