# Tasks for 2608201704

## Phase 1 — 根因修正
- [x] `in_app_webview_manager.cpp:126` 的 `CreateWindowEx` 加上 `WS_CHILD`
- [x] `in_app_webview.cpp` 的 `setPosition` 改為 parent client 座標，移除標題列／邊框扣算

## Phase 2 — 焦點交付（迭代一）
- [x] `in_app_webview.h` 新增取得焦點的 private helper 宣告
- [x] `setPointerButtonState` 的 Down 分支：送輸入事件前先取得焦點
- [x] `setPointerUpdate` 的 Down 分支：同上（觸控路徑）

## Phase 3 — 驗證
- [x] 建置 `flutter_inappwebview_windows/example`（Windows）
- [x] 點網頁 input：第一下與第二下皆維持焦點，游標不消失
- [x] input 聚焦期間，應用程式視窗標題列維持啟用狀態
- [x] 鍵盤輸入正常；中文輸入法 composing 與候選字視窗位置正確（Q1 選項 A 的實測關卡）
- [x] `<select>` 下拉與右鍵選單的落點正確（setPosition 座標語意改動的驗證）
- [x] 既有輸入路徑未回歸：滑鼠點擊／拖曳、滾輪捲動、觸控板手勢
- [x] 視窗移動與縮放後，上述行為仍正確
- [x] 點擊 WebView 以外的 Flutter 元件後，鍵盤輸入回到 Flutter 端
