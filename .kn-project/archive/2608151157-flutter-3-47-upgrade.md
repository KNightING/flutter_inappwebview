# 2608151157 - flutter-3-47-upgrade

- Created: 2026-08-15 11:57 / Archived: 2026-08-15 18:15
- Issue: KNightING/flutter_inappwebview#10

## Summary

將本 repo 的平台宣告與建置設定全面對齊 Flutter 3.47.0 / Dart 3.13.0，並讓兩個 iOS example 採用 UIScene 生命週期。涵蓋 Android 工具鏈（KGP 2.2.20→2.4.0、套件 `minSdk` 19→24）、iOS/macOS 部署目標（套件層與 example 層皆升至 iOS 15 / macOS 12）、README 平台基準更新。因 iOS/macOS 的實測需要 Xcode，本計畫**分兩段執行、共用同一分支與同一份計畫**：Stage 1 於 Windows 完成 Android/Windows/Web 的變更與驗證，Stage 2 於 macOS 完成 Xcode 專案遷移與 iOS/macOS 實測。所有數值判定皆取自本機 Flutter SDK 原始碼（`gradle_utils.dart`、`DependencyVersionChecker.kt`、各 migrator），非 blog 轉述。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** iOS 15 / macOS 12 全面採用，套件與 example 皆升 — 與 3.47 完全對齊；代價（放棄 iOS 12–14 / macOS 10.15–11 使用端、擴大上游 delta）已揭露並由使用者接受。
- **[Q2]** KGP 升至 2.4.0（Flutter template 值）— 原值 2.2.20 正好等於 `errorKGPVersion`，已在 warn 區，下一次調升即建置失敗。
- **[Q3]** `pubspec.yaml` 的 `environment:` 下限不動 — 下限抬高只切斷舊使用端，對 3.47 相容性無助益且擴大 delta。
- **[Q4/Q12]** iOS example 採用 UIScene — **但採用理由經 Stage 2 更正**：SDK 原始碼查無任何 "Xcode 27" 字樣（`xcodeRequiredVersion=15` / `xcodeRecommendedVersion=16`），Stage 1 引用的「Xcode 27 建置即啟動失敗」屬 blog 轉述、無法佐證（違反 Rule 18，已更正）。SDK 實際措辭為 "upcoming iOS versions"。改以可佐證的理由陳述：UIScene 是未來 iOS 版本的要求，且 Flutter 3.47 已內建 stable 預設啟用的自動遷移器。
- **[Q5]** 套件 `minSdk` 19→24 — 19 是不實宣稱，Flutter 早已不支援且本套件從未在其上驗證。
- **[Q6]** Impeller 只驗 Windows（Stage 1）與 macOS（Stage 2），Linux 標記為已知未驗證。
- **[Q7]** Material/Cupertino 獨立套件遷移不做 — 2026 年 11 月才正式棄用，現在遷移會與上游全面衝突。
- **[Q8]** `README.md` 於 Stage 1 更新；`project.md` 與 wiki 交由 Phase 5 處理（Rule 18）。
- **[Q9]** 保留 `pub get` 自動改寫的 `analysis_options.yaml` — 3.47 工具鏈的既定行為，revert 也會被寫回。
- **[Q10]** Built-in Kotlin 遷移不做，僅記錄 — Flutter 未來要淘汰的是「自行 apply KGP」這件事本身，牽動 example 的第三方依賴，超出基準對齊範圍。
- **[Q13]** SceneDelegate 不獨立成檔、不改 `project.pbxproj` — 官方遷移器用的是 engine 內建的 `FlutterSceneDelegate`（非新專案範本的 `$(PRODUCT_MODULE_NAME).SceneDelegate`）。原訂「新增檔案 + 手改 pbxproj 四處」是建立在錯誤前提上的高風險編輯，已作廢。
- **[Q14]** `@UIApplicationMain` → `@main` — 同檔同次編輯、邊際成本為零，且已在新版 Swift 棄用。
- **[Q15]** 插件註冊改用 `FlutterImplicitEngineDelegate` — 查證後確認這正是官方遷移器自身的輸出，非額外變數。
- **[Q17]** 補上兩個 federated 子 example 的 `dependency_overrides` — 既有缺陷（非 3.47 造成，已於 `main` 乾淨 worktree 重現），但阻斷了已核准的驗證項目；修法與 `flutter_inappwebview_android/example` 的 `1c12f440f` 完全一致，獨立 commit 以便單獨 revert。
- **[Q18]** SPM traits 錯誤**不做任何程式碼變更** — 經乾淨複測推翻「swift-collections 版本不相容」的假說，確認為首次 SPM 整合在冷快取下的一次性壞解析。

## Deviations

- **計畫分兩段執行**（Stage 1 Windows / Stage 2 macOS，共用同一分支與計畫），而非一次做完。理由：iOS/macOS 的實際建置驗證在 Windows 上不可能取得，硬做只會產出未驗證卻宣稱完成的變更。
- **Q13 的原決議在執行中作廢**。使用者原核准「照範本新增獨立 `SceneDelegate.swift` + 手動改 pbxproj 四處」，Stage 2 查證 SDK 後發現官方遷移器路徑完全不需要這些操作，改採零風險做法。本計畫因此**沒有任何 pbxproj 結構性手動編輯**。
- **Q17 為計畫外的既有缺陷修復**，嚴格說超出「只做基準對齊」的自我約束，納入理由為它阻斷已核准的驗證項目，且修法有同 repo 先例、無設計裁量空間。
- **Q18 一度導向錯誤處置**。曾以「四次建置矩陣」認定需更新 `Package.resolved` 至 1.6.0，但該矩陣建立在被前次實驗污染的共用快取上；還原變數後的乾淨複測證明上游原狀（1.3.0）即可通過，變更已全部還原。
- **D2b（Windows example 實跑目視）未完成**，且無法在 macOS 執行。使用者於 2026-08-15 選擇「繼續歸檔」，此項作為已知缺口留存。

## Impact Files

### Android 工具鏈（Stage 1）
- `flutter_inappwebview/example/android/settings.gradle:20` — KGP `2.2.20` → `2.4.0`
- `flutter_inappwebview_android/example/android/settings.gradle` — 同上
- `flutter_inappwebview_android/android/build.gradle:37` — `minSdk 19` → `24`

### 套件層部署目標（Stage 1，migrator 永不觸及，須手動）
- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.swift:9` — `.iOS("12.0")` → `"15.0"`
- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios.podspec:34,39` — `s.platforms` 與 `core.platform` **兩處**皆 → `15.0`
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift:9` — `.macOS("10.15")` → `"12.0"`
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos.podspec:25` — `:osx, '10.15'` → `'12.0'`

### example 專案部署目標（Stage 2，由官方 migrator 自動改寫）
- `flutter_inappwebview/example/ios/{Podfile, Runner.xcodeproj/project.pbxproj, Flutter/AppFrameworkInfo.plist}`
- `flutter_inappwebview_ios/example/ios/{Podfile, Runner.xcodeproj/project.pbxproj, Flutter/AppFrameworkInfo.plist, Podfile.lock}`
- `flutter_inappwebview/example/macos/{Podfile, Runner.xcodeproj/project.pbxproj}`
- `flutter_inappwebview_macos/example/macos/{Podfile, Runner.xcodeproj/project.pbxproj, Podfile.lock}`
- 結果：`IPHONEOS_DEPLOYMENT_TARGET` 5 處 = 15.0（另 2 處既有 16.0 未動）、`MACOSX_DEPLOYMENT_TARGET` 6 處 = 12.0、4 個 Podfile 同步

### UIScene（Stage 2）
- `flutter_inappwebview_ios/example/ios/Runner/{AppDelegate.swift, Info.plist}` — **官方遷移器自動完成**（AppDelegate 逐字元命中範本 #4）
- `flutter_inappwebview/example/ios/Runner/{AppDelegate.swift, Info.plist}` — **手動套用**（含 `flutter_downloader` 註解故不命中範本），依遷移器輸出形狀撰寫，`flutter_downloader` 註解區塊原樣保留

### 子 example 修復（Stage 2，Q17）
- `flutter_inappwebview_ios/example/pubspec.yaml` — 新增 `dependency_overrides`（+4 行）
- `flutter_inappwebview_macos/example/pubspec.yaml` — 同上

### 文件與工具自動改寫
- `README.md:58-59` — 更新為 minSdk 24 / AGP 9.3.0 / iOS 15 / macOS 12
- `flutter_inappwebview/analysis_options.yaml`、`flutter_inappwebview/example/analysis_options.yaml`、`flutter_inappwebview_android/example/analysis_options.yaml`、`flutter_inappwebview_{ios,macos}/example/analysis_options.yaml` — `pub get` 自動附加 `analyzer: exclude:`（Q9）

## Details

### 3.47 的實際門檻（取自 SDK 原始碼，供未來升級比對）

`DependencyVersionChecker.kt`（唯一會 throw 的檢查）：Gradle warn 9.1.0 / error 8.14.0；Java 17/17；AGP warn 9.0.1 / error 8.11.1；KGP warn 2.3.20 / error 2.2.20；minSdk warn 24 / error 23。
`gradle_utils.dart`：template Gradle 9.3.1、AGP 9.1.0、KGP 2.4.0、compileSdk/targetSdk 36、minSdk 24。
部署目標 migrator 取代值：`ios_deployment_target_migration.dart:118` = 15.0、`macos_deployment_target_migration.dart:66` = 12.0。
本 repo 既有的 AGP 9.3.0 / Gradle 9.5.0 通過，因 `gradle_utils.dart:829` 對「比 `maxKnownAndSupportedAgpVersion`(9.2) 新」的 AGP 於 Gradle ∈ [9.3.1, 100.00] 時放行。

### UIScene 自動遷移器的行為（`migrations/uiscene_migration.dart`）

stable 預設啟用（`features.dart:294-304`，config `enable-uiscene-migration`、env `FLUTTER_UISCENE_MIGRATION`）。三個硬性前置條件：Info.plist 尚無 `UIApplicationSceneManifest`、`UIMainStoryboardFile` 必須等於 `Main`、`AppDelegate.swift` 需**逐字元命中** 5 個範本之一（比對前 `.trim()`）。不滿足即只印警告並指向 `flutter.dev/to/uiscene-migration`。寫入的 `UISceneDelegateClassName` 為 **`FlutterSceneDelegate`**（engine 內建），故不需新增檔案或改 pbxproj。

### 驗證結果

**已驗證**：四個 example 的 iOS 模擬器 / macOS 建置全通過；iOS 模擬器（iPhone 17 Pro / iOS 26.5）實跑 `flutter_inappwebview/example`——UIScene 下正常啟動、WebView 渲染、捲動、全螢幕進出、前後景切換（PID 不變、頁面狀態保留）；macOS 由使用者目視確認 Impeller 預設下呈現正常；podspec / `Package.swift` / Pods 專案三方部署目標一致（各 12 處）；UIScene 遷移警告重建後歸零。Stage 1：Android 兩個 example 建置通過、`flutter analyze` 無新增 error、Web 建置通過且 Wasm dry run succeeded、Windows example 建置通過。

**未驗證**：實體 iOS 裝置（本機未接）；Xcode 27 對 UIScene 的強制性（本機 26.6，且 SDK 查無此說法）；Linux（無環境）；Windows example 實跑目視（D2b，需 Windows 機器）。

### 環境基準

Stage 1（Windows 11）：Flutter 3.47.0 / Dart 3.13.0。
Stage 2（macOS 26.5.2）：Flutter 3.47.0 / Xcode 26.6 (17F113) / SDK iOS 26.5、macOS 26.5 / CocoaPods 1.17.0 / Swift 6.3.3。

### 附帶回報（未處理，僅記錄）

- `flutter_downloader` 不支援 SPM，Flutter 提示「未來版本將成為 error」——屬 example 的第三方依賴，非本套件。
- 本套件的 `Package.swift`（ios 與 macos）缺 `FlutterFramework` 依賴，Flutter 於建置時提示；目前不影響建置，屬上游的 SPM 適配議題。
- Flutter 建議 example 由 CocoaPods 改為純 SPM（`pod deintegrate`），屬獨立議題。
- **首次於新機器建置 iOS example 可能遇到一次性的 `Could not resolve package dependencies: Disabled default traits...`**。處置為清除解析狀態後重建（`flutter clean` + 移除 `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`、`ios/Pods`、`ios/Podfile.lock`），**切勿**修改 `Package.swift` 或 `Package.resolved`。
