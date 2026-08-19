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
- [ ] Windows example 待人工補測：最小化後還原、切分頁（生命週期路徑）

## Phase 2 — iOS gesture 掃描降頻（#2）

- [x] `InAppWebView.swift`：把 `observeValue` 末端的 `replaceGestureHandlerIfNeeded()` 移入 `estimatedProgress` 與 `url` 兩個導覽相關分支
- [ ] iOS example 實跑：長按選單（連結、文字、圖片）在首次載入、多次導覽、返回上一頁後皆正常
- [ ] iOS example 實跑：捲動流暢度目視比對（同一頁面改動前後）

## Phase 3 — Android 高頻事件 gating（#1）

- [x] `in_app_webview_controller.dart`：抽出判斷「某高頻事件是否已註冊」的單一 helper，既有 dispatcher 改為引用它
- [x] `in_app_webview.dart`：`creationParams` 加入已註冊高頻事件集合（欄位名採內部命名，不進公開 settings）
- [x] （若 Q1 選 A）新增內部 method channel 呼叫，於 `_onPlatformViewCreated` 重新同步一次
- [x] `FlutterWebView.java`：讀入該欄位並交給 `WebViewChannelDelegate`；**欄位缺席時一律視為全開**
- [x] `WebViewChannelDelegate.java`：`onScrollChanged` / `onOverScrolled` / `onZoomScaleChanged` 三處 `invokeMethod` 前加 gate
- [ ] Android example 實跑：註冊 `onScrollChanged` 時事件正常送達；不註冊時捲動無 channel 流量
- [ ] Android example 實跑：InAppBrowser、headless、`windowId` 新視窗三條路徑行為不變（fail-open 驗證）

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
