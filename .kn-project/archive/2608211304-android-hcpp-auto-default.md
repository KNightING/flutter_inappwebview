# 2608211304 - android-hcpp-auto-default

- Created: 2026-08-21 13:04 / Archived: 2026-08-21 13:40
- Issue: KNightING/flutter_inappwebview#22

## Summary

Android 的平台視圖合成模式改為**預設自動選擇**：能用 HCPP 就用 HCPP，否則 TLHC，使用端不需要設定任何套件欄位。

核心是 `_resolveCompositionMode()` 的 else 分支由 `TLHC` 換成 auto，其餘不動。明確指定的寫法全部維持原行為（pin TLHC / HC / HCPP，以及 deprecated 的 `useHybridComposition: true`）。auto 路徑會等支援度探測完成才建立 WebView，因為合成模式在 platform view 建立當下就定死，提早決定會讓「有沒有吃到 HCPP」變成取決於 App 啟動時序。

**未 opt-in 的 app 行為完全不變**——實測確認。由於絕大多數使用端不會 opt-in，這次預設變更對他們是零影響。

影響模組：`_android`（解析與延後建立）、`platform_interface`（欄位與列舉文件）。Java 端零改動。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** 不新增 `AUTO` 列舉成員，以 `null`／不設代表 auto——改動最小；新增一個「不是真正合成模式」的列舉值會讓語義變混。
- **[Q2]** auto 且支援度未知時**延後建立 WebView**——只有這樣才能保證每次都真的用到 HCPP。採「接受不一致」會讓結果取決於啟動時序，而預設值最不該具備的性質就是不可預測。實作以記憶化 future 避免 rebuild 重啟探測而拆掉已建立的 WebView，`initialData` 在答案已知時短路，且 `FutureBuilder` 在 auto 模式下恆留在樹中以維持樹形不變。
- **[Q3]** 不另提供全域逃生門——明確指定 `TEXTURE_LAYER_HYBRID_COMPOSITION` 已是逐 WebView 的細粒度控制。
- **[Q4]** 完整重跑一輪實機驗證——預設值變更的風險等級等同上一次 HC → TLHC 的翻預設。
- **[地雷]** **不得**讓 `useHybridComposition` 變 nullable 來區分「沒設」與「設了 false」：它在 Java 是 `Boolean` 且 `fromMap` 直接轉型，送 `null` 會讓 native 的 21 處判斷發生 **unboxing NPE**。因此該欄位的型別與預設值一律不動。
- **[Phase 2 實測]** 六種設定組合的解析結果全部符合規格，含 `useHybridComposition: true` 仍走 HC 的相容性防線。
- **[Phase 2 實測，風險低於預期]** 未 opt-in 的 app（無 `EnableHcpp`）`support=false`，AUTO 解析為 TLHC，行為與變更前完全相同。
- **[Phase 2 修正假設]** manifest 的 `EnableHcpp` **對 debug build 一樣生效**，不限 release——不帶 intent extra 從 launcher 啟動 debug APK 仍得到 `support=true`。
- **[方法論]** 引擎的 `Using HCPP platform view rendering strategy` log **每個 process 只印一次**，無法歸屬到個別 WebView；曾據此誤判 AUTO 沒走到 HCPP，改以套件內暫時儀器直接印解析結果才取得可靠證據。
- **[方法論]** `flutter analyze lib/`（於 example）**涵蓋不到套件原始碼**——重構後遺漏的 `context` 參數是 `flutter build` 編譯時才被抓到。套件端的正確性檢查須以編譯為準。

## Deviations

- **未驗證**：延後建立造成的第一幀 placeholder 未做視覺確認（僅確認 WebView 未被建立兩次）；`InAppBrowser` 與 headless 不經 platform view，未實跑；其他平台未回歸。
- **裝置數量**：正面驗證僅一台 Android 16 實機，非裝置矩陣。

## Impact Files

- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`
  — `_resolveCompositionMode()` 的 else 分支改為 auto 並改吃傳入的支援度；新增
  `_isAutoCompositionMode()`、`_buildPlatformView()`（自 `build()` 抽出，需傳入 `context`）、
  以及記憶化的 `_autoCompositionModeSupport()`；`build()` 在 auto 路徑包 `FutureBuilder`。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart`
  — `androidCompositionMode` 欄位文件：不設即為自動選擇、如何 pin TLHC、auto 會延後第一個
  WebView 的建立。
- `.../in_app_webview_settings.g.dart` — 產生檔。
- `flutter_inappwebview_platform_interface/lib/src/types/android_composition_mode.dart`
  — 類別層文件說明預設為自動選擇。
- `.../android_composition_mode.g.dart` — 產生檔。
- **不改動**：`useHybridComposition` 的型別與預設值；Java 端全部檔案。

## Details

**解析對照表**（實機逐項驗證）：

| 使用端寫法 | 解析結果 |
| :--- | :--- |
| 不設任何欄位（已 opt-in、API 34+、Vulkan） | `HYBRID_COMPOSITION_PLUS_PLUS` |
| 不設任何欄位（未 opt-in） | `TEXTURE_LAYER_HYBRID_COMPOSITION` |
| 不設任何欄位（API 29） | `TEXTURE_LAYER_HYBRID_COMPOSITION` |
| `useHybridComposition: true`（deprecated） | `HYBRID_COMPOSITION` |
| `androidCompositionMode: TEXTURE_LAYER_HYBRID_COMPOSITION` | 同左 |
| `androidCompositionMode: HYBRID_COMPOSITION_PLUS_PLUS` | 同左（不支援時退回 TLHC） |

**AUTO 走到 HCPP 時的功能驗證**（Android 16 平板）：渲染、捲動、`keyboardAvoidance`
（注音輸入法 composing、候選字列、焦點框保持可見）、長按選單、影片播放
（`currentTime` 7.51 → 8.53，`advanced=true`）皆正常。U2（API 29）退回 TLHC 後同樣正常、無崩潰。
