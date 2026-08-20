# 2608121440 - 修正邊緣返回手勢造成 WebView 頁面被甩動

- Created: 2026-08-12 / Archived: 2026-08-20
- Issue: N/A（同 2608121003，當時誤判本 repo 的 GitHub Issues 已停用）

## Summary

消除「從螢幕邊緣往內滑做返回手勢時，若起點落在 WebView 區域，網頁會被甩走」的行為；
修法為在 `InAppWebView.onTouchEvent` 前置守衛中丟棄系統注入的合成 `ACTION_MOVE`，僅影響 Android。
**本計畫最重要的產出是機制被實測推翻**：原推測「fling 已啟動而 `ACTION_CANCEL` 未使其中止」是錯的——
根本沒有 fling。真因是系統在 `CANCEL` 前送出一個 y 座標憑空跳 268–269px 的合成 `ACTION_MOVE`，
Chromium 把它當成真實捲動輸入照做，而 `CANCEL` 不會撤銷已套用的捲動。
影響檔案僅 `flutter_inappwebview_android` 的 `InAppWebView.java`，不新增設定項。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **與軟鍵盤避讓計畫（2608111609）拆開**（Rule 8 分類）。理由：實測證實兩者機制不同——本問題是文件捲動、
  與鍵盤無關，`keyboardAvoidance` 開關不影響它。混在同一計畫會讓驗證無法歸因。
- **Q1 修法採 C：僅在起點落於系統手勢區時丟棄異常 MOVE**。以 `getSystemGestureInsets()` 於 `ACTION_DOWN`
  判定起點是否在邊緣手勢帶，是才啟用位移門檻攔截。副作用面最小——畫面中央的快速滑動完全不受影響。
  門檻取 **48dp**：實測真實 MOVE 單事件位移 ≤ 16px（約 6dp），合成 MOVE 為 268–269px（約 98dp），
  相差一個數量級以上。即使誤判也只掉**一個中間事件**，後續事件仍帶正確絕對座標，位置不累積偏差。
- **丟棄時刻意不更新 `lastGestureX/Y`**。該事件對本手勢視同未發生；若更新，下一個真實事件會相對假座標
  算出巨大位移而被連帶誤判。
- **Q2 不加設定項，無條件修正**。理由：這是明確的錯誤行為，沒有使用端會想保留它，加開關等於為一個
  沒人要的行為增加 delta。**連帶約束**：失去逃生口，因此副作用檢查（正常甩動捲動仍須正常）
  由「應該做」升為發布前硬性條件。
- **Q1 刻意延後到機制證實之後才決定**。理由：本次工作已因憑推理猜測成因誤判三次，三次皆由實測推翻；
  機制未證實前選修法只會是第四次。

## Deviations

- **`plan.md` 的生命週期欄位從未更新**：歸檔時仍記載 `Status: Planning` 與「分支尚未建立」，
  但程式碼早在 2026-08-12 即完成並合併（`5d26f5b36` → `ac0af40dd`）。屬 Phase 3 步驟 4 的紀律失誤，
  而非工作未做——這也是它滯留 `plans/` 八天的原因。
- **Phase O（可重複的人工驗證流程）三項全部未執行**：實際上直接進入 Phase A 的實測擷取。
- **以下驗證項至今未結清**：
  - `A6` — 「合成 MOVE 與 CANCEL 共用 `eventTime`」是否為 Android 通用行為，僅在單一裝置
    （`M4AIB763K212ZBA`）觀察到。**最終修法不依賴此特徵**，故未阻擋交付。
  - `C3` — 多指觸控、父層攔截等其他會產生 `ACTION_CANCEL` 的情境未驗。
  - `C4` — 從非 WebView 區域起始的返回手勢未實際確認（該路徑本就不經過本修正）。
  - `C5-b` — **鍵盤開著時做邊緣返回手勢**未驗。這是本修正與 `keyboardAvoidance` 唯一交會的路徑：
    手勢修正丟棄 `MOVE` 的同時，IME 動畫回呼正逐幀更新鍵盤高度。需真手指操作，合成注入無效。
  - `D1`/`D2` — delta 檢查與 PR 目標 repo 確認無紀錄。
- **原 Q1 的三個候選全部作廢**（`flingScroll(0,0)`、`CANCEL` 時還原捲動位置、手勢區特殊處理），
  因其建立在被推翻的機制上。

## Impact Files

- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebView.java:1604`
  — `onTouchEvent` 開頭的守衛：`if (shouldDropSystemGestureArtefact(ev))` 即不轉交 `super`
- 同檔 `:1637` — `shouldDropSystemGestureArtefact(MotionEvent)` 本體（API 29 以下無手勢導航，直接不介入）
- 同檔 `:129` — 方法的 Javadoc 交叉引用

## Details

**實測數據**（使用者真手指操作，無鍵盤，三次皆重現）。事件序列固定為
`DOWN → 1 個真實 MOVE → 1 個合成 MOVE → CANCEL`：

| 手勢 | DOWN | MOVE 1 | MOVE 2（合成） | Δy |
| :--- | :--- | :--- | :--- | ---: |
| 1 | y=1407 | y=1407 | y=1676 | +269 |
| 2 | y=1472 | y=1471 | y=1740 | +269 |
| 3 | y=1549 | y=1547 | y=1815 | +268 |

x 於同一段僅移動 5–16px（手指是水平滑動），y 卻跳 268–269px，三次高度一致，是系統產生的固定值而非手指軌跡。
`CANCEL` 後 8–13ms 出現**單獨一次**捲動事件——非 fling（fling 會產生一連串遞減事件，對照組的正常滑動即為該形態）。

**兩個方法學教訓，值得未來沿用**：

1. `adb shell input swipe` **測不出本問題**——它直接注入事件，繞過系統手勢辨識器，不會震動也不會發
   `ACTION_CANCEL`。此類問題的驗證必須由真實手指操作，自動化在此無效。
2. `View.getScrollY()` **在現代 WebView 上恆為 0**，不反映頁面捲動（內容捲動發生在 Chromium 的
   compositor 內），不可作為量測訊號。

相關 commit：`5d26f5b36`（修正本體）、`ac0af40dd`（併入 main）、`3eca2c09a`（與軟鍵盤避讓首次共存於同一建置）。
