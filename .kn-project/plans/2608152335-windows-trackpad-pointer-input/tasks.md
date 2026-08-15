# Tasks: Windows 觸控板改走 SendPointerInput

計畫：`plan.md`（同目錄）

## Phase A — 設定項（**最終全部回退，見 plan 的 Deviations**）
- [x] A1. ~~宣告 `useTrackpadPointerInput`~~ → 已實作並通過驗證，最後依實測結果整個移除
- [x] A2. ~~重新產生 `.g.dart`~~ → 同上，已回退
- [x] A3. ~~原生欄位／解析／回傳 map~~ → 同上，已回退
- [x] A4. `scrollMultiplier` 的 doc comment 註明僅作用於滾輪路徑（**保留**，改寫為不引用已刪除的設定）

## Phase B — 手勢改走觸控
- [x] B1. ~~依設定分流~~ → 無設定，觸控板一律走觸控路徑
- [x] B2. `panZoomStart` → `down`（座標取手勢起點）
- [x] B3. `panZoomUpdate` → `update`（座標為起點 + 累積 `pan`）
- [x] B4. `panZoomEnd` → `up`
- [x] B5. pointer id 取自事件本身（`ev.pointer`），不與真實觸控衝突
- [x] B6. 刪除軸鎖定（`_latchPanAxis` / `_panAxis` / `_panTravel`）與 `resetScrollRemainder`
      整組管線——觸控路徑天生支援二維捲動，前者失去意義，後者失去唯一呼叫者
- [x] B7. 與 `_pointerKind` / hover 無衝突（實測 hover 與拖曳皆正常）

## Phase C — 驗證（實機）
- [x] C1. 慣性存在且會自然停止
- [x] C2. 斜滑同時捲動兩軸
- [x] C3. 頁面確實收到 `touchstart/touchmove/touchend`，`wheel` 維持 0
- [x] C4. ~~關閉設定時行為與現行一致~~ → 已於移除設定前驗證通過（滾輪路徑完好），
      設定移除後此項不再適用
- [x] C5. 滑鼠滾輪不受影響
- [ ] C6. **未執行**：手邊無觸控螢幕裝置，真實觸控輸入未實測（見 plan 的 Deviations）
- [x] C7. `git diff` 確認淨變更為 **-32 行**，且無換行汙染
- [x] C8. 額外對照：hover 與拖曳在兩條路徑下皆正常，四項裝置能力查詢不變

## Phase D — 收尾
- [ ] D1. Commit（Rule 17 逐項請示）
- [ ] D2. Phase 5 歸檔時，交由 `kn:project:wikification` **改寫**
      `wiki/features/windows-scroll-input.md`——該頁的「無慣性、不支援斜滑」已不成立，
      軸鎖定與符號不一致的整段敘述亦須刪除，不能只追加
- [ ] D3. 發 tag（與 `2608152118` 的 Windows 捲動修復一併發布）
