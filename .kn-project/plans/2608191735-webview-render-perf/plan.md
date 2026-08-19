<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608191735 - WebView 渲染效能最佳化（五項）

- Created: 2026-08-19
- Branch: `feature/2608191735-webview-render-perf`
- Issue: KNightING/flutter_inappwebview#16
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

消除四條「每幀都在付、但多數情境不需要付」的成本，並把 Android 的平台視圖合成模式
切到成本較低的一條。五項彼此獨立，可各自回退。

| # | 平台 | 目標 | 對外行為 |
| :-- | :--- | :--- | :--- |
| 1 | Android | 未註冊 callback 時，不再每幀送捲動事件過 channel | 不變 |
| 2 | iOS | 捲動時不再每幀掃描 gesture recognizer 的 description 字串 | 不變 |
| 3 | Windows | texture 沒有新影格時不再重複做全螢幕 GPU 複製 | 不變 |
| 4 | Windows | size / position 未變化時不再重設 WebView2 bounds | 不變 |
| 5 | Android | `useHybridComposition` 預設由 `true` 改為 `false`（TLHC） | **變更**（見 E 節風險） |

**共同前提**：#1~#4 以「零對外行為變更」為驗收條件；#5 是使用者明確拍板的行為變更，
其風險於 E 節完整揭露。

## Architecture

### A. Android 高頻事件 channel gating（#1）

**現況（實測佐證）**：native 端只要 `channelDelegate` 存在就送事件，不看 Dart 端有沒有註冊
callback。捲動時這是 60–120 次/秒的 `invokeMethod`，每次都付 StandardMessageCodec 編碼、
跨執行緒、Dart 端解碼的成本。

Dart 端其實**已經有一道 gate**，只是在收到訊息之後才判斷——成本已經付掉了：

```
(webviewParams != null && webviewParams!.onScrollChanged != null) || _inAppBrowserEventHandler != null
```

**設計**：把這道 gate 前移到 native。

- Dart 端以**單一 helper** 由 `webviewParams` / `_inAppBrowserEventHandler` 算出「已註冊的高頻
  事件集合」，序列化後隨 `creationParams` 傳入；helper 是唯一真相來源，避免與 dispatcher 的
  判斷式漂移（通用鐵則 §2 DRY）。
- native 端存為 `Set<String>`，`WebViewChannelDelegate` 於 `invokeMethod` 前先查。
- **納入的事件**（皆為每幀等級）：`onScrollChanged`、`onOverScrolled`、`onZoomScaleChanged`。
  `onContentSizeChanged` 只在內容尺寸真的改變時觸發，不納入。
- **fail-open（關鍵安全性質）**：creationParams 缺少該欄位時，native 端一律視為「全開」。
  任何本計畫未覆蓋到的建立路徑（headless、`windowId` 新視窗、InAppBrowser）行為完全不變。

**為何需要 runtime 重新同步（見 Q1）**：`InAppWebView` 每次 rebuild 都會產生新的 params 物件，
但 `_controller` 只在 `_onPlatformViewCreated` 建立一次；`keepAlive` 情境下同一個 native webview
還會被新的 widget 重新掛載。純 creationParams 快照在 keepAlive 重新掛載時會過期。

### B. iOS gesture 掃描降頻（#2）

**現況**：`observeValue` 的**最後一行**無條件呼叫 `replaceGestureHandlerIfNeeded()`。
`UIScrollView.contentOffset` 有掛 KVO，所以捲動時每幀都會觸發它。

它做的事是：`DispatchQueue.main.async` 排一個 block → 走訪 `scrollView.subviews` 全部的
`gestureRecognizers` → 對每一個取 `$0.description`（即時組出除錯字串）再做 `contains` 比對。
一秒上百輪，全在 main thread。

**設計**：只在**與頁面導覽相關**的 KVO 分支後呼叫——`estimatedProgress` 與 `url`。
WebKit 重建 long-press gesture 的時機就是導覽（見程式碼既有註解引用的
`https://bugs.webkit.org/show_bug.cgi?id=193366`），而 `estimatedProgress` 在每次載入都會
觸發多次，覆蓋率足夠。`contentOffset` / `contentSize` / captureState / fullscreenState
分支不再呼叫。

> 保守側：本項只減少呼叫**次數**，不改 `replaceGestureHandlerIfNeeded()` 自身的邏輯，
> 因此「找不到就補掛」的既有語意完整保留。

### C. Windows texture dirty flag（#3）

**現況**：`GetSurfaceDescriptor()` 不管 `last_frame_` 是不是上次那一張，都照做一次全尺寸
`CopyResource` + `Flush()`。Flutter 每次合成這個 texture 都會呼叫它——WebView 靜止但畫面上
有其他動畫時（loading 轉圈、頁面轉場），等於每幀白做一次 GPU 複製。

**設計**：在 `TextureBridge` 基底類別加一個「自上次取用後是否有新影格」的旗標。

- `OnFrameArrived()` 成功取得且未被 fps limit 丟棄的影格 → 設為 dirty。
- `GetSurfaceDescriptor()` / `CopyPixelBuffer()` 只在 dirty 時 `ProcessFrame`，之後清除旗標。
- **必要的例外**：GPU 路徑的 `StopInternal()` 會把 `surface_` 設為 `nullptr`（註解說明恢復時
  必須重建）。因此條件是 `dirty || !surface_`，否則 resume 後會回傳空 surface。
  fallback 路徑對應的是 `pixel_buffer_` 為空的情形。
- 旗標與 `last_frame_` 一樣受既有的 `mutex_` 保護，不引入新的同步原語。

### D. Windows size / position 去重（#4）

**現況**：`onPointerDown` 每次都呼叫 `_reportSurfaceSize()` + `_reportWidgetPosition()`，
各一次 method channel，最後落到 native 的 `put_RasterizationScale` + `put_Bounds` +
`SetWindowPos`。尺寸與位置沒變也照做，等於每次點擊都戳一下 WebView2 的 compositor。

**設計**：在 `_CustomPlatformViewState` 快取上次送出的 size / position / scaleFactor，
值完全相同就不送。

- **關鍵細節（不做會造成回歸）**：`AppLifecycleListener` 在 `resumed` / `hidden` 時的重報是
  **刻意的**——WebView2 恢復時需要重新設定 bounds，即使數值沒變。因此兩個上報方法需要
  `force` 參數，生命週期路徑傳 `true` 繞過去重。
- 一般路徑（`onPointerDown`、`SizeChangedLayoutNotification`、`onWindowMove`）走去重。
  視窗移動時位置本來就變了，去重不會擋到它。

### E. Android `useHybridComposition` 預設改為 `false`（#5）

**現況**：預設 `true` → `PlatformViewsService.initExpensiveAndroidView`（Hybrid Composition）。
改為 `false` → `initSurfaceAndroidView`（Texture Layer Hybrid Composition，TLHC），
也是現行 `webview_flutter` 的預設。

**預設值散在三處，必須同步翻，否則行為不一致**：

1. `platform_interface` 的建構子預設值 — 決定使用端不傳設定時的值
2. `_android` widget 的 `?? true` fallback — 決定 `initialSettings` 為 null 時走哪條
3. Android native 的欄位預設 — 決定 native 端的 `setLayerType` 與 IME 代理路徑

**風險（必須在驗收時實機確認）**：

- **翻預設會啟用一條至今休眠的 IME 代理路徑。** `InputAwareWebView` 的
  `ThreadedInputConnectionProxyAdapterView` 機制**只有在 `useHybridComposition == false` 時
  才生效**（`dispose()` 與 `checkInputConnectionProxy()` 開頭都是 `if (useHybridComposition) return;`）。
  換句話說預設使用者從未走過這條路徑，翻預設等於一次性啟用它——而它正好直接關係到本 fork
  的旗艦功能 `keyboardAvoidance`。**這是本計畫風險最高的一項。**
- **與上游產生行為分歧。** 違反 `project.md`「delta 保持極小」鐵則的精神。使用者已拍板接受，
  記入 Key Decisions。變更本身是三個字面值，拉取上游時衝突面極小。
- **`hardwareAcceleration` 設定在 TLHC 下不再套用。** native 端的 `setLayerType(LAYER_TYPE_HARDWARE)`
  被包在 `if (customSettings.useHybridComposition)` 內。本計畫**不改動**這段——那是上游刻意的
  區分（TLHC 本就走 texture，強設 layer type 沒有意義），但要知道這個副作用。
- TLHC 對 `SurfaceView`（影片、地圖）與 pull-to-refresh 的行為與 HC 不同，需實測。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-19 在 `main`（`da2ded8cb`）上以 Grep 確認。

### A. Android 高頻事件 gating（#1）

- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebView.java:1443`
  — `onScrollChanged()` 內 `if (channelDelegate != null) channelDelegate.onScrollChanged(x, y);`，
  無條件送出，是本項的主要成本點。
- `.../in_app_webview/InAppWebView.java:1699`
  — `onOverScrolled()` 內同形的無條件送出。
- `.../webview/WebViewChannelDelegate.java:763` / `:784` / `:1145`
  — `onScrollChanged` / `onOverScrolled` / `onZoomScaleChanged` 三個 `channel.invokeMethod`，
  gate 實際掛載處。
- `.../webview/in_app_webview/FlutterWebView.java`
  — 解析 creationParams 的入口，新欄位由此讀入並交給 `WebViewChannelDelegate`。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart:352`
  — `creationParams` map 的組裝處，新欄位加在這裡。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview_controller.dart:375`
  — 既有的 Dart 端 gate（`webviewParams!.onScrollChanged != null || _inAppBrowserEventHandler != null`），
  新 helper 必須與此判斷式完全一致，並改由 helper 供應以避免漂移。

### B. iOS gesture 掃描（#2）

- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Sources/flutter_inappwebview_ios/InAppWebView/InAppWebView.swift:935`
  — `observeValue` 末端無條件呼叫 `replaceGestureHandlerIfNeeded()`，本項唯一要改的一行。
- `.../InAppWebView.swift:255`
  — `replaceGestureHandlerIfNeeded()` 定義；`DispatchQueue.main.async` + `description` 掃描的成本來源。
  **本項不修改此方法本身**，僅列為理解成本用。
- `.../InAppWebView.swift:486`
  — `scrollView.addObserver(... contentOffset ...)`，高頻觸發源，說明為何每幀都會打到 :935。

### C. Windows texture dirty flag（#3）

- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge.h:50`
  — `last_frame_` 等共用狀態的宣告處，新旗標加在此基底類別。
- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge.cc:107`
  — `OnFrameArrived()`，取得新影格處，設 dirty。
- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge_gpu.cc:89`
  — `GetSurfaceDescriptor()` 內無條件的 `ProcessFrame(last_frame_)`。
- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge_gpu.cc:100`
  — `StopInternal()` 把 `surface_` 設為 `nullptr`，是 dirty 條件必須加上 `|| !surface_` 的原因。
- `flutter_inappwebview_windows/windows/custom_platform_view/texture_bridge_fallback.cc:120`
  — `CopyPixelBuffer()` 內同形的無條件 `ProcessFrame`（fallback 建置路徑）。

### D. Windows size / position 去重（#4）

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart:557`
  — `_reportSurfaceSize()` / `_reportWidgetPosition()` 定義處，去重與 `force` 參數加在這裡。
- `.../custom_platform_view.dart:340`
  — `AppLifecycleListener` 的 `resumed` / `hidden` 重報，**必須傳 `force: true`**。
- `.../custom_platform_view.dart:361`
  — `onWindowMove()` 的重報。
- `.../custom_platform_view.dart:380`
  — `SizeChangedLayoutNotification` 的重報。
- `.../custom_platform_view.dart:397`
  — `onPointerDown` 的重報，本項要消除的主要冗餘來源。

### E. Android TLHC 預設（#5）

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:3448`
  — 建構子的 `this.useHybridComposition = true`，預設值正本。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1176`
  — 欄位宣告與文件註解，需同步更新說明。
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart:323`
  — `?? true` fallback。
- `.../in_app_webview/InAppWebViewSettings.java:133`
  — native 端 `public Boolean useHybridComposition = true;`。
- `.../in_app_webview/InAppWebView.java:445`
  — `if (customSettings.useHybridComposition) setLayerType(...)`，**不修改**，列為副作用佐證。
- `.../in_app_webview/InputAwareWebView.java:209` / `:230`
  — `if (useHybridComposition) return;` 兩處守衛，證明翻預設會啟用休眠的 IME 代理路徑。

### 新增

- 無（皆為既有檔案的行為修正）。

## Open Questions / 待確認事項

> 全部釐清前不得進入 Phase 3。

### Q1. #1 的 gating 是否加上 runtime 重新同步？ — 影響範圍：`_android` 的 dart + java

`InAppWebView` 每次 rebuild 產生新 params，但 `_controller` 只建立一次；`keepAlive` 更會讓同一個
native webview 被新 widget 重新掛載。純 creationParams 快照在那些情境會過期（可能少送事件）。

- [x] 選項 A：creationParams + 一個內部 method channel（於 `_onPlatformViewCreated` 重新同步一次）
      (建議，理由：多約 30 行，換掉整類「事件靜默消失」的難查 bug；keepAlive 是本 fork 使用端會用到的路徑)
- [ ] 選項 B：只做 creationParams 快照
      (delta 最小，但 keepAlive 重新掛載後若 callback 集合改變會少送事件)
- **決議**：選項 A　狀態：✅ 已確認

### Q2. #1 是否同步套用到 iOS？ — 影響範圍：`_ios` 的 swift + dart

iOS 有完全相同的模式（`InAppWebView.swift:2705` 的 `channelDelegate?.onScrollChanged`）。

- [x] 選項 A：本輪只做 Android
      (建議，理由：iOS 的捲動成本主要由 #2 解決；同時動兩個平台會讓驗證面積翻倍，且 #2 尚未實測)
- [ ] 選項 B：Android 與 iOS 一起做
- **決議**：選項 A　狀態：✅ 已確認

### Q3. #5 的三處預設值處置 — 影響範圍：`platform_interface` + `_android` dart + java

- [x] 選項 A：三處全部翻為 `false`
      (建議，理由：只翻其中一處會讓「使用端不傳設定」與「傳了部分設定」走到不同分支，是更難查的不一致)
- [ ] 選項 B：只翻 Dart 端兩處，native 預設保留 `true`
- **決議**：選項 A　狀態：✅ 已確認

### Q4. 是否把本計畫拆成多份獨立計畫？（Rule 22） — 影響範圍：治理

檢視結果：#2（iOS swift）、#3（Windows C++）、#4（Windows dart）三者彼此無檔案重疊、無執行相依，
**符合提升為獨立計畫的條件**；#1 與 #5 都動
`flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`，**有檔案重疊，不可拆開**。

- [x] 選項 A：不拆，一份計畫一個分支一個 PR
      (建議，理由：五項同屬一次效能盤點，合併驗收較有意義；拆開會變成 4 份計畫 / 4 張 issue / 4 個 PR)
- [ ] 選項 B：拆成 4 份（`#1+#5` 合一、`#2`、`#3`、`#4` 各一），可平行推進、分批合併
- **決議**：選項 A　狀態：✅ 已確認

### Q5. #5 的實機驗證由誰執行？ — 影響範圍：驗收

`useHybridComposition=false` 啟用休眠的 IME 代理路徑，**無法以自動化或模擬器充分驗證**
（輸入法 composing、鍵盤避讓都需要真手指與真輸入法）。

- [x] 選項 A：由使用者在實機上依 `tasks.md` 的驗證清單逐項確認，回報後才進 Phase 4
      (建議，理由：與 `2608121440-back-gesture-fling` 同樣的方法學限制——合成注入測不出真實行為)
- [ ] 選項 B：僅做建置與 example 目視，接受未驗證風險
- **決議**：選項 A　狀態：✅ 已確認

## Key Decisions

- **[Q1]** #1 的 gating 採「creationParams + 內部 method channel 重新同步」——
  理由：`_controller` 只在 platform view 建立時抓一次 params，`keepAlive` 會讓同一個 native
  webview 被新 widget 重新掛載，純快照會過期並造成事件靜默消失。
- **[Q2]** #1 本輪只做 Android，iOS 不同步套用——
  理由：iOS 的捲動成本主要由 #2 解決；同時動兩個平台會讓驗證面積翻倍，而 #2 尚未實測。
- **[Q3]** #5 的三處預設值（`platform_interface` 建構子、`_android` widget 的 `?? true`、
  Java 欄位）全部翻為 `false`——理由：只翻其中一處會讓「不傳設定」與「傳了部分設定」走到
  不同分支，是比行為變更本身更難查的不一致。
- **[Q4]** 不拆分計畫，五項共用一個分支與一個 PR——
  理由：#2 / #3 / #4 雖符合 Rule 22 的提升條件，但五項同屬一次效能盤點，合併驗收較有意義；
  拆開會變成 4 份計畫 / 4 張 issue / 4 個 PR。#1 與 #5 共用同一個 Dart 檔，本就不可拆開。
- **[Q5]** #5 的驗收採實機人工驗證，由使用者依 `tasks.md` Phase 5 清單回報——
  理由：IME 代理路徑與鍵盤避讓需要真手指與真輸入法，`adb input` 這類合成注入測不出來
  （與 `2608121440-back-gesture-fling` 遇到的是同一個方法學限制）。
- **[執行中，實測推翻原設計]** #4 的去重**只套用在 `onPointerDown`**，其餘上報路徑一律照送——
  理由：原設計對所有路徑去重，實跑後 WebView 整片空白。根因是
  `custom_platform_view.cc` 的 `setSize` handler 同時負責 `texture_bridge_->Start()` 與
  `put_Bounds`，而 `InAppWebView::setSurfaceSize` 在 `webViewController` 尚未建立時會直接 return
  ——**那些看似多餘的重複上報其實是重試機制**。已用 A/B 實測確認（去重全開＝空白、僅關 #4＝正常）。
  原計畫的 `force` 參數設計隨之作廢，改以獨立的 `_reportGeometryIfMoved()` 承載。
- **[實測澄清]** 視窗縮放時網頁內容被拉伸**是上游既有行為，非本計畫造成**——
  在完全未套用任何改動的基準版上以相同操作重現。成因是 texture 先被縮放到新的 widget 尺寸，
  WebView2 重新排版後的新影格才跟上。不在本計畫範圍內處理。
- **[執行中]** `in_app_webview_settings.g.dart` 以手改方式同步預設值與文件註解，未重跑產生器——
  理由：產生器輸出僅此一處差異，手改的 delta 與重新產生等價，但避免整份 `.g.dart` 因產生器版本
  差異而出現大量無關變更（違反 delta 極小鐵則）。
- **[執行中]** #1 的 native gate 以 `enabledHighFrequencyEvents == null` 為 fail-open 判準，
  Dart 端 helper 在 `webviewParams == null` 或有 InAppBrowser handler 時回傳全部事件——
  理由：InAppBrowser 的 controller 於建構期才綁定 handler，以「參數為 null 就全開」作為判準
  比依賴綁定順序穩固。
- **[使用者拍板 2026-08-19]** #5 採 TLHC（`useHybridComposition` 預設改 `false`）——
  理由：使用者在檢查報告後明確選擇此方向，接受與上游產生行為分歧的代價。
  本計畫的職責是把該分歧的範圍與風險限制到最小（三個字面值 + 完整實機驗證清單）。
- **[範圍]** #6（WebView 生命週期暫停 / `pauseTimers`）不納入本計畫——
  理由：使用者對「執行到一半的程式被停掉」有疑慮，且該行為屬於 App 政策而非套件預設，
  正確形態應是新增可選設定而非改預設。詳見下方 References 的說明。

## Git Completion Policy

- PR body 必須含 `Closes #${N}`（`${N}` 取自上方 `- Issue:`），歸檔後於該 issue 張貼由 archive 蒸餾的結案留言。
- 經核准的 Commit 後，完成階段會執行 `git rebase main` 與
  `git push --force-with-lease --force-if-includes`（本 repo 預設主幹由 `refs/remotes/origin/HEAD`
  判定為 `origin/main`）。
- **PR 一律指向 `KNightING/flutter_inappwebview`**；本 repo 是 `pichillilorenzo` 的 fork，
  `gh pr create` 預設指向 parent。已確認 `gh repo set-default --view` 回報
  `KNightING/flutter_inappwebview`。
- 實作一律遵守 `kn:project:code-style` 的通用鐵則（該技能目前無 Dart / Java / Swift / C++ 的
  語言層規範，故以「貼合既有風格」與通用鐵則為準）。

## References

- 現有 Wiki 節點：[windows-scroll-input](../../wiki/features/windows-scroll-input.md)
  — #4 動到的 `custom_platform_view.dart` 是該節點描述的輸入合成路徑所在檔案；#4 只碰
  size / position 上報，不碰指標輸入，兩者不衝突。歸檔時需由 wikification 判斷是否補充。
- 現有 Wiki 節點：[keyboard-avoidance](../../wiki/features/keyboard-avoidance.md)
  — #5 的最大風險面，翻預設會啟用該功能所依賴視圖層之外的 IME 代理路徑。
- 活躍計畫 `2608121440-back-gesture-fling` 同樣動 `InAppWebView.java`，但落在
  `onTouchEvent`（:1585）；本計畫落在 `onScrollChanged`（:1443）與 `onOverScrolled`（:1699），
  無重疊。兩者若同期推進，合併時需注意同檔案不同區段。
- **#6 未納入的技術理由**：Android 的 `WebView.pauseTimers()` 是**行程層級**的，會影響 App 內
  所有 WebView 實例；`onPause()` 則會停掉 JS timer、`requestAnimationFrame` 與 CSS 動畫。
  執行到一半的同步 JS 不會被中斷，但任何靠 timer 續跑的流程（輪詢、上傳進度、遊戲迴圈）
  會停在原地。這正是使用者的疑慮所在，因此不作為預設行為。
