# 2608191735 - webview-render-perf

- Created: 2026-08-19 17:35 / Archived: 2026-08-20 00:59
- Issue: KNightING/flutter_inappwebview#16

## Summary

消除四條「每幀都在付、多數情境卻不需要付」的渲染成本，並把 Android 的平台視圖合成模式由 Hybrid Composition 改為預設 TLHC。

Android 端讓未註冊 callback 的高頻捲動事件不再跨 method channel；iOS 端把每個捲動幀都在跑的 gesture recognizer 字串掃描收斂到導覽時才執行；Windows 端在 texture 無新影格時略過整張 GPU 複製，並在座標未變時不重設 WebView2 bounds。第五項是刻意的對外行為變更：`useHybridComposition` 預設由 `true` 翻為 `false`，會啟用 `InputAwareWebView` 中一條至今對預設使用者休眠的 IME 代理路徑，因此以實機人工驗證作為驗收。

過程中另修復了 example app 的 WebView Tester 畫面兩個既有缺陷（鍵盤彈出會重建 WebView、底部測試面板無法收合），它們與效能改動無關，但不修就沒有可用的驗證載體。

影響模組：`_android`（dart + java）、`_ios`（swift）、`_windows`（dart + c++）、`platform_interface`、`example`。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** #1 的 gating 採「creationParams + 內部 method channel 重新同步」——`_controller` 只在 platform view 建立時抓一次 params，`keepAlive` 會讓同一個 native webview 被新 widget 重新掛載，純快照會過期並造成事件靜默消失。
- **[Q2]** #1 本輪只做 Android，iOS 不同步套用——iOS 的捲動成本主要由 #2 解決；同時動兩個平台會讓驗證面積翻倍。
- **[Q3]** #5 的三處預設值（`platform_interface` 建構子、`_android` widget 的 `?? true`、Java 欄位）全部翻為 `false`——只翻其中一處會讓「不傳設定」與「傳了部分設定」走到不同分支，是比行為變更本身更難查的不一致。
- **[Q4]** 不拆分計畫，五項共用一個分支與一個 PR——五項同屬一次效能盤點，合併驗收較有意義；#1 與 #5 共用同一個 Dart 檔，本就不可拆。
- **[Q5]** #5 的驗收採實機人工驗證——IME 代理路徑與鍵盤避讓需要真手指與真輸入法，`adb input` 這類合成注入測不出來（與 `2608121440-back-gesture-fling` 是同一個方法學限制）。
- **[使用者拍板]** #5 採 TLHC，接受與上游產生行為分歧的代價；本計畫的職責是把分歧範圍與風險壓到最小（三個字面值 + 完整實機驗證清單）。
- **[執行中，實測推翻原設計]** #4 的去重**只套用在 `onPointerDown`**，其餘上報路徑照送——原設計對所有路徑去重，實跑後 WebView 整片空白。根因是 `custom_platform_view.cc` 的 `setSize` handler 同時負責 `texture_bridge_->Start()` 與 `put_Bounds`，而 `InAppWebView::setSurfaceSize` 在 `webViewController` 尚未建立時會直接 return——**那些看似多餘的重複上報其實是重試機制**。已用 A/B 實測確認。原計畫的 `force` 參數設計作廢，改以 `_reportGeometryIfMoved()` 承載。
- **[實測澄清]** 視窗縮放時網頁內容被拉伸是**上游既有行為**，在未套用任何改動的基準版上以相同操作重現，不在本計畫範圍內處理。
- **[執行中]** `in_app_webview_settings.g.dart` 以手改方式同步預設值，未重跑產生器——避免整份檔案因產生器版本差異出現大量無關變更。
- **[執行中]** #1 的 native gate 以 `enabledHighFrequencyEvents == null` 為 fail-open 判準——InAppBrowser 的 controller 於建構期才綁定 handler，以「參數為 null 就全開」比依賴綁定順序穩固。
- **[範圍]** WebView 生命週期暫停 / `pauseTimers` 不納入本計畫——該行為屬於 App 政策而非套件預設，正確形態是新增可選設定而非改預設。
- **[迭代]** example app 修復併入本計畫而非另開計畫（使用者拍板）——它存在的唯一目的是讓 #5 的實機驗證有可用載體。代價是 delta 多出 `example/` 一個檔案，該檔不屬套件程式碼，#1~#4 的「零對外行為變更」驗收不受影響。
- **[迭代]** example 鍵盤問題的主修法是 `Scaffold.resizeToAvoidBottomInset: false`，並額外掛 `GlobalKey`——前者同時修正 example app 未遵守 `keyboard-avoidance` 使用端契約的問題；後者讓 element 在版面分支切換時被重新掛載而非銷毀，從結構上消除「分支切換就重載頁面」這一類問題。

## Deviations

- **Phase 5 的 pull-to-refresh 未驗證**。使用者選擇在該項未完成的情況下繼續歸檔並開 PR。其餘六項（中文輸入法 composing／`keyboardAvoidance`／鍵盤收起後版面還原／影片播放／長按選單／捲動流暢度）皆已在 U2（Android 10, API 29）以 release build 通過。
- **iOS 捲動流暢度為絕對評估，非 A/B 比對**。原訂「同一頁面改動前後比對」，實際只在 iPad（iOS 26.6, release）確認改動後表現順暢，未建置 `main` 版本對照。
- **`## Impact Files` 原先漏列兩個檔案**，Phase 6 覆核時補上：`WebViewChannelDelegateMethods.java`（Q1 的 method channel 決議必然帶出的 enum 成員）與 `in_app_webview_settings.g.dart`（#5 翻預設值後同步）。兩者皆為已核准決策的直接衍生，非範圍外變更。
- **`InAppWebView.java` 與 `InputAwareWebView.java` 列入 Impact Files 但未修改**：前者是 #1 的成本來源，gate 依計畫實作在 `WebViewChannelDelegate`；後者計畫即明載不修改。
- **一次未重現的 Chromium 原生 crash**：example app 首次實跑時觀察到 SIGSEGV（`ThreadPoolForeg`），發生在 flutter.dev 載入並建立 `OMX.MTK.VIDEO.DECODER.AVC` 之後。以「啟動後靜置」與「單獨觸發收合」兩個對照皆未重現，成因未確認，記錄備查。
- **編號衝突**：`pauseTimers` 那項範圍排除在計畫早期被稱為 #6，迭代追加的 example 修復也被編為 #6。兩者無關，本檔已改以文字描述區分。

## Impact Files

### Android 高頻事件 gating（#1）

- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/WebViewChannelDelegate.java:763` / `:784` / `:1145` — 三個 `channel.invokeMethod` 的 gate 掛載處。
- `.../webview/WebViewChannelDelegateMethods.java` — 新增 `setEnabledHighFrequencyEvents` enum 成員。
- `.../webview/in_app_webview/FlutterWebView.java` — 讀入 creationParams 新欄位；欄位缺席時 fail-open。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart:352` — creationParams 組裝處。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview_controller.dart:375` — 既有 Dart 端 gate，改由共用 helper 供應以避免漂移。
- `.../webview/in_app_webview/InAppWebView.java:1443` / `:1699` — 成本來源（`onScrollChanged` / `onOverScrolled`），**未修改**。

### iOS gesture 掃描（#2）

- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Sources/flutter_inappwebview_ios/InAppWebView/InAppWebView.swift:935` — `observeValue` 末端的無條件呼叫移入 `estimatedProgress` 與 `url` 兩個導覽分支。
- `.../InAppWebView.swift:255` — `replaceGestureHandlerIfNeeded()` 定義，成本來源，未修改。
- `.../InAppWebView.swift:486` — `contentOffset` KVO 註冊處，說明為何每幀都會打到 `:935`。

### Windows texture dirty flag（#3）

- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge.h:50` — dirty 旗標宣告。
- `.../texture_bridge.cc:107` — `OnFrameArrived()` 設旗標。
- `.../texture_bridge_gpu.cc:89` — `GetSurfaceDescriptor()` 條件化 `ProcessFrame`。
- `.../texture_bridge_fallback.cc:120` — `CopyPixelBuffer()` 同一條件。

### Windows size / position 去重（#4）

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart:397` — `onPointerDown` 的重複上報，去重僅套用於此。

### Android TLHC 預設（#5）

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart` — 建構子預設值。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.g.dart` — 同步產生檔。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart:325` — widget 的 `?? true` 改 `?? false`。
- `.../webview/in_app_webview/InAppWebViewSettings.java` — Java 欄位預設。
- `.../webview/in_app_webview/InputAwareWebView.java:209` / `:230` — `if (useHybridComposition) return;` 兩處守衛，翻預設會啟用此路徑，**未修改**。

### example 驗證載體

- `flutter_inappwebview/example/lib/screens/webview_tester_screen.dart:69` / `:83` / `:44` / `:139` / `:190` / `:215` — Scaffold 的 `resizeToAvoidBottomInset`、版面分支判斷、底部面板下限、`effectiveMax` 計算、resize handle、WebView 建構處。

## Details

**驗證方法學**：#1 的 gate 以一次性 integration test harness 驗證，探針取自 `AndroidInAppWebViewController._handleMethod` 在 switch 之前對每則進來的 platform message 所做的 debug log，因此量到的是「訊息有沒有跨過 channel」而非 Dart 端結果。七個情境的高頻事件訊息數：已註冊 5、未註冊 0、headless 5、InAppBrowser 5、windowId 新視窗 5、keepAlive 重掛前 0／重掛後 5。harness 已刪除，未進入 delta。

`scrollTo` 每次只產生一則事件，故該組數字驗證的是 gate 的語義正確性，不是 fling 時 60–120 次/秒的實際量級。
