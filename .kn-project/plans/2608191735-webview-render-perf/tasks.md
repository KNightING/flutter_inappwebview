# Tasks for 2608191735

> Phase 順序依「風險遞增」安排：先做純本地、可自證的最佳化，最後才動會改變對外行為的 #5。
> Phase 3 與 Phase 4 都動 `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`，
> 必須循序，不可對調。

## Phase 1 — Windows 本地最佳化（#3 + #4）

- [x] `texture_bridge.h` / `texture_bridge.cc`：於基底類別加入「自上次取用後有無新影格」旗標，`OnFrameArrived()` 取得未被 fps limit 丟棄的影格時設起
- [x] `texture_bridge_gpu.cc`：`GetSurfaceDescriptor()` 改為僅在 dirty 或 `surface_` 為空時 `ProcessFrame`，之後清旗標
- [x] `texture_bridge_fallback.cc`：`CopyPixelBuffer()` 套用同一條件（`pixel_buffer_` 為空時強制處理）
- [x] `custom_platform_view.dart`：`_reportSurfaceSize` / `_reportWidgetPosition` 加入上次值快取與 `force` 參數
- [x] `custom_platform_view.dart`：去重改為只套用於 `onPointerDown`（`_reportGeometryIfMoved`），其餘路徑照送——原 `force` 設計經實測推翻，見 plan.md Key Decisions
- [x] Windows example 建置並實跑：初始渲染、點擊導覽、滾輪捲動、視窗縮放與移動皆正常（2026-08-19 以 computer-use 目視確認）
- [x] Windows example 人工補測：最小化後還原、切分頁（生命週期路徑）——2026-08-19 由使用者實測確認

## Phase 2 — iOS gesture 掃描降頻（#2）

- [x] `InAppWebView.swift`：把 `observeValue` 末端的 `replaceGestureHandlerIfNeeded()` 移入 `estimatedProgress` 與 `url` 兩個導覽相關分支
- [x] iOS example 實跑：長按選單（連結、文字、圖片）在首次載入、多次導覽、返回上一頁後皆正常
      （2026-08-19 iPhone 17 模擬器 / iOS 26.4，見下方驗證紀錄）
- [ ] iOS example 實跑：捲動流暢度目視比對（同一頁面改動前後）
      — 模擬器不具參考性（無真實 GPU/CPU 對應），保留給實機；捲動功能本身已確認正常

## Phase 3 — Android 高頻事件 gating（#1）

- [x] `in_app_webview_controller.dart`：抽出判斷「某高頻事件是否已註冊」的單一 helper，既有 dispatcher 改為引用它
- [x] `in_app_webview.dart`：`creationParams` 加入已註冊高頻事件集合（欄位名採內部命名，不進公開 settings）
- [x] （若 Q1 選 A）新增內部 method channel 呼叫，於 `_onPlatformViewCreated` 重新同步一次
- [x] `FlutterWebView.java`：讀入該欄位並交給 `WebViewChannelDelegate`；**欄位缺席時一律視為全開**
- [x] `WebViewChannelDelegate.java`：`onScrollChanged` / `onOverScrolled` / `onZoomScaleChanged` 三處 `invokeMethod` 前加 gate
- [x] Android example 實跑：註冊 `onScrollChanged` 時事件正常送達；不註冊時捲動無 channel 流量
- [x] Android example 實跑：InAppBrowser、headless、`windowId` 新視窗三條路徑行為不變（fail-open 驗證）
      （2026-08-19 emulator-5554 / Android 12 API 32，見下方驗證紀錄）

## Phase 4 — Android TLHC 預設切換（#5）

- [x] `in_app_webview_settings.dart`：建構子預設值改 `false`，並更新欄位文件註解說明預設已變
- [x] `in_app_webview.dart`：`?? true` 改為 `?? false`
- [x] `InAppWebViewSettings.java`：native 欄位預設改 `false`（依 Q3 決議）
- [x] 確認 `.g.dart` 產生檔是否需同步重新產生
- [x] `setLayerType` 與 `InputAwareWebView` 兩處**不修改**，僅覆核其在新預設下的分支走向

## Phase 5 — #5 實機驗證（依 Q5 決議執行）

> 以下每一項都必須在**實體 Android 裝置**上以真手指與真輸入法確認；模擬器與 `adb input` 測不出 IME 代理路徑。

- [ ] 中文輸入法（注音／拼音）在網頁輸入框可正常 composing、選字、送出
- [ ] `keyboardAvoidance` 仍能讓焦點輸入框保持可見（本 fork 旗艦功能，最高風險項）
- [ ] 鍵盤收起後版面正確還原
- [ ] 頁面內影片播放正常（TLHC 對 `SurfaceView` 的行為差異）
- [ ] pull-to-refresh 手勢正常
- [ ] 長按選單 / 文字選取正常
- [ ] 捲動流暢度目視比對（改動前後同一頁面）

## Phase 6 — 收尾

- [x] `flutter analyze` 通過
- [ ] 五項變更逐項覆核未超出 `## Impact Files` 所列範圍（delta 極小鐵則）
- [ ] 更新 `plan.md` 的 `- Status:` 與 `- Completed:`

---

## 驗證紀錄（2026-08-19）

### Phase 3 — Android gating（emulator-5554, Android 12 / API 32）

以一次性的 integration test harness 驗證後刪除，未進入 commit delta。探針有兩層：Dart 端
callback 計數，以及 `AndroidInAppWebViewController._handleMethod` 在 switch 之前對**每一則**
進來的 platform message 所做的 debug log（`excludeFilter` 設成只放行那三個高頻事件），因此
「視窗內有 log 行」＝訊息確實跨過 channel。每個視窗固定送 5 次 `scrollTo`。

| 情境 | 高頻事件 channel 訊息數 | 判讀 |
| --- | --- | --- |
| A 已註冊 `onScrollChanged` | 5（Dart callback 也是 5） | 正常送達，無遺漏 |
| B 三個 callback 都未註冊（另加一次 `zoomBy`） | 0 | gate 生效 |
| C headless（creationParams 無此欄位） | 5 | fail-open |
| D InAppBrowser（同上） | 5 | fail-open |
| E `windowId` 新視窗，已註冊 | 5（callback 5） | 新視窗路徑未被 gate 誤擋 |
| F1 keepAlive 建立時未註冊 | 0 | gate 起始關閉 |
| F2 同一 keepAlive WebView 重掛到有註冊的 widget | 5（callback 5） | `syncEnabledHighFrequencyEvents()` 重新同步成功 |

F1/F2 正是 commit message 點名的 keepAlive 重掛情境，確認 creationParams 之外的那次補送有效。

註：`scrollTo` 每次只產生一則事件，所以這組數字驗證的是 gate 的語義正確性，不是 fling 時
60–120 次/秒的實際量級。

### Phase 2 — iOS gesture 掃描（iPhone 17 模擬器, iOS 26.4）

以一次性 probe app（`initialData` 組出含連結／圖片／可選取文字的頁面，註冊
`onLongPressHitTestResult`）驗證後刪除。四個時間點各長按一次，`onLongPressHitTestResult`
皆正常觸發：

- 首次載入
- 連續 3 次導覽（`loadData` 換頁）之後
- `goBack()` 之後
- 上下捲動之後（原本 `contentOffset` KVO 是這條路徑的補掛保險，移除後仍正常）

連結與圖片的 WebKit 原生長按選單（Open Link / Copy Link / Share、Save to Photos / Copy）
在導覽與捲動之後皆正常出現。

過程中一度以為出現回歸，實為測試序列造成：前一次長按留下的 WebKit 預覽選單未關閉會吃掉下一次
長按。改以「長按文字」作為 app 啟動後的第一個動作對照，branch 與 `main`（僅將該 .swift 還原）
行為一致。
