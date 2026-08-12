# Tasks: 修正邊緣返回手勢造成 WebView 頁面 fling

> 進 Phase 3 前需先結清 plan.md 的 Q2（是否加設定項閘控）。
> Q1（修法方向）刻意留到 Phase A 之後——機制未證實前選修法就是猜。

## Phase O — 可重複的人工驗證流程
- [ ] O1. 建立人工重現步驟並確認**穩定可重現**（合成 `input swipe` 無效，必須真手指）
- [ ] O2. 記錄基準：重現一次並擷取捲動位移量，作為修正後的比對基準
- [ ] O3. 確認在 `keyboardAvoidance` 開／關兩種狀態下皆重現——若只在其中一種發生，
      表示與該功能有關，需回頭修正 plan.md 的歸因

## Phase A — 證實機制（**已完成，且推翻原推測**）
- [x] A1. 於 `onTouchEvent` 加暫時性記錄（action／座標／`eventTime`／`getScrollY()`），
      由使用者真手指操作三次返回手勢取得序列
- [x] A2. `ACTION_CANCEL` **確實送達**，序列固定為 `DOWN → 1 真實 MOVE → 1 合成 MOVE → CANCEL`
- [x] A3. **推測機制被推翻**：沒有 fling。`CANCEL` 後 8–13ms 出現**單獨一次**捲動事件，
      而非 fling 的連續遞減序列（對照組的正常滑動才是後者）。
      真因是 `CANCEL` 前那個**合成 MOVE 的 y 座標憑空跳 268–269px**，Chromium 照做
- [x] A4. 已依規定停下重新分析，並作廢 Q1 原本的三個候選（皆基於錯誤機制）
- [x] A5. 額外發現：`View.getScrollY()` **在現代 WebView 上恆為 0**，不反映頁面捲動
      （內容捲動發生在 Chromium 的 compositor 內），不可作為量測訊號
- [ ] A6. **待補**：確認「合成 MOVE 與 CANCEL 共用 `eventTime`」是 Android 通用行為，
      而非測試機（`M4AIB763K212ZBA`）特性。若修法依賴此特徵則為前置條件

## Phase B — 修正（Q1=C：僅邊緣起始時丟棄異常 MOVE）
- [x] B1. `InAppWebView.shouldDropSystemGestureArtefact(MotionEvent)`，於 `onTouchEvent` 開頭守衛：
      `ACTION_DOWN` 以 `getSystemGestureInsets()` 判定起點是否在邊緣手勢帶並記下座標；
      `ACTION_MOVE` 僅在旗標成立時檢查，單事件位移 > **48dp** 即丟棄（不轉交 `super`）；
      其餘 action 清旗標。API 29 以下無手勢導航，直接不介入。
      **丟棄時刻意不更新 `lastGestureX/Y`**——該事件對本手勢視同未發生，若更新，
      下一個真實事件會相對假座標算出巨大位移而被連帶誤判
- [x] B2. Phase A 的暫時性記錄已移除（`grep TEMP-DEBUG|KBGESTURE` 無殘留）
- [x] B3. 依 Q2 決議**不加設定項**，無條件生效

## Phase C — 驗證
- [x] C1. 使用者實機確認：邊緣返回手勢起點落在 WebView 區域，**網頁不再往上跑**
- [x] C2. **副作用檢查通過**：畫面中央的快速甩動捲動不受影響；
      **從螢幕最邊緣開始的正常垂直捲動**（最可能被誤傷的情境——起點在手勢帶內、旗標成立）
      手感正常。此為發布前硬性條件（無設定項可關），已滿足
- [ ] C3. 多指觸控、父層攔截等其他會產生 `ACTION_CANCEL` 的情境**未驗**
- [ ] C4. 從非 WebView 區域起始的返回手勢行為不變 — **未驗**（該路徑本就不經過本修正，
      但未實際確認）
- [ ] C5. `keyboardAvoidance` 開／關兩種狀態皆驗 — **未驗**。本分支自 `main` 切出，
      不含軟鍵盤分支的最新修正；兩者合併後需確認互不干擾

## Phase D — delta 檢查（本 repo 特有）
- [ ] D1. `git diff upstream/master` 確認變更範圍未逸出計畫
- [ ] D2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
