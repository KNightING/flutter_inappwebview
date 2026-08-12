# Tasks: 修正邊緣返回手勢造成 WebView 頁面 fling

> 進 Phase 3 前需先結清 plan.md 的 Q2（是否加設定項閘控）。
> Q1（修法方向）刻意留到 Phase A 之後——機制未證實前選修法就是猜。

## Phase O — 可重複的人工驗證流程
- [ ] O1. 建立人工重現步驟並確認**穩定可重現**（合成 `input swipe` 無效，必須真手指）
- [ ] O2. 記錄基準：重現一次並擷取捲動位移量，作為修正後的比對基準
- [ ] O3. 確認在 `keyboardAvoidance` 開／關兩種狀態下皆重現——若只在其中一種發生，
      表示與該功能有關，需回頭修正 plan.md 的歸因

## Phase A — 證實機制（**未完成不得進 Phase B**）
- [ ] A1. 取得真實的 `MotionEvent` 序列：於 `onTouchEvent` 加暫時性記錄，
      印出 action、座標、時間戳，涵蓋整個返回手勢
- [ ] A2. 確認 `ACTION_CANCEL` 確實有送達，以及它與 fling 起始的時序關係
- [ ] A3. 確認 fling 是否真由 Chromium 的速度追蹤器啟動（對照 `MOVE` 的速度與實際位移量）
- [ ] A4. 若 A2/A3 推翻推測機制，**停下重新分析**，不得直接套用 Q1 的任一修法

## Phase B — 修正（依 A 的結果與 Q1 決議）
- [ ] B1. 實作選定方向
- [ ] B2. 移除 Phase A 的暫時性記錄
- [ ] B3. 依 Q2 決議決定是否加設定項

## Phase C — 驗證
- [ ] C1. 重現流程確認問題消失，並與 O2 的基準比對
- [ ] C2. **副作用檢查——正常的甩動捲動仍須正常**。這是本計畫最大的風險：
      修法若過度，會把使用者真正想要的慣性捲動一併中止
- [ ] C3. 多指觸控、父層攔截等其他會產生 `ACTION_CANCEL` 的情境不受影響
- [ ] C4. 從非 WebView 區域起始的返回手勢行為不變
- [ ] C5. `keyboardAvoidance` 開／關兩種狀態皆驗（確認兩個計畫的修改不互相干擾）

## Phase D — delta 檢查（本 repo 特有）
- [ ] D1. `git diff upstream/master` 確認變更範圍未逸出計畫
- [ ] D2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
