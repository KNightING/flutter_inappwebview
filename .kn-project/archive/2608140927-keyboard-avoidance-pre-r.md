# 2608140927 - keyboard-avoidance-pre-r

- Created: 2026-08-14 09:27 / Archived: 2026-08-14 14:05
- Issue: KNightING/flutter_inappwebview#8

## Summary

`keyboardAvoidance` 自本次起在 **Android 全部支援版本**皆生效，API 30 以下不再被忽略。原本 `setKeyboardAvoidanceEnabled` 在 `SDK_INT < R` 直接 return，該區間沒有任何避讓者：使用端照文件關掉 `Scaffold.resizeToAvoidBottomInset` 後，焦點欄位會被鍵盤蓋住（於 Urovo U2 / API 29 以模板 App 複現，頁面零位移）。缺的只有「平移」這一半——pre-R 的 Chromium 收不到鍵盤、不執行自己的 `ScrollFocusedEditableIntoView`，沒有第二個角色需要壓制。鍵盤高度改由 framework 轉交：原生端在該區間沒有可用通道，而 engine 有。影響 `InputAwareWebView`、`WebViewChannelDelegate` 與 android 套件的 Dart 層；API 30+ 路徑一行未改。

## Cross-Repo Scope

- **本 repo**（`KNightING/flutter_inappwebview`）：本次的全部實作與文件。
- **`sld-upcc-middle`**（消費方，不在本計畫內）：待本 repo 發出新 tag 後另開計畫——重釘依賴、`resizeToAvoidBottomInset` 一律 `false`、移除 `_detectKeyboardResizeFallback`，並重新評估為 viewport 變形而生的 `data-orientation` / `screen-landscape:` 機制（其計畫 `2608140010-template-sync-1-1-2`）。
- **執行順序相依**：本 repo 先發 tag，使用端才能重釘。
- **`nuxt-flutter-app`**：僅作為驗證宿主借用，未留下任何變更。

## Key Decisions

- **[Q1]** 接受 fork delta 因 pre-R 分支而成長 — 把使用端重造的原生行為收進套件正是本 fork 的目的，且目標機（Urovo U2 / API 29）就落在該區間。本次增加約 130 行程式碼。
- **[Q2]** 實驗若無法壓制 Chromium 即停下回報、不合併 — 半套的壓制比不開更糟。**實測後此顧慮解除**：pre-R 的 Chromium 根本不動作，無須壓制。
- **[Q3]** 接受 pre-R 只有 settled 值的降級 — **實際未發生**：`didChangeMetrics` 在鍵盤動畫期間逐幀觸發，位移跟著動畫走。
- **[執行中]** 鍵盤高度來源改為 Dart 層轉交 `FlutterView.viewInsets.bottom` — 原生端在 pre-R 沒有可用通道：type-based insets 沒有 `ime` 值；實測 system window 與 stable 底邊全程為 0（Flutter embedding 在上層消耗）；visible display frame 要靠 layout pass，而 `resize:false` 之下不重排。engine 握有此值（framework 自身的 resize 能在 API 29 正確運作即為證據）。
- **[執行中]** `setFrameworkKeyboardInsetPx` 在 API 30+ 直接忽略 — 該區間自有更即時的來源，避免兩個寫入者。
- **[執行中]** Dart 端以 `initialSettings?.toMap()['keyboardAvoidance']` 取值而非型別 getter — 本套件相依 pub.dev 上的 platform interface（`pubspec.yaml:23`），fork 自加的設定在型別上不存在，typed access 無法通過 standalone `flutter analyze`。

## Deviations

- **計畫假設的量測通道全數作廢**。原計畫預期以 `systemWindowInsets.bottom − stableInsets.bottom` 取得鍵盤高度（理由是 Flutter 也這樣算）。實測該通道在本情境完全不可用（值恆為 0 且鍵盤彈出時不再觸發）；改採的 visible display frame 通道則只在 `resize:true`（有 layout pass）時才響，同樣不可用於目標組態。最終改由 Dart 層轉交。
- **Phase C 的壓制實驗未執行到底**。原訂三條候選（不壓制／整段消耗底部插邊／停下回報），在確認 Chromium 於 pre-R 不動作後即無必要，C2 標記為不適用。
- **一度得出「fork 無需修改」的錯誤結論**。在 `h-dvh` 的使用端頁面上，鍵盤縮短動態 viewport 會讓版面自行重排、焦點欄位因此可見，被誤判為 Chromium 完成了避讓。改以模板 `nuxt-flutter-app`（`min-h-dvh` 長頁面、不重排）在同一台裝置複現後推翻——該版面副作用不是避讓機制，長表單等不重排的頁面仍會被蓋住。
- **D3（API 30+ 迴歸）以 API 36 模擬器完成**，非實體裝置。驗的是行為正確性（平移生效、欄位可見），非效能數據。

## Impact Files

- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InputAwareWebView.java`（`setKeyboardAvoidanceEnabled` 的 pre-R 分支改為建立 controller + 掛 JS interface；新增 `setFrameworkKeyboardInsetPx`）
- `.../webview/WebViewChannelDelegate.java`、`.../webview/WebViewChannelDelegateMethods.java`（新增 `setFrameworkKeyboardInset`）
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview_controller.dart`（`startFrameworkKeyboardInsetReporting` / `_FrameworkKeyboardInsetObserver`）
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`（`_onPlatformViewCreated` 依 `keyboardAvoidance` 啟動回報）
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart` 與其 `.g.dart`（版本要求、`resize:false` 的 CAUTION 收斂為 iOS 專屬、`visualViewport` 失效理由補上兩條路徑）
- `KeyboardAvoidanceController.java` — **未改動**，位移演算法以視窗座標計算，無 API 級別相依。

## Details

實機驗證（U2 / API 29，宿主為模板 App 的 `min-h-dvh` 長頁面）：直向上移 57px、橫向 104px，焦點欄位皆可見於鍵盤正上方；失焦後精準還原；連續切換焦點不累加位移（`computeShiftPx` 的冪等設計在新通道下仍成立）。API 36 模擬器迴歸：R+ 行為與改動前一致。

實作時務必沿用的兩條教訓：

- `getInsetsIgnoringVisibility(Type.systemBars())` 在 pre-R 會打到平台隱藏方法 `android.view.WindowInsets$Type.systemBars()`（API 30 才公開），被 blacklist 擋下。pre-R 一律用 `getSystemWindowInsets()` / `getStableInsets()`。
- `getViewTreeObserver()` 在 View 尚未 attach 時回傳暫時性 VTO，attach 後會被換掉——監聽器只在啟動時響幾次就再也不觸發。
