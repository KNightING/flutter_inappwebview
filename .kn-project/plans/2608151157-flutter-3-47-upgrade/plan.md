<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608151157 - 對齊 Flutter 3.47.0 的平台基準

- Created: 2026-08-15
- Issue: KNightING/flutter_inappwebview#10
- Branch: `feature/2608151157-flutter-3-47-upgrade`
- Status: In Progress
- Completed: [Wait for Finish]

> **本計畫分兩段執行，共用同一個分支與同一份計畫。**
> **Stage 1（Windows，本次）**：Android 工具鏈、套件層的 iOS/macOS 部署目標宣告、README，
> 以及 Windows / Web 的實測。完成後 commit。
> **Stage 2（macOS，後續接手）**：example 的 Xcode 專案與 Podfile、UIScene 採用，
> 以及 iOS/macOS 的實際建置驗證。**不另開計畫**，直接在本分支續作。

## Goals

本機 Flutter SDK 已升至 **3.47.0 / Dart 3.13.0**（`flutter --version` 實測，2026-08-15）。
本計畫把本 repo 的平台宣告與建置設定對齊該版本的新基準，並逐項確認哪些是**必須改**、
哪些是**現在還能跑但下一版會斷**、哪些是**刻意不動**。

本計畫**只做基準對齊**，不夾帶任何功能或行為變更。

## Architecture

### 3.47.0 的實際門檻（取自本機 SDK 原始碼，非 blog 轉述）

Blog 是意圖，SDK 原始碼才是會實際擋下建置的東西。以下數值皆於 2026-08-15 從
`C:/Users/lxian/develop/flutter`（`flutter --version` 指向的 SDK）讀出：

`packages/flutter_tools/lib/src/android/gradle_utils.dart`：

| 常數 | 值 |
| :--- | :--- |
| `templateDefaultGradleVersion` (`:36`) | `9.3.1` |
| `templateAndroidGradlePluginVersion` (`:44`) | `9.1.0` |
| `templateKotlinGradlePluginVersion` (`:52`) | `2.4.0` |
| `compileSdkVersionInt` (`:61`) | `36` |
| `minSdkVersionInt` (`:63`) | `24`（3.44 時為 21） |
| `targetSdkVersion` (`:65`) | `36` |
| `maxKnownAndSupportedGradleVersion` (`:85`) | `9.3.1` |
| `maxKnownAndSupportedKgpVersion` | `2.4.0` |
| `maxKnownAndSupportedAgpVersion` (`:98`) | `9.2`（3.44 時為 `9.1`） |
| `maxKnownAgpVersionWithFullKotlinSupport` (`:104`) | `9.1.0` |

`packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`（**這支才會 throw**）：

| 項目 | warn | error（低於即建置失敗） |
| :--- | :--- | :--- |
| Gradle (`:94`,`:96`) | 9.1.0 | 8.14.0 |
| Java (`:99`,`:101`) | 17 | 17 |
| AGP (`:103`,`:105`) | 9.0.1 | 8.11.1 |
| KGP (`:107`,`:109`) | **2.3.20** | **2.2.20** |
| minSdk (`:114`,`:117`) | 24 | 23 |

iOS / macOS 最低部署版本（migrator 的取代值即官方新下限）：

- `packages/flutter_tools/lib/src/ios/migrations/ios_deployment_target_migration.dart:118` —
  `IPHONEOS_DEPLOYMENT_TARGET = 15.0;`（原 13.0 會被自動改寫）
- `.../macos/migrations/macos_deployment_target_migration.dart:66` —
  `MACOSX_DEPLOYMENT_TARGET = 12.0;`（原 10.15 會被自動改寫）

> **注意 migrator 的作用範圍**：它只改 **app 專案**（`example/ios`、`example/macos` 的
> `project.pbxproj` 與 `Podfile`），**不會**碰套件自己的 `.podspec` 與 `Package.swift`。
> 後者是本計畫真正要手動處理的部分。

### 現況判定：哪些已經合格、哪些不合格

| 項目 | 現值 | 3.47 要求 | 判定 |
| :--- | :--- | :--- | :--- |
| AGP（example settings.gradle） | 9.3.0 | ≥ 8.11.1（error），template 9.1.0 | ✅ 通過（落入「比已知版本新」分支） |
| Gradle wrapper | 9.5.0 | AGP ≥ 9.2 時需 Gradle ≥ 9.3.1 | ✅ 通過 |
| Java | 17 | 17（error 門檻） | ✅ 剛好合格 |
| **KGP** | **2.2.20** | error 2.2.20 / warn 2.3.20 | ⚠️ **剛好踩在 error 線上**，現在只 warn，下一次調升即斷 |
| **套件 `minSdk`** | **19** | Flutter 支援下限 24（app 端 error 23） | ⚠️ 落後兩級 |
| example `targetSdk` | 36 | 36 | ✅ |
| `compileSdk` | `flutter.compileSdkVersion`（=36） | 36 | ✅ 跟隨 SDK，不需動 |
| **iOS 套件部署目標** | **12.0** | 15.0 | ❌ 落後 |
| **macOS 套件部署目標** | **10.15** | 12.0 | ❌ 落後（2026-08-14 才從 10.14 升上來） |
| example iOS/macOS 專案 | 13.0 / 10.15 | 15.0 / 12.0 | ❌ 落後（但 migrator 會自動改寫） |
| Web（`dart:html`） | 已用 `package:web` | `package:web` | ✅ 已合格，無需遷移 |
| **iOS example UIScene** | **未採用** | 未來 iOS 版本要求；3.47 已內建自動遷移器 | ⚠️ 見 Q4 / Q12 更正 / Q16 |

### AGP 9.3.0 為何仍然通過

`gradle_utils.dart:829` 對「比 `maxKnownAndSupportedAgpVersion`(9.2) 新」的 AGP 是放行的，
條件是 Gradle 落在 `[9.3.1, 100.00]`。本 repo 的 9.5.0 在範圍內，因此**上一個 AGP 計畫的
成果在 3.47 下不需要退版，也不需要再升**。3.44 時該分支要求的 Gradle 下限是 9.1.0，
3.47 提高到 9.3.1——若當初停在 Gradle 9.1.0，此刻就會被擋下。

### 本機可驗證範圍（Windows 11）

- ✅ 可實測：Android、Windows、Web。
- ❌ 無法實測：iOS、macOS（需 macOS + Xcode）、Linux。
  對這三者的變更屬於**宣告值調整**，只能靠靜態比對與 SDK 常數佐證，無法建置驗證。
  此限制必須寫進最終回報，不得以「已完成」含混帶過。

### Impeller 桌面預設化的潛在風險

3.47 起 Impeller 成為 macOS / Windows / Linux 的**預設**渲染後端（取代 Skia）。
本 repo 的桌面實作都走**外部 texture**路徑，不是純 widget：

- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge_fallback.cc`
- `flutter_inappwebview_linux/linux/in_app_webview/inappwebview_egl_texture.cc`

外部 texture 在後端切換時是典型的破裂點（黑畫面、閃爍、尺寸錯位）。
本計畫**不預先修改**這些檔案——沒有實測就改是臆測——但把 Windows example 的實跑
列為驗證項；Linux 無法在本機驗證，只能標記為已知未驗證區域。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-15 在 `main`（與 `origin/main` 零分歧）上實際確認。

### 既有 — Android 工具鏈
- `flutter_inappwebview/example/android/settings.gradle:20` — `id "org.jetbrains.kotlin.android" version "2.2.20"`，
  正好等於 Flutter 的 KGP error 門檻，需升至 template 值 `2.4.0`。
- `flutter_inappwebview_android/example/android/settings.gradle` — 同性質（行號執行時確認）。
- `flutter_inappwebview_android/android/build.gradle:37` — `minSdk 19`，落後 Flutter 支援下限 24。

### 既有 — iOS 部署目標（套件本體，migrator 不會碰）
- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.swift:9` — `.iOS("12.0")`。
- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios.podspec:34` — `s.platforms = { :ios => '12.0' }`
  以及 `:38` 的 `core.platform = :ios, '12.0'`（**兩處都要改，漏一處會不一致**）。

### 既有 — macOS 部署目標（套件本體）
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos/Package.swift:9` — `.macOS("10.15")`。
- `flutter_inappwebview_macos/macos/flutter_inappwebview_macos.podspec:26` — `s.platform = :osx, '10.15'`。

### 既有 — example 的 iOS/macOS 專案（migrator 會自動改寫，但檔案需入版控）
- `flutter_inappwebview/example/ios/Podfile:2` — `platform :ios, '13.0'`。
- `flutter_inappwebview/example/ios/Runner.xcodeproj/project.pbxproj:579,632` — `IPHONEOS_DEPLOYMENT_TARGET = 13.0`
  （`:473,511` 已是 16.0，不需動）。
- `flutter_inappwebview_ios/example/ios/Runner.xcodeproj/project.pbxproj:477,608,657` — 同上 13.0。
- `flutter_inappwebview_ios/example/ios/Podfile:2` — 註解掉的 `# platform :ios, '13.0'`（僅註解，一併更新以免誤導）。
- `flutter_inappwebview/example/macos/Podfile:1`、
  `flutter_inappwebview/example/macos/Runner.xcodeproj/project.pbxproj:399,478,525` — `10.15`。
- `flutter_inappwebview_macos/example/macos/Podfile:1`、
  `flutter_inappwebview_macos/example/macos/Runner.xcodeproj/project.pbxproj:559,651,698` — `10.15`。

### 既有 — 文件
- `README.md:58` — `minSdkVersion >= 19`、`AGP >= 7.3.0`，與現況（AGP 9.3.0）已嚴重脫節。
- `README.md:59` — `iOS 12.0+`。
- `.kn-project/project.md` 的「平台基準」段 — 記載 `AGP 8.13.1`、`minSdkVersion 19`、
  `macOS 10.15`、「AGP 9.0 尚未導入」，**四項皆已與程式碼不符**（AGP 計畫已升至 9.3.0）。
  依 Rule 18，此落差在此揭露；文件修正交由 Phase 5 的 wikification 處理，不在 Phase 3 就地改。

### 既有 — UIScene（見 Q4，未核准前不動）
- `flutter_inappwebview/example/ios/Runner/AppDelegate.swift:5` — `@UIApplicationMain`，未採用 UIScene。
- `flutter_inappwebview/example/ios/Runner/Info.plist` — 無 `UIApplicationSceneManifest`。
- `flutter_inappwebview_ios/example/ios/Runner/Info.plist` — 同上。

### 不需變更（已確認合格，列出以免重複調查）
- `flutter_inappwebview_web/lib/web/*.dart` — 已使用 `package:web`，非 `dart:html`，Wasm 相容。
- 各套件 `pubspec.yaml` 的 `environment:`（`sdk: ^3.8.0` / `flutter: ">=3.32.0"`）——見 Q3。
- `flutter_inappwebview_android/android/build.gradle:11` — AGP classpath 9.3.0，通過。
- 兩個 example 的 `gradle-wrapper.properties` — Gradle 9.5.0，通過。

### 新增
- 無。

## Open Questions / 待確認事項

### Q1. iOS / macOS 部署目標要不要升 — 影響：範圍最大的一項，且本機無法驗證
Flutter 3.47 的下限是 iOS 15 / macOS 12。套件的 `.podspec` 與 `Package.swift` **不會**被
migrator 自動改寫，維持 12.0 / 10.15 短期仍可建置（只是低於 Flutter 支援範圍），
但這正是 2026-08-14 那次 macOS 建置失敗的成因類型——Xcode 對舊部署目標的可用性檢查會直接擋下。

代價：升上去等於**放棄 iOS 12–14 / macOS 10.15–11 的使用端**，且會擴大與上游的 delta
（上游目前仍是 12.0 / 10.15，未跟進 3.47）。本 repo 純自用、不回貢，delta 的成本只在
「拉取上游更新時可能衝突」這一項。

- [x] A.（建議）**套件與 example 全部升至 iOS 15 / macOS 12**。理由：與 Flutter 3.47 完全對齊，
  一次做完；且 example 遲早會被 migrator 自動改寫，不如一併納入版控避免無主 diff。
- [ ] B. **只升 example，套件宣告維持 12.0 / 10.15**。delta 較小，但套件宣告會低於 Flutter 支援下限，
  屬於「宣稱支援其實未驗證」的狀態。
- [ ] C. **完全不動**，等實際在 macOS 上撞到再處理。

狀態：✅ 已確認（2026-08-15）

**分段落點**：套件本體的 `.podspec` / `Package.swift` 在 **Stage 1** 就改——它們是純文字宣告，
且 migrator 永遠不會碰，留著只會讓 Stage 2 多一件雜事。example 的 `Podfile` / `project.pbxproj`
留給 **Stage 2**，因為在 macOS 上 `flutter build` 會由 migrator 自動改寫，屆時的 diff 才是可信的。

### Q2. Kotlin Gradle Plugin 2.2.20 → 2.4.0 — 影響：下一次 Flutter 升級是否會斷
現值 `2.2.20` **正好等於** `errorKGPVersion`（`DependencyVersionChecker.kt:109`），
判定式是 `version < errorKGPVersion` 才 throw，因此現在**只出 warning 不失敗**。
但它同時低於 `warnKGPVersion` 2.3.20，等於已進入警告區；Flutter 下一次調升 error 門檻即建置失敗。

此項本機**可實測**（Android example 可建置）。

- [x] A.（建議）升至 `2.4.0`（Flutter 3.47 的 template 值），兩個 example 的 `settings.gradle` 同步改。
- [ ] B. 升至 `2.3.20`（剛好脫離 warn 區），改動較保守。
- [ ] C. 不動，等真的斷掉再說。

狀態：✅ 已確認（2026-08-15）→ Stage 1

### Q3. `pubspec.yaml` 的 `environment:` 下限要不要跟著抬 — 影響：使用端的 SDK 相容範圍
現為 `sdk: ^3.8.0` / `flutter: ">=3.32.0"`，這是**下限**，在 Flutter 3.47 / Dart 3.13 下完全合法，
不抬也不會有任何錯誤。抬高等於主動切斷舊 SDK 的使用端。

- [x] A.（建議）**不動**。理由：下限就是下限，抬高只有壞處沒有好處；且會擴大與上游的 delta。
- [ ] B. 抬到 `flutter: ">=3.47.0"` / `sdk: ^3.13.0`，明確宣告「本 fork 只保證 3.47」。

狀態：✅ 已確認（2026-08-15）

### Q4. iOS example 要不要採用 UIScene — 影響：Xcode 27 下 example 能否啟動
3.47 說明「以 Xcode 27 建置且未採用 UIScene 的 app 啟動即失敗」。本 repo 兩個 iOS example
都還是 `@UIApplicationMain` + 無 `UIApplicationSceneManifest`。

但這**純屬 example app 的事**，與套件本體無關；且本機是 Windows，改了也**無法驗證**，
屬於盲改。上游遲早會自己跟進，屆時會與本 fork 的改動衝突。

- [ ] A. **本次不做**，記入 wiki 的已知落差，等有 macOS 環境時另開計畫。
- [ ] B. 一併照 Flutter 3.47 範本加上 `UIApplicationSceneManifest` 與 `SceneDelegate`（盲改）。
- [x] **C.（使用者於 2026-08-15 指定）列入本計畫的 Stage 2，由 macOS 環境執行並驗證。**
  這是 A 與 B 的中間解：不在 Windows 盲改（B 的風險），也不推遲到另一份計畫（A 的斷點），
  而是留在同一份計畫、同一個分支上，等有 Xcode 的環境接手。

狀態：✅ 已確認（2026-08-15）→ Stage 2

### Q5. `flutter_inappwebview_android` 的 `minSdk 19` 要不要升到 24 — 影響：宣稱的 Android 支援範圍
Flutter 3.47 的支援下限已是 API 24（`minSdkVersionInt = 24`），app 端低於 23 直接 error。
套件宣告 19 目前不會擋下建置（AGP 只在「library 高於 app」時報錯），但它是**不實的宣稱**：
Flutter 早已不支援 19，本套件也從未在 19 上驗證過。

- [x] A.（建議）升至 `24`，與 Flutter 支援下限一致，並同步更新 `README.md:58`。
- [ ] B. 升至 `21`（3.44 時的 Flutter 下限），較保守。
- [ ] C. 不動。

狀態：✅ 已確認（2026-08-15）→ Stage 1

### Q6. Impeller 桌面預設化的驗證要做到什麼程度 — 影響：Windows/Linux 是否留下未驗證區域
3.47 起 Impeller 是桌面預設。本 repo 的 Windows / Linux 都走外部 texture，是典型破裂點。

- [x] A.（建議）**只驗 Windows**（本機可跑），實跑 example 確認 WebView 正常顯示、縮放、捲動；
  Linux 標記為「已知未驗證」寫進計畫結論。發現問題再另開計畫修，不在本計畫夾帶。
- [ ] B. 連 Windows 也不驗，本計畫只做宣告值對齊。
- [ ] C. 先在 Windows 以 Skia opt-out 對照測試，量化差異（工時較高）。

狀態：✅ 已確認（2026-08-15）→ Stage 1（macOS 的 Impeller 驗證順帶落在 Stage 2）

### Q7. Material / Cupertino 獨立套件遷移 — 影響：未來的 breaking change
3.47 讓 `material_ui` / `cupertino_ui` 到 1.0，SDK 內的 `flutter/material.dart` 預告
**2026 年 11 月**正式棄用，並提供 `dart fix --apply --code=migrate_design_widgets`。

- [x] A.（建議）**本次不做**。理由：尚未棄用，現在遷移會產生大量 import 變更、與上游全面衝突，
  完全違反「delta 極小」鐵則。等上游動作後再跟。
- [ ] B. 現在就跑 `dart fix` 遷移。

狀態：✅ 已確認（2026-08-15）

### Q8. 本計畫要不要順手處理 `project.md` 與 `README.md` 的過期記載 — 影響：範圍邊界
`project.md` 的「平台基準」有四項與程式碼不符（AGP 8.13.1、minSdk 19、AGP 9.0 尚未導入、
macOS 10.15），`README.md:58-59` 也停留在 AGP 7.3 / minSdk 19 / iOS 12。

- [x] A.（建議）`README.md` 在 Phase 3 一併更新（它是對使用端的公開宣稱，與本計畫改的值直接對應）；
  `project.md` 與 wiki 交由 Phase 5 的 wikification 統一處理（Rule 18 要求）。
- [ ] B. 兩者都留給 Phase 5。
- [ ] C. 兩者都不動，另開文件計畫。

狀態：✅ 已確認（2026-08-15）→ Stage 1

### Q9.（執行中浮現）`flutter pub get` 自動改寫 `analysis_options.yaml` 要不要保留 — 影響：delta 大小
Flutter 3.47 的 `pub get` 會**主動改寫** `analysis_options.yaml`，輸出
`Upgrading analysis_options.yaml to exclude build and platform directories`，
並附加 `analyzer: exclude:` 區塊（`build/**`、`android/**`、`ios/**`、`web/**`、
`windows/**`、`macos/**`、`linux/**`）。本次命中兩個檔案：

- `flutter_inappwebview/analysis_options.yaml`
- `flutter_inappwebview/example/analysis_options.yaml`

這不是我改的，是工具自動行為。**revert 也沒用——下一次 `pub get` 會再寫回來。**

- [x] A.（建議）保留並納入本次 commit。理由：它是 3.47 工具鏈的既定行為，擋不掉；
  納入版控至少讓它成為一次有紀錄的變更，而不是每個開發者機器上的無主 diff。
- [ ] B. revert 掉，接受它每次 `pub get` 後重新出現。
- [ ] C. 保留但獨立成一個 commit，與基準對齊的變更分開。

狀態：✅ 已確認（2026-08-15）

實際命中**三**個檔案（原估兩個）：另有 `flutter_inappwebview_android/example/analysis_options.yaml`，
由第二個 example 的 `pub get` 觸發。

### Q10.（執行中浮現，**比 KGP 版本更重要**）Built-in Kotlin 遷移 — 影響：未來 Flutter 版本能否建置
Android 建置實測（2026-08-15，`flutter build apk --debug` 成功，exit 0）時，Flutter 3.47 印出：

```
WARNING: Your Android app project: app ... applies the Kotlin Gradle Plugin,
which will cause build failures in future versions of Flutter.
Please migrate your app to Built-in Kotlin ...
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
file_picker, flutter_downloader
```

也就是說：**Flutter 未來要淘汰的不是「舊版 KGP」，而是「自行 apply KGP」這件事本身。**
Q2 把 KGP 升到 2.4.0 解掉的是當下的版本警告，但這條路最終會被整條移除。
注意警告同時點名 `file_picker` 與 `flutter_downloader`——那是 **example 的依賴**，不是本套件，
本套件（`flutter_inappwebview_android`）本身是純 Java、不 apply KGP，**不在被點名之列**。

現況不會失敗，只是警告。遷移涉及 example 的 Gradle 結構與第三方套件的相容性，
明顯超出「基準對齊」的範圍。

- [x] A.（建議）本計畫**不做**，僅記錄。理由：現在不會斷；遷移牽動 example 依賴的第三方套件，
  屬於獨立議題，夾帶進來會違反「只做基準對齊」的自我約束。
- [ ] B. 本計畫一併遷移 example 到 Built-in Kotlin。
- [ ] C. 另開計畫追蹤。

狀態：✅ 已確認（2026-08-15）——僅記錄，留待 Flutter 實際強制時再處理。

### Q11.（執行中浮現）Windows 驗證被本機環境擋住 — 影響：Q6 的驗證能否完成
`flutter build windows --debug` 失敗，但**與 3.47 無關**：

```
error MSB3073: NUGET-NOTFOUND install Microsoft.Windows.CppWinRT ...
error MSB3073: NUGET-NOTFOUND install Microsoft.Web.WebView2 ...
```

`which nuget` 確認 **NuGet CLI 不在 PATH 上**。這正是 `README.md:60` 早已載明的 Windows 前置需求
（`NuGet CLI available on your PATH`），屬於本機環境缺件，不是程式碼或版本問題。
Visual Studio Build Tools 2022 本身存在且被 `flutter doctor` 認可。

- [ ] A. 安裝 NuGet CLI 後重跑。
- [ ] B. 放棄 Windows 驗證，與 Linux 一併標記為「已知未驗證」。
- [x] **C.（實際採用）不必安裝任何東西——nuget.exe 早就在 build 目錄裡。**

狀態：✅ 已解決（2026-08-15）

**真正的成因（初判有誤，此處更正）**：一開始判定為「本機缺 NuGet CLI」，**不正確**。
Flutter 自己會抓一支 nuget.exe（6.0.0）放到
`example/build/windows/x64/_deps/nuget-src/nuget.exe`——日誌那句
`Nuget.exe not found, trying to download or use cached version` 即此機制，Flutter 自己那層用得很順。

卡住的是套件端的 `flutter_inappwebview_windows/windows/CMakeLists.txt:26` 的
`find_program(NUGET nuget)`：它**只搜 PATH**，看不到 Flutter 放在 `_deps/` 的那支；
且**沒有 fallback**，找不到就只 `message(NOTICE)`，照樣把字面值 `NUGET-NOTFOUND`
當成命令塞進 vcxproj，於是 `exit 9009`。結果還會被黏進 `CMakeCache.txt`
（`NUGET:FILEPATH=NUGET-NOTFOUND`），之後就算裝了 nuget，不清 cache 也一樣失敗。

**驗證方式**：把那支 nuget.exe 的目錄加進 PATH、清掉 `build/windows` 重建 → **成功**，
`√ Built build\windows\x64\runner\Debug\example.exe`（519s），且
`build/windows/x64/packages/` 出現四個 `-ExcludeVersion` 目錄
（`Microsoft.Web.WebView2`、`Microsoft.Windows.CppWinRT`、
`Microsoft.Windows.ImplementationLibrary`、`nlohmann.json`），證明 nuget install 確實跑過。

**與 WebView2 無關**：本機 WebView2 **Runtime** 151.0.4129.78 早已安裝（註冊表確認）。
建置需要的是 `Microsoft.Web.WebView2` **SDK NuGet 套件**（標頭 + Loader），兩者不互相取代。

**與 Flutter 3.47 無關**：這是本套件長期存在的行為，不是本次升級造成的。

**遺留注意事項**：本次 `NUGET:FILEPATH` 指向的是**暫存目錄**下的 nuget.exe，
僅供本次驗證。該目錄被清掉後，下次 CMake 重新 configure 會再度失敗。
長期解法是把 nuget.exe 放到穩定位置並加入 PATH（或依 README 安裝 NuGet CLI）。
此狀態只存在於 gitignore 的 `build/` 內，不影響版控。

### Q12.（Stage 2 浮現）本機是 Xcode 26.4.1，不是 Xcode 27 — 影響：Q4 的驗證強度上限
Q4 採用 UIScene 的理由是「以 Xcode 27 建置且未採用 UIScene 的 app 啟動即失敗」。
本機實測（2026-08-15）為 **Xcode 26.4.1（Build 17E202）**、macOS 26.5.2。

**更新後複測（同日，使用者回報已更新 Xcode）**：實際為 **26.6（Build 17F113）**，
SDK 為 iOS 26.5 / macOS 26.5。**仍非 Xcode 27**，因此本題的判斷與驗證強度上限**完全不變**。
此處記下兩個版本是為了避免日後誤以為「更新過就等於驗證過」。

因此**「不採用就啟動失敗」這個前提，在本機無法重現**——Xcode 26 下不採用 UIScene 的 app
仍能正常啟動。本機能驗證的是**反向命題**：採用 UIScene 之後，在 Xcode 26 / iOS 26 模擬器上
不會壞掉。這是有價值的（採用本身有風險，需確認無回歸），但**不等於**驗證了 Xcode 27 的行為。

此落差必須誠實寫進結論，不得以「UIScene 已驗證」含混帶過。

- [x] **A.（使用者於 2026-08-15 確認）** 仍照 Q4/C 採用，並明確標註「Xcode 27 的強制性未在本機驗證」。
- [ ] B. 既然本機無法重現該強制性，Stage 2 不做 UIScene，退回 Q4/A（記入 wiki，等有 Xcode 27 再說）。

狀態：✅ 已確認（2026-08-15）

#### ⚠️ 前提更正（2026-08-15，使用者質疑後查證 SDK）

使用者指出「商城裡沒有 Xcode 27」。據此**直接查本機 SDK 原始碼**，結果推翻了原本的敘述：

| 查證項目 | 結果 |
| :--- | :--- |
| SDK 內 "Xcode 27" 字樣 | **零筆**（`xcode.dart` / `xcode_validator.dart` 皆無） |
| `xcode.dart:24` `xcodeRequiredVersion` | **15** |
| `xcode.dart:28` `xcodeRecommendedVersion` | **16** |
| SDK 警告的實際措辭 | `uiscene_migration.dart:299` — **"upcoming iOS versions"**，非「Xcode 27」 |

**結論**：Q4 與本題原本引用的「以 Xcode 27 建置且未採用 UIScene 的 app 啟動即失敗」，
是 Stage 1 從 blog 轉述的說法，**無法在 SDK 原始碼中佐證**（違反 Rule 18 的佐證標準，此處更正）。
SDK 能佐證的只有較弱的版本：**UIScene 是「未來 iOS 版本」的requirement，時程未由 SDK 指明**。

Xcode 27 本身是否已發布，**本計畫無從查證**，不作任何主張。
商城查無此版本與「尚未發布」相符，但這不是本計畫需要斷定的事。

**對決策的影響：無。** 採用 UIScene 的理由從「Xcode 27 會擋」改為
「Flutter 官方工具已內建遷移器且 stable 預設啟用，方向明確」——**理由更強而非更弱**（見 Q16）。
改變的只是**結論的措辭**：不得宣稱「為了 Xcode 27」，應寫「為未來 iOS 版本的 UIScene 要求預作準備」。

### Q13.（Stage 2 浮現）SceneDelegate 要獨立成檔還是併入 AppDelegate.swift — 影響：pbxproj 改動風險
Flutter 3.47 的 app 範本（本機 SDK 實際讀出，
`packages/flutter_tools/templates/app/ios.tmpl/Runner/`）採用 UIScene 的形狀是三件事：

1. `Info.plist` 加 `UIApplicationSceneManifest`，其 `UISceneDelegateClassName`
   為 `$(PRODUCT_MODULE_NAME).SceneDelegate`
2. 新增 `SceneDelegate.swift`，內容僅 `class SceneDelegate: FlutterSceneDelegate {}`
3. `AppDelegate` 改為 `FlutterImplicitEngineDelegate`，插件註冊移到
   `didInitializeImplicitFlutterEngine`

其中第 2 點若照範本**新增獨立檔案**，就必須手動改 `project.pbxproj`
（`PBXFileReference` + `PBXBuildFile` + `PBXSourcesBuildPhase` + group 四處），
那是本次改動中**唯一有實質破壞風險**的操作。

`UISceneDelegateClassName` 是以 **module + 類別名**解析的，與檔名無關——
因此把 `class SceneDelegate: FlutterSceneDelegate {}` 直接寫在既有的
`AppDelegate.swift` 裡，功能完全等價，且**完全不需要動 pbxproj**。

- [ ] ~~A. 併入 `AppDelegate.swift`~~ — **作廢**，見下方更正。
- [ ] ~~B. 照範本新增獨立 `SceneDelegate.swift` + 手動改 pbxproj 四處~~ — **作廢**，見下方更正。
- [x] **C.（2026-08-15 查證 SDK 後新增，取代 A/B）跟隨官方遷移器的做法：
  `UISceneDelegateClassName` 直接用 engine 內建的 `FlutterSceneDelegate`，
  不新增任何 Swift 檔案，不碰 `project.pbxproj`。**

狀態：✅ 已更正（2026-08-15）

#### ⚠️ A/B 為何都作廢

本題原本的前提是「採用 UIScene 必須有一個自己的 SceneDelegate 類別」——**這個前提錯了**。

我原先是照**新專案範本**（`app/ios.tmpl`）的形狀規劃，那份範本確實用
`$(PRODUCT_MODULE_NAME).SceneDelegate` 並附一個 `SceneDelegate.swift`。
但**既有專案的遷移路徑**走的是另一條：`uiscene_migration.dart:277` 寫入的
`UISceneDelegateClassName` 是 **`FlutterSceneDelegate`**——engine 已經提供的類別。

兩條路都合法，但遷移路徑：

- **不新增檔案** → 不需要 `PBXFileReference` / `PBXBuildFile` / `PBXSourcesBuildPhase` / group 四處編輯
- **因此本計畫原本唯一的高風險操作，整個消失**

原本因採 B 而加上的「pbxproj 改完先驗證可解析、失敗即還原」防線，**隨之不再需要**。

### Q14.（Stage 2 浮現）兩個 iOS example 的 AppDelegate 屬性不一致 — 影響：是否順手統一
- `flutter_inappwebview/example/ios/Runner/AppDelegate.swift:5` — `@UIApplicationMain`（**已在新版 Swift 棄用**）
- `flutter_inappwebview_ios/example/ios/Runner/AppDelegate.swift:4` — `@main`（現行寫法）

若執行 Q4/C 的 UIScene 採用，前者無論如何都要動到該檔案，順手改為 `@main` 的邊際成本為零。
但這已越過「基準對齊」一步，屬於既有的、與 3.47 無關的落差。

- [x] **A.（使用者於 2026-08-15 確認）** 採用 UIScene 時一併改為 `@main`
  （同一檔案、同一次編輯，且 `@UIApplicationMain` 已棄用）。
- [ ] B. 不動，僅記錄落差。

狀態：✅ 已確認（2026-08-15）

### Q15.（Stage 2 浮現）插件註冊要不要跟進 `FlutterImplicitEngineDelegate` — 影響：改動幅度
3.47 範本把 `GeneratedPluginRegistrant.register` 從 `didFinishLaunchingWithOptions`
移到 `didInitializeImplicitFlutterEngine(_:)`。舊寫法在 3.47 下**仍可運作**，不是必須。

注意 `flutter_inappwebview/example` 的 AppDelegate 內有 `flutter_downloader` 的
註冊 callback（目前整段註解掉），改動時需原樣保留，不得順手清理。

- [ ] A.（建議）**維持現行 `didFinishLaunchingWithOptions` 註冊**。理由：UIScene 採用與插件註冊時機
  是兩件獨立的事，一次只動一個變數；出問題時才能定位是誰造成的。
- [x] **B.（使用者於 2026-08-15 指定）** 一併跟進範本的 `FlutterImplicitEngineDelegate` 寫法。

狀態：✅ 已確認（2026-08-15）

**已揭露的取捨**：本選項與建議相反，等於在同一次 commit 內同時改動
「UIScene 採用」與「插件註冊時機」兩個變數。使用者已知悉並採納。
**因應**：F-B 的實跑若出現插件相關異常（例如 WebView 未註冊、平台通道無回應），
處置方式是先把註冊改回 `didFinishLaunchingWithOptions` 二分定位，
而非直接推斷為 UIScene 的問題。
`flutter_inappwebview/example` 內既有的 `flutter_downloader` 註解區塊原樣保留，不順手清理。

### Q16.（Stage 2 浮現，**推翻 Q13 的前提**）Flutter 3.47 內建 UIScene 自動遷移器

查證 Q12 時發現 `packages/flutter_tools/lib/src/migrations/uiscene_migration.dart`（314 行），
由 `ios/mac.dart:186` 在 iOS 建置流程中呼叫，旗標為 `featureFlags.isUISceneMigrationEnabled`。

**stable channel 預設啟用**（`features.dart:294-304`）：

```
configSetting: 'enable-uiscene-migration'
environmentOverride: 'FLUTTER_UISCENE_MIGRATION'
stable: FeatureChannelSetting(available: true, enabledByDefault: true)
```

即：**只要在 macOS 上跑 `flutter build ios`，它就會自動嘗試遷移**，與部署目標 migrator 同一個機制。

#### 遷移器的實際行為（逐行讀出，非推測）

`_migrateInfoPlist()`（`:270-283`）插入的 `UIApplicationSceneManifest` 為：

```json
{
  "UIApplicationSupportsMultipleScenes": false,
  "UISceneConfigurations": {
    "UIWindowSceneSessionRoleApplication": [{
      "UISceneClassName": "UIWindowScene",
      "UISceneDelegateClassName": "FlutterSceneDelegate",
      "UISceneConfigurationName": "flutter",
      "UISceneStoryboardFile": "Main"
    }]
  }
}
```

`_migrateAppDelegate()`（`:236-268`）把 `AppDelegate.swift` 整份取代為
`newSwiftAppDelegate`（`:170-186`）——即 `@main` + `FlutterImplicitEngineDelegate` +
`didInitializeImplicitFlutterEngine` 註冊。

**關鍵差異**：`UISceneDelegateClassName` 是 **`FlutterSceneDelegate`**（engine 內建），
**不是**新專案範本用的 `$(PRODUCT_MODULE_NAME).SceneDelegate`。
因此遷移路徑**不新增任何 Swift 檔案，也完全不碰 `project.pbxproj`**。

#### 自動遷移的三個硬性前置條件

1. `Info.plist` 尚無 `UIApplicationSceneManifest`（`:206-209`）
2. `Info.plist` 的 `UIMainStoryboardFile` **必須等於 `Main`**（`:212-224`）
3. `AppDelegate.swift` 內容**逐字元命中** 5 個範本之一（`:236-247`，比對前 `.trim()`）

不滿足即**不自動改**，只 `printError` 指向 `https://flutter.dev/to/uiscene-migration`。

#### 本 repo 兩個 iOS example 的實際判定（2026-08-15 程式化比對）

| example | `UIMainStoryboardFile` | AppDelegate 比對 | 判定 |
| :--- | :--- | :--- | :--- |
| `flutter_inappwebview_ios/example` | `Main` ✅ | **命中範本 #4** | ✅ **會自動遷移** |
| `flutter_inappwebview/example` | `Main` ✅ | ❌ 不命中任一範本 | ⚠️ **只印警告，需手動** |

後者不命中的原因是該檔含 `//import flutter_downloader`、`@UIApplicationMain` 後多一個空行、
以及檔尾註解掉的 `registerPlugins` 區塊——與範本不是逐字元相同。

#### 對計畫的影響

- **Q13 的 A/B 兩選項作廢**，改為跟隨遷移器（見 Q13 的更正）。本計畫唯一的高風險編輯消失。
- **Q14（`@main`）與 Q15（`FlutterImplicitEngineDelegate`）的使用者決議，
  正好等於遷移器的輸出**——兩者不需另行實作，自動遷移即達成。
- 手動處理的那個 example，**照遷移器的輸出形狀寫**，使兩個 example 結果一致。
  其中 `flutter_downloader` 的註解區塊需決定去留（見下）。

- [x] **A.（採用）** 讓遷移器自動處理 `flutter_inappwebview_ios/example`；
  `flutter_inappwebview/example` 依遷移器的輸出形狀手動套用，保留 `flutter_downloader` 註解區塊。
- [ ] B. 兩個都手動，不倚賴遷移器（無理由，徒增出錯機會）。
- [ ] C. 先把 `flutter_inappwebview/example` 的 AppDelegate 改成與範本逐字元相同（刪掉註解），
  讓遷移器也能自動處理它——但這會刪掉 `flutter_downloader` 的既有註解，屬於夾帶清理。

狀態：✅ 已確認（2026-08-15）

### Q17.（Stage 2 執行中浮現，**阻斷性**）兩個 federated 子 example 的 `pub get` 失敗

F-A 一開工即撞到：`flutter_inappwebview_ios/example` 與 `flutter_inappwebview_macos/example`
的 `flutter pub get` **失敗**：

```
Because flutter_inappwebview_ios_example depends on flutter_inappwebview_ios from path
which depends on flutter_inappwebview_platform_interface ^1.4.0-beta.3,
flutter_inappwebview_platform_interface from hosted is required.
So, because flutter_inappwebview_ios_example depends on
flutter_inappwebview_platform_interface from path, version solving failed.
```

**是來源衝突，不是版本衝突**：套件的 `pubspec.yaml:23` 宣告 **hosted** 依賴
（`flutter_inappwebview_platform_interface: ^1.4.0-beta.3`，`:24` 的 path 是註解掉的），
而 example 宣告 **path** 依賴，pub 無法調和兩個來源。
本地 `flutter_inappwebview_platform_interface/pubspec.yaml:3` 的版本是 `1.4.0-beta.3`，
**版本本身完全滿足約束**——問題純粹在來源。

#### 三項查證（皆於 2026-08-15 實際執行）

1. **與本分支無關、與 Flutter 3.47 無關**：在 `main` 的乾淨 worktree 上重現同一則失敗。
   屬**既有問題**，不是本次升級造成。
2. **成因明確**：`flutter_inappwebview_android/example/pubspec.yaml:42-44` **已有**
   `dependency_overrides`，由 commit `1c12f440f`（"fix broken Android baseline on both example apps"）
   加入——這正是 Stage 1 的 Android 建置能通過的原因。
   而 `git log -S "dependency_overrides"` 對 ios / macos 兩個子 example **查無任何紀錄**，
   即**從未加過**。合理推斷：當時無 macOS 環境，這兩個子 example 跑不到，因此未被發現。
3. **修法已驗證**：在拋棄式 worktree 套用與 Android 相同的 4 行，兩者 `pub get` 皆通過
   （worktree 事後移除，未污染本 repo）。

#### 為何必須在本計畫處理

`flutter_inappwebview_ios/example` 是 **Q16 判定唯一會自動遷移 UIScene 的 example**
（AppDelegate 逐字元命中範本 #4）。它無法 `pub get`，F-B 的核心（驗證官方自動遷移）
就完全做不成，只剩手動的那一半——等於 UIScene 這項的驗證強度砍半。

- [x] **A.（使用者於 2026-08-15 核准）補上 `dependency_overrides`，納入本計畫。**
  內容與 `flutter_inappwebview_android/example` 完全相同，有 `1c12f440f` 的先例可循。
  **獨立成一個 commit**，不與基準對齊的變更混同。
- [ ] B. 跳過兩個子 example，只驗證 `flutter_inappwebview/example`。
- [ ] C. 另開計畫先修，本計畫暫停等待。

狀態：✅ 已確認（2026-08-15）

**範圍誠實揭露**：本項嚴格說已超出「只做基準對齊」的自我約束——它修的是既有缺陷，
不是 3.47 的對齊。納入的理由是**它阻斷了本計畫已核准的驗證項目**，
且修法有同 repo 的既有先例、無設計裁量空間。以獨立 commit 隔離，使其可被單獨 revert。

### Q18.（Stage 2 執行中浮現，**阻斷性**）SPM 鎖定檔把 swift-collections 釘在不相容的 1.3.0

F-A 的第一次 iOS 建置失敗（`flutter_inappwebview_ios/example`）：

```
xcodebuild: error: Could not resolve package dependencies:
  Disabled default traits on package 'swift-collections' (swift-collections)
  that declares no traits. This is prohibited to allow packages to adopt
  traits initially without causing an API break.
```

**與部署目標、UIScene 兩項變更皆無關**——那兩個 migrator 都已成功執行，失敗發生在其後的
SPM 依賴解析階段。

#### 成因鏈（逐項實測，非推測）

1. **Flutter 3.47 stable 預設啟用 SPM**（`features.dart:233-240`，
   `swiftPackageManager` 的 `stable: enabledByDefault: true`；本機 `flutter config` 未覆寫）。
   因此套件的 `Package.swift` 會被拉進 app 建置。
2. 套件宣告 `.package(url: swift-collections, from: "1.2.1")`
   （`flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.swift:15`）——
   語意為 `>=1.2.1 <2.0.0`，**本身沒有問題**。
3. 真正的釘選來自**已納入版控**的
   `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Package.resolved`，
   其 `version` 為 **`1.3.0`**。
4. swift-collections **1.3.0** 在 **Swift 6.3.3**（Xcode 26.6 隨附）的 traits 規則下被拒。

#### 實測矩陣（四次建置，皆於 2026-08-15）

| `Package.swift` 宣告 | 實際解析版本 | 結果 |
| :--- | :--- | :--- |
| `from: "1.2.1"`（上游原狀）+ 舊 `Package.resolved` | **1.3.0** | ❌ 失敗 |
| `"1.2.1"..<"1.3.0"` | 1.2.x | ✅ 通過 |
| `from: "1.4.1"` | 1.6.0 | ✅ 通過 |
| **`from: "1.2.1"`（上游原狀）+ 重新解析** | **1.6.0** | ✅ **通過**（34.4s，乾淨建置） |

最後一列是關鍵：**`Package.swift` 完全不必改**，只要讓 SPM 重新解析即可。
前面兩個「成功」的實驗因此都是不必要的繞路，已全部還原。

> **一次方法論失誤的自我更正**：第一次「還原後仍通過」的測試只跑了 7 秒且無 `Package.resolved`
> 產出，實為沿用前次成功建置的產物，**結論不成立**。已改以 `flutter clean` +
> 移除 `swiftpm/` / `Pods` / `Podfile.lock` 後重測，才取得上表最後一列的可信結果。
> 此處記錄以免日後誤信被污染的實驗。

#### ⚠️ 結論更正：**不是版本問題，是一次性的冷快取解析失敗**

上表原本導向「更新 `Package.resolved` 到 1.6.0」的處置。**該處置是錯的**，
被後續兩項觀察推翻：

1. **macOS 子 example 以 `1.3.0` 建置成功**（`Package.resolved` 未動、實際解析亦為 1.3.0）。
   若 1.3.0 與 Swift 6.3.3 的 traits 規則本質不相容，macOS 不可能通過。
2. **決定性複測**：把 iOS 的 `Package.resolved` **還原為上游原本的 1.3.0**，
   執行 `flutter clean` + 移除 `swiftpm/` / `Pods` / `Podfile.lock` 後重建
   → **`✓ Built`（28.3s），`Disabled default traits` 出現 0 次。**

**真正的成因**：首次啟用 SPM 整合時，在冷快取狀態下產生了一次壞的依賴解析。
清除解析狀態重建即自行消失，**與 swift-collections 的版本無關**。

#### 處置（更正後）

- [ ] ~~A. 更新兩個套件的 `Package.resolved` 至 1.6.0~~ — **作廢，已還原**。
- [ ] ~~B. 改 `Package.swift` 調整版本區間~~ — **作廢**。
- [ ] ~~C. 關閉 SPM~~ — 作廢。
- [x] **D.（採用）本 repo 不做任何變更。** 套件本體的 `Package.swift` 與 `Package.resolved`
  維持上游原狀，與上游 delta **為零**。

狀態：✅ 已確認（2026-08-15）

**留給後人的操作提示（非程式碼變更）**：在**首次**於新機器建置本 repo 的 iOS example 時，
可能遇到一次 `Could not resolve package dependencies: Disabled default traits...`。
處置是清除解析狀態後重建，**不要**去改 `Package.swift` 或 `Package.resolved`：

```
flutter clean
rm -rf ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm ios/Pods ios/Podfile.lock
flutter pub get && flutter build ios --simulator --debug
```

**方法論教訓（第二次，記錄以自我約束）**：本題我一度依「四次建置矩陣」就下結論，
但那四次都建立在**同一條被污染的快取時間線**上——先前實驗把 1.6.0 灌進共用快取，
才使得「改版本就會過」看似成立。真正有判別力的實驗是**還原變數後的乾淨複測**，
而不是「換一個值試試看會不會過」。變更前後都必須在同等乾淨的狀態下比較。

## Key Decisions

- **iOS 15 / macOS 12 全面採用，套件與 example 皆升**（來源：Q1，使用者 2026-08-15 核准）。
  代價已揭露並接受：放棄 iOS 12–14 / macOS 10.15–11 的使用端，且擴大與上游的 delta。
- **本計畫分兩段執行，共用同一分支與同一份計畫**（來源：使用者 2026-08-15 指示
  「當前環境修改的部分測試並 commit 後，我會再讓 macOS 來接續升級計畫」）。理由：iOS/macOS
  的實際建置驗證在 Windows 上不可能取得，硬做只會產出未驗證卻宣稱完成的變更。
- **套件層宣告在 Stage 1 就改，example 的 Xcode 專案留給 Stage 2**（來源：Q1 的分段落點）。
  理由：`.podspec` / `Package.swift` 是 migrator 永遠不碰的手動區；`Podfile` / `project.pbxproj`
  則會被 migrator 自動改寫，在 macOS 上產生的 diff 才可信。
- **KGP 升至 2.4.0**（來源：Q2）。理由：現值 2.2.20 正好等於 Flutter 的 error 門檻，
  已在 warn 區，下一次調升即建置失敗。
- **`pubspec.yaml` 的 `environment:` 下限不動**（來源：Q3）。理由：下限抬高只切斷舊使用端，
  對 3.47 的相容性毫無幫助，且擴大 delta。
- **UIScene 列入 Stage 2 而非另開計畫**（來源：Q4，使用者指定選項 C）。理由：不在 Windows 盲改，
  也不讓它掉出本計畫的追蹤範圍。
- **套件 `minSdk` 19 → 24**（來源：Q5）。理由：19 是不實宣稱——Flutter 早已不支援，本套件也從未驗證過。
- **Impeller 只驗 Windows，Linux 標記為已知未驗證**（來源：Q6）。理由：本機無 Linux 環境；
  發現問題另開計畫修，不在本計畫夾帶行為變更。
- **Material/Cupertino 獨立套件遷移不做**（來源：Q7）。理由：11 月才正式棄用，現在遷移會與上游全面衝突。
- **`README.md` 在 Stage 1 更新，`project.md` 與 wiki 留給 Phase 5**（來源：Q8，Rule 18）。

### Stage 2 追加（2026-08-15，macOS 環境）

- **補上兩個 federated 子 example 的 `dependency_overrides`**（來源：Q17，使用者核准）。
  既有缺陷、非本次升級造成，但阻斷了已核准的驗證項目。與 Android 子 example 的既有修法一致，
  獨立 commit 以便單獨 revert。

- **UIScene 照原訂採用**（來源：Q12）。但**採用的理由已更正**：
  SDK 原始碼內**查無任何 "Xcode 27" 字樣**（required=15 / recommended=16），
  Stage 1 引用的「Xcode 27 建置即啟動失敗」無法佐證，屬 blog 轉述。
  改以 SDK 可佐證的理由陳述：**UIScene 是未來 iOS 版本的要求，且 Flutter 3.47 已內建
  stable 預設啟用的自動遷移器**——方向明確，理由較原本更強。
  結論措辭不得再宣稱「為了 Xcode 27」。
- **~~SceneDelegate 照範本獨立成檔~~ → 改為跟隨官方遷移器，用 engine 內建的 `FlutterSceneDelegate`，
  不新增檔案、不碰 pbxproj**（來源：Q13 更正 + Q16）。
  原決議（獨立成檔 + pbxproj 四處手動編輯）**作廢**——它建立在「必須自己有一個 SceneDelegate 類別」
  這個錯誤前提上。本計畫原本唯一的高風險編輯因此消失，相應的還原防線也不再需要。
- **`@UIApplicationMain` → `@main`**（來源：Q14）。理由：同檔同次編輯、邊際成本為零，且已棄用。
- **插件註冊跟進 `FlutterImplicitEngineDelegate`**（來源：Q15，使用者指定選項 B）。
  查證後確認：**這正是官方遷移器自己會寫出的結果**（`uiscene_migration.dart:170-186`），
  因此不是「額外多改一個變數」，而是採用 UIScene 的官方路徑本身就包含它。
  原先揭露的「同時改兩個變數」顧慮**因此解除**。

## 附帶回報（非本計畫範圍，僅揭露）

1. **`2608121003-agp-9-upgrade` 計畫狀態為 `Awaiting Archive`**，與本次工具鏈主題相鄰但屬另一份合約。
   依 Rule 13 不自動歸檔——需要的話請另行指示。
2. **三個已完全併入 `main` 的本地分支殘留**（Rule 21，此處只報不刪）：
   `feature/2608111609-webview-keyboard-avoidance`、`feature/2608121003-agp-9-upgrade`、
   `feature/2608121440-back-gesture-fling`。
3. **既有計畫記載「本 repo GitHub Issues 已停用」與現況不符**：
   `gh repo view --json hasIssuesEnabled` 於 2026-08-15 回報 `true`。因此本計畫依 Rule 20
   走「需建立 issue」路線，與前幾份計畫的 `N/A` 不同。

## Stage 1 結案與交棒（2026-08-15）

Stage 1 已 commit：`13b0d233` — `chore: 對齊 Flutter 3.47.0 平台基準`（14 檔）。

### 已驗證 / 未驗證（不得混為一談）

| 項目 | 狀態 |
| :--- | :--- |
| Android `flutter_inappwebview/example` 建置 | ✅ exit 0（703s） |
| Android `flutter_inappwebview_android/example` 建置 | ✅ exit 0（101s） |
| `flutter analyze` | ✅ 非 `env.dart` 來源的 error = 0 |
| Web 建置 | ✅ 通過（146s）+ Wasm dry run succeeded |
| Windows 建置 | ✅ `example.exe`（519s） |
| **Windows 實跑目視（Impeller）** | ⏳ **未完成**——交由使用者自行執行 |
| **iOS / macOS** | ❌ **完全未驗證**，本機無 Xcode |
| **Linux** | ❌ **完全未驗證**，本機無環境 |

`env.dart` 那 25 個 analyze error 是 `.gitignore` 掉的開發者本機檔案缺失所致，
**與 3.47 無關，且變更前後皆存在**。

### macOS 接手方式

1. `git fetch && git switch feature/2608151157-flutter-3-47-upgrade`
2. 依 `tasks.md` 的 **Phase F** 逐項執行（example 的 Xcode 專案、Podfile、UIScene、實測）
3. Phase F 的 commit 仍逐項請示（Rule 17）
4. 全部完成後才進 Phase G（rebase + force-push + PR + 歸檔 + wikification）

### 交棒時必須知道的三件事

- **套件層的部署目標已改完**（`.podspec` / `Package.swift`），Stage 2 只需處理 **example 的 Xcode 專案**。
  在 macOS 上跑 `flutter build ios` / `flutter build macos` 時，Flutter 的 migrator 會自動改寫
  `Podfile` 與 `project.pbxproj`，複核 diff 即可，不必手改。
- **Built-in Kotlin 警告已知且刻意不處理**（Q10）。看到它不必驚慌，也不要順手修。
- **Windows 的 nuget 問題已釐清**（Q11），不是環境缺件，macOS 上不會遇到。

## Stage 2 開工基準（macOS 環境，2026-08-15）

### 環境實測值

| 項目 | 值 |
| :--- | :--- |
| Flutter | 3.47.0 stable（Dart 3.13.0） |
| Xcode | **26.6（Build 17F113）** — **不是 27**，見 Q12 |
| Xcode SDK | iOS 26.5 / macOS 26.5 |
| macOS | 26.5.2（25F84） |
| CocoaPods | 1.17.0 |
| 可用模擬器 | iPhone 17 Pro、iPhone 17（iOS 26.5）|
| SDK 路徑 | `flutter` 指向本機 `~/flutter` |

分支 `feature/2608151157-flutter-3-47-upgrade` 已拉取，工作區乾淨，
`13b0d233`（Stage 1）與 `8b069cc0`（交棒文件）皆在。

### Code Evidence Scan 複核（2026-08-15，於本分支）

Stage 1 在 Windows 上記錄的錨點**全部複核通過**，無漂移：

| 檔案 | 行 | 現值 |
| :--- | :--- | :--- |
| `flutter_inappwebview/example/ios/Podfile` | 2 | `platform :ios, '13.0'` |
| `flutter_inappwebview_ios/example/ios/Podfile` | 2 | `# platform :ios, '13.0'`（註解） |
| `flutter_inappwebview/example/ios/Runner.xcodeproj/project.pbxproj` | 579, 632 | `13.0`（473/511 已是 16.0） |
| `flutter_inappwebview_ios/example/ios/Runner.xcodeproj/project.pbxproj` | 477, 608, 657 | `13.0` |
| `flutter_inappwebview/example/macos/Podfile` | 1 | `platform :osx, '10.15'` |
| `flutter_inappwebview_macos/example/macos/Podfile` | 1 | `platform :osx, '10.15'` |
| `flutter_inappwebview/example/macos/Runner.xcodeproj/project.pbxproj` | 399, 478, 525 | `10.15` |
| `flutter_inappwebview_macos/example/macos/Runner.xcodeproj/project.pbxproj` | 559, 651, 698 | `10.15` |
| 兩個 iOS example 的 `Info.plist` | — | **無** `UIApplicationSceneManifest`（Q4 前提成立） |

本機 SDK 的 migrator 取代值也已直接讀出確認，與 Stage 1 記載一致：
`ios_deployment_target_migration.dart:118` → `15.0`（`:92` 涵蓋原值 `13.0`）、
`macos_deployment_target_migration.dart:66` → `12.0`（`:41` 涵蓋原值 `10.15`）。
**即 `flutter build` 一跑，這兩組值會被自動改寫，不需手改。**

### Stage 2 的驗證範圍與已知上限

- ✅ 可實測：iOS 模擬器建置與執行、macOS 建置與執行（含 Impeller 預設下的 WKWebView）、
  `pod install` / podspec 一致性。
- ❌ 無法實測：**實體 iOS 裝置**（本機未接）、**Xcode 27 對 UIScene 的強制性**（本機為 26.6，Q12）。
- 沿用 Stage 1 的未驗證區域：Linux、Windows 實跑目視。

### 執行順序（先低風險，後高風險）

1. 部署目標（讓 migrator 自動改寫，人只複核 diff）→ 建置驗證
2. UIScene 採用（唯一的行為變更）→ 再次建置與執行驗證

兩者分開驗證，才能在出問題時分辨是部署目標還是 UIScene 造成的。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- Flutter 3.47 發布說明：`https://flutter.dev/blog/whats-new-in-flutter-3-47`
- 本機 SDK 版本判定：`packages/flutter_tools/lib/src/android/gradle_utils.dart`
- 本機 SDK 建置期檢查：`packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`
- 本機 SDK 部署目標 migrator：`packages/flutter_tools/lib/src/ios/migrations/ios_deployment_target_migration.dart`、
  `packages/flutter_tools/lib/src/macos/migrations/macos_deployment_target_migration.dart`
- 相鄰計畫：`.kn-project/plans/2608121003-agp-9-upgrade/`（AGP 9.3.0 / Gradle 9.5.0 的來源）
- 相鄰歸檔：`.kn-project/archive/2608140054-macos-spm-deployment-target.md`（macOS 部署目標的前一次調整）
