# 2608200109 - android-hcpp-mode

- Created: 2026-08-20 01:09 / Archived: 2026-08-21 12:35
- Issue: KNightING/flutter_inappwebview#20

## Summary

Android 平台視圖新增 **Hybrid Composition++（HCPP）** 作為第三種可選合成模式，預設不啟用。

HCPP 讓 platform view 與 Flutter 各自繪到原生 Surface、交由 SurfaceFlinger 合成，同時取得 HC 的原生保真度與 TLHC 的效能（不需合併 raster 與 platform 執行緒）。對外新增 `AndroidCompositionMode` 列舉承載三種模式，`useHybridComposition` 保留並標記 deprecated，既有使用端零破壞。

**Java 端完全未改動**：逐點檢視該布林在 native 的 21 處分支後確認，它問的其實是「WebView 是否在真實 view 階層中」，HCPP 與 HC 同側，因此 Dart 在 HCPP 模式下送 `useHybridComposition: true` 即可。

影響模組：`platform_interface`（新型別 + 設定欄位）、`_android`（模式選擇與支援度探測）、`example`（manifest opt-in）。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** 新增 `androidCompositionMode` 列舉，`useHybridComposition` 標 deprecated 但保留——對外零破壞；代價是需定義兩欄位的優先順序（新欄位非 null 時勝出）。
- **[Q2]** 探測 HCPP 支援度並快取，不可用時自動退回 TLHC——使用端只宣告意圖，不會出現白畫面等級的失敗。
- **[Q3]** Java 端布林維持不變，HCPP 送 `true`——該布林語義本就是二元的（是否在真實 view 階層）。判定表見下方 Details。
- **[Q4]** 以模擬器驗證，後於實體 Android 16 平板取得更強佐證。
- **[Q5]** `InAppBrowser` 與 `HeadlessInAppWebView` 不經 platform view，僅以文件說明不適用。
- **[執行中]** 重跑 build_runner 產生 `.g.dart`——實測確認只動相關檔案，未對其他產生檔造成 churn，前一計畫擔心的風險在此情境不成立。
- **[執行中]** 設定欄位型別必須寫帶底線的來源類別 `AndroidCompositionMode_`；寫成產生後的名字會讓產生器輸出 `InvalidType` 而**不報錯**。
- **[執行中]** `@Deprecated` 會讓產生器把欄位從 `toMap()` 移除，deprecated 設定將靜默停止送達 native；必須同時加 `@ExchangeableObjectProperty(leaveDeprecatedInToMapMethod: true)`，與既有的 `forceDark` 相同。
- **[執行中]** 新欄位必須同時加到來源建構子的參數列，否則 `InAppWebViewSettings(...)` 用不到它（`undefined_named_parameter`），同樣不會在產生時報錯。
- **[執行中]** 新型別必須加入 `types/main.dart` 的 `export` 才對外可見。
- **[Phase 4 修正]** 探測不可在 `registerWith()` 一次定生死——該時點早於引擎附著，會得到 `false`（實測模擬器與實機皆然）。改為**只快取正面結果**，負面結果允許重問，並於 widget `build()` 重探讓後續 WebView 自癒。要保證第一個 WebView 就拿到 HCPP，使用端可先 `await precacheHybridCompositionPlusPlusSupport()`。
- **[Phase 4 修正]** **不可為 HCPP 而在 app 層強制 `ImpellerBackend=vulkan`**。該設定讓模擬器得以走 Vulkan，卻在 Android 10 的 U2 上造成啟動即崩潰（`Check failed: android_context_->IsValid()`）。實機不需要它。
- **[Phase 4 先錯後正]** 曾兩度斷定官方 opt-in 文件過時，**兩次都錯**。`--enable-hcpp` 是隱藏旗標（`hide: !verboseHelp`）；`EnableHcpp` manifest 鍵由工具端讀取（`project.dart:1102`），不在 embedding jar 內——用 grep embedding jar 否證它是**無效方法**，同一套方法也會「證明」公認有效的 `EnableImpeller` 不存在。補做的決定性測試（帶該鍵的 release APK、launcher 一般啟動）確認兩條官方路徑皆成立。
- **[Phase 4 修正判讀]** 曾觀察到「HCPP 下畫面空白」，實為捲動捲過頁面內容所致，非渲染失敗。

## Deviations

- **`## Impact Files` 執行中共補列 6 項**：`types/main.dart`、新列舉兩檔、settings 建構子參數列、`inappwebview_platform.dart`、example manifest。皆為已核准決策的直接衍生，非範圍外變更。
- **Phase 5 覆核一度誤報 Windows 三檔**：實為本地 `main` 落後於 `origin/main`（分支由 `gh issue develop` 從遠端 main 切出，已含 PR #19），非誤提交。
- **未驗證**：`InAppBrowser` 與 headless 路徑僅以文件說明不適用，未實跑；其他平台未回歸測試。
- **驗證裝置僅兩台**（Android 16 平板為主、API 36 模擬器為輔），非裝置矩陣。

## Impact Files

- `flutter_inappwebview_platform_interface/lib/src/types/android_composition_mode.dart` — 新列舉來源宣告（`AndroidCompositionMode_`），含 opt-in 條件的文件。
- `.../types/android_composition_mode.g.dart` — build_runner 產生。
- `.../types/main.dart:9` — 新型別的 `export`。
- `.../in_app_webview/in_app_webview_settings.dart:1177` — `useHybridComposition` 標 deprecated 並補 `leaveDeprecatedInToMapMethod`；其後新增 `AndroidCompositionMode_? androidCompositionMode`。建構子參數列於 `:3482` 附近同步。
- `.../in_app_webview/in_app_webview_settings.g.dart` — 產生檔。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart` — `precacheHybridCompositionPlusPlusSupport()` 與 `isHybridCompositionPlusPlusSupported`、`_resolveCompositionMode()`、`_createAndroidViewController()` 的 `initHybridAndroidView` 分支、`settingsMap['useHybridComposition']` 覆寫。
- `flutter_inappwebview_android/lib/src/inappwebview_platform.dart:23` — `registerWith()` 啟動支援度探測。
- `flutter_inappwebview/example/android/app/src/main/AndroidManifest.xml` — `EnableHcpp` opt-in。
- **Java 端未改動**：`InAppWebView.java`、`FlutterWebView.java`、`InputAwareWebView.java`、`InAppWebViewSettings.java` 皆維持原狀（Q3A）。

## Details

**Java 端 21 處分支的判定表**（Q3A 的依據，全部與 HC 同側）：

| 類別 | 位置 | HCPP 走向 |
| :--- | :--- | :--- |
| containerView 代理 | `FlutterWebView.java:67` / `:173` / `:179` / `:185` / `:192`、`InAppWebView.java:1712` / `:1766` / `:2236` | HC 側（不代理，containerView 為 null） |
| IME 代理 workaround | `InputAwareWebView.java:209` / `:230` / `:271` / `:349` | HC 側（略過，交給 `super`） |
| 自訂浮動選單 | `InAppWebView.java:539` / `:651` / `:1746` / `:1755` | HC 側（用原生 action mode） |
| layer type | `InAppWebView.java:445` / `:1124` | HC 側（套用）；本表推理最間接的一項，已於 Phase 4 實測確認 |
| 直通、非分支 | `InAppWebView.java:217`、`InAppWebViewSettings.java:135` / `:425` / `:585` | — |

結構性佐證：多數 `!useHybridComposition` 分支另有 `containerView != null` 守衛，而 containerView 只在非 hybrid 時才非 null（`FlutterWebView.java:67`），兩道守衛由建構方式保證一致。

**Phase 4 實機驗證結果**（實體 Android 16 平板 model 25097RP43G）：渲染、捲動、`keyboardAvoidance`（注音輸入法 composing 與候選字列正常）、長按選單與文字選取（原生 action mode）、影片播放皆正常；HC / TLHC 回歸正常。影片以 `video.currentTime` 是否前進為判準（三種模式皆在一秒內前進約 1.03 秒且 `paused=false`），而非目視單一幀。U2（API 29）確認 `support=false` → 降級 TLHC → 正常渲染、無白畫面。

**XML 註解陷阱**：manifest 註解內不得出現連續兩個減號，寫 `flutter run --enable-hcpp` 會讓 manifest merger 解析失敗。
