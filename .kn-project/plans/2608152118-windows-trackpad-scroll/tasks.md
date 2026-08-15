# Tasks: Windows 觸控板捲動失效與不流暢

計畫：`plan.md`（同目錄）

## Phase A — 先量測
- [x] A1. Dart 端探針（事件種類、`panDelta`/`scrollDelta`、`localPosition`、`lastCursorPos` 鏡像）
- [x] A2. 建置並執行 `flutter_inappwebview_windows/example`，由使用者實測
      （前置：本機 `nuget.exe` 不在 PATH，需手動加入才能建置，見 plan 的 Follow-up）
- [x] A3. 分岔判定：觸控板**確實**走 `onPointerPanZoomUpdate`，非 `WM_MOUSEWHEEL`
- [x] A4. 實測數據推翻 R2 與 R4（`dy` 為 10–166 px；`lastCursorPos` 全程同步），已寫回 plan
- [x] A5. 原生端探針（`delta → whole → offset → asUint32 → HRESULT`）：1227 筆全部 `S_OK`，
      證明套件端完整送達，問題在 Chromium 對事件序列的解讀
- [x] A6. 單一變因實驗：關閉水平送出 → 使用者實測「上：正常 下：正常」，根因確立

## Phase B — 修復
- [x] B1. `in_app_webview.h` 新增水平/垂直殘量累加器成員
- [x] B2. `sendScroll` 改為殘量累加後送整數部分，整數為 0 時不送事件
- [x] B3. 同處補上溢位飽和，避免 `scrollMultiplier` 過大時繞回反號
- [x] B4. ~~手勢期間更新游標座標~~ **取消**：前提 R4 已被實測推翻（Deviations 已記錄）
- [x] B5. 新增 `onPointerPanZoomStart` / `onPointerPanZoomEnd` 與原生 `resetScrollRemainder`
- [x] B6. **軸鎖定（根因修復）**：每個手勢鎖定一次主導軸，累積位移超過 3px 才判定，
      鎖定前的位移一併補送；判定放在 Dart 端，原生 `setScrollDelta` 維持上游原樣
- [x] B7. 水平取負（`-dx`、`+dy`），兩軸的 wheel 語意不一致，推導已寫入註解
- [x] B8. 移除所有探針（Dart 與原生）

## Phase C — 驗證（使用者實機）
- [x] C1. 觸控板上下兩個方向皆正常
- [x] C2. 捲動流暢
- [x] C3. 滑鼠滾輪回歸：速度與修復前一致
- [x] C4. 水平捲動方向正確、距離合理（以本機測試頁的 `scrollX` HUD 對照）
- [ ] C5. `scrollMultiplier` 設 3 與 200 各試一次，確認無反向捲動（溢位飽和）
      —— **未執行**：溢位路徑需手動改 example 設定重建，且非本次症狀；
      程式碼層面已夾在 `short` 值域內
- [x] C6. `git diff upstream/master` 確認變更以新增為主

## Phase D — 收尾
- [ ] D1. Commit（Rule 17 逐項請示）
- [ ] D2. Phase 5 歸檔時，交由 `kn:project:wikification` 建立 Windows 捲動的 wiki 節點
- [ ] D3. 另開迭代處理慣性與斜滑兩軸（`SendPointerInput`，設定項閘控）——見 plan 的 Follow-up
