<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608121440 - 修正邊緣返回手勢造成 WebView 頁面 fling

- Created: 2026-08-12
- Issue: N/A（無 issue 追蹤基準——本 repo 為 fork，GitHub Issues 已停用）
- Branch: `feature/2608121440-back-gesture-fling`（尚未建立）
- Status: Planning
- Completed: [Wait for Finish]

## Goals

消除「從螢幕邊緣往內滑做返回手勢時，若起點落在 WebView 區域，網頁會被甩動捲走」的行為。

使用者體驗上，返回手勢不該對頁面內容造成任何副作用。

## Architecture

### 現象（實測，非推論）

使用者於 2026-08-12 回報，並於 `kb_probe` 探針擷取到完整事件序列。

**觸發條件**（使用者實測歸納）：
- 手勢起點必須落在 **WebView 區域**；起點在其他 Flutter widget 則不發生。
- 與軟鍵盤**無關**——鍵盤未開啟時同樣發生。
- 在套件自帶的 example 亦可重現。
- 發生於系統確認返回手勢的那一刻（使用者以「觸發系統震動」描述）。

**擷取數據**（14:12:49，`keyboardAvoidance=false`，無鍵盤）：
15 筆 `scroll` 事件集中於 250ms，焦點元素底部由 1531 單調遞減至 41 實體 px，
逐幀差值 `52 → 61 → 264 → 110 → 215 → 105 → 101 → 99 → 95 → 91 → 88 → 84 → 81 → 44`
——先衝高再遞減衰減，是典型的 fling 減速曲線。

全程 `visualViewport.offsetTop` 維持 14.9 不變，**visual viewport 未參與**；動的是文件捲動位置。
因此與 `2608111609-webview-keyboard-avoidance` 處理的 Chromium `ScrollFocusedEditableIntoView`
是**兩件不同的事**，該功能開或關都不影響本現象。

### 機制（**Phase A 已實測證實，2026-08-12**）

> **原推測「fling 已啟動、`CANCEL` 未使其中止」是錯的，實測推翻。** 根本沒有 fling。
> 原文保留於本節末以供追溯。

系統接管返回手勢時，會在 `ACTION_CANCEL` 之前送出一個**位置被大幅位移的合成 `ACTION_MOVE`**，
兩者的 `eventTime` **完全相同**（同一批送達）。這是 Android 讓使用 slop 判定的 View 主動放棄的
既有機制。但 **Chromium 把那個位移當成真實捲動輸入照做**，隨後才收到 `CANCEL`——而 `CANCEL`
不會撤銷已套用的捲動。

三次實測（使用者真手指操作，無鍵盤，皆重現）：

| 手勢 | DOWN | MOVE 1 | MOVE 2（合成） | Δy | CANCEL |
| :--- | :--- | :--- | :--- | ---: | :--- |
| 1 | y=1407 | y=1407 | **y=1676** | +269 | y=1676，`t` 同 MOVE 2 |
| 2 | y=1472 | y=1471 | **y=1740** | +269 | y=1740，`t` 同 MOVE 2 |
| 3 | y=1549 | y=1547 | **y=1815** | +268 | y=1815，`t` 同 MOVE 2 |

x 於同一段僅移動 5–16px（手指是水平滑動），y 卻跳 268–269px。三次位移量高度一致，
是系統產生的固定值而非手指軌跡。

事件序列固定為 `DOWN → 1 個真實 MOVE → 1 個合成 MOVE → CANCEL`，
且 `CANCEL` 後 **8–13ms 出現「單獨一次」捲動事件**——非 fling（fling 會產生一連串遞減事件，
對照組的正常滑動即為該形態）。

捲動落在**手勢起點下方的可捲動元素**上（探針中為內層容器，故事件為 `scroll:innerscroll`；
在無內層容器的頁面則為文件本身）。這與使用者在 example app 觀察到的一致。

<details><summary>原推測機制（已被推翻，保留追溯）</summary>

Android 的手勢返回需要觀察一段軌跡才能判定。判定完成前，`ACTION_DOWN` 與數個 `ACTION_MOVE`
已經送進 WebView，Chromium 的速度追蹤器開始累積速度。系統確認手勢後補發 `ACTION_CANCEL`，
但 fling 已經以既有速度啟動，`CANCEL` 並未使其中止。

</details>

### 尚未驗證的前提
「合成 MOVE 與 CANCEL 共用 `eventTime`」目前只在**一台裝置**（`M4AIB763K212ZBA`）觀察到。
若要以此為修正的判定依據，需確認它是 Android 的通用行為而非本機特性。

### 合成注入無法重現（方法學限制）

`adb shell input swipe` **測不出本問題**——它直接注入事件，繞過系統手勢辨識器，不會震動、
也不會發 `ACTION_CANCEL`。本計畫的所有驗證都必須由**真實手指**操作，這會使自動化受限，
Phase A 需先建立可重複的人工驗證流程。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-12 在 `main` 上確認。

### 既有
- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebView.java:1585`
  — `public boolean onTouchEvent(MotionEvent ev)`。目前只記錄 `lastTouch`、於 `ACTION_DOWN` 停用
  pull-to-refresh，然後 `super.onTouchEvent(ev)`。**未對 `ACTION_CANCEL` 做任何處置**。
- `flutter_inappwebview_android/.../InAppWebView.java:547`
  — `setOnTouchListener(...)`，另一條觸控路徑，回傳 `false` 不消耗事件。
- `flutter_inappwebview_android/.../InAppWebView.java:571`
  — 既有的 `case MotionEvent.ACTION_CANCEL:`，但位於 `disableHorizontalScroll ||
  disableVerticalScroll` 的區塊內，作用是鎖住事件座標以停用單軸捲動，**與中止 fling 無關**，
  且該區塊在預設設定下不會執行。
- `flutter_inappwebview_android/.../InAppWebView.java:555`
  — `checkScrollStoppedTask` 僅於 `ACTION_UP` 執行。返回手勢結束於 `CANCEL` 而非 `UP`，
  故該路徑於本情境不會觸發（相關但非本問題主因，記錄備查）。

### 佐證備註
全套件**無任何** `setSystemGestureExclusionRects` 呼叫（全 repo 搜尋無結果）。

### 新增
- 無（預期為既有檔案的行為修正）。

## Open Questions / 待確認事項

### Q1. 修法方向 — 影響：範圍與副作用

> **原列的三個候選（`flingScroll(0,0)`、`CANCEL` 時還原捲動位置、手勢區特殊處理）全部作廢**
> ——它們建立在「fling 未被取消」的錯誤機制上。既然根本沒有 fling，中止 fling 無事可做。

實測確立的目標改為：**不讓那個合成 `MOVE` 到達 Chromium**。

- [ ] A. **延遲送出異常大的 MOVE**：單一事件位移超過門檻時先扣住不轉交 `super`，並 post 一個
  極短延遲的 runnable；若期間收到 `eventTime` 相同的 `CANCEL` 就丟棄，否則補送。
  只有異常事件被延遲，正常捲動零影響。代價是實作最複雜，且改動 `onTouchEvent` 的控制流。
- [ ] B. **直接丟棄異常大的 MOVE**：不緩衝，位移超過門檻即不轉交。最簡單。
  風險是真實的極快滑動會掉一個事件——但只掉一個中間事件，後續事件仍會帶著正確位置抵達，
  影響可能不可察覺。需 C2 驗證。
- [x] C. **僅在起點落於系統手勢區時丟棄異常 MOVE**：以 `getSystemGestureInsets()` 判定
  `ACTION_DOWN` 是否在邊緣區，是才啟用位移門檻攔截。副作用面最小，因為只影響本來就可能被系統
  接管的手勢；畫面中央的快速滑動完全不受影響。代價是多一層判定，且該區寬度隨裝置與使用者設定變動。

狀態：✅ 已確認

**不依賴 `eventTime` 特徵**，故 A6（確認該特徵的通用性）不是本次的前置條件，降為待辦。

門檻取值依據實測：真實 MOVE 的單事件位移 ≤ 16px（約 6dp），合成 MOVE 為 268–269px（約 98dp），
兩者相差一個數量級以上。取 **48dp** 落在中間，且遠高於任何真實手指在單一事件內能產生的位移。
即使誤判，掉的也只是**一個中間事件**——後續事件仍帶著正確的絕對座標抵達，位置不會累積偏差。

### Q2. 是否需要設定項閘控 — 影響：上游 delta 與相容性
本 repo 的保留鐵則要求 delta 極小、關閉時行為與上游一致。

- [x] A. 無條件修正，不加設定項：這是明確的錯誤行為，沒有使用端會想保留它；
  加設定項等於為一個沒人要的行為保留開關。
- [ ] B. 以新設定項閘控，預設關閉：與上游行為完全一致，但使用端須主動打開才拿得到修正。
- [ ] C. 以新設定項閘控，預設開啟：折衷，保留關閉的逃生口。

狀態：✅ 已確認

**連帶約束**：既然沒有逃生口，C2 的副作用檢查（正常甩動捲動仍須正常）就從「應該做」升為
**發布前的硬性條件**。修法若誤傷慣性捲動，使用端無法自行關掉，只能改回上游——那等於這個計畫白做。

## Key Decisions

- **與軟鍵盤避讓計畫拆開**（來源：Rule 8 分類）。理由：實測證實兩者機制不同——本問題是文件捲動
  且與鍵盤無關，`keyboardAvoidance` 開關不影響它。混在同一計畫會讓驗證無法歸因。
- **不加設定項，無條件修正**（來源：Q2）。理由：這是明確的錯誤行為，沒有使用端會想保留；
  加開關等於為一個沒人要的行為增加 delta。代價是失去逃生口，因此 C2 的副作用檢查升為硬性條件。
- **Q1（修法方向）刻意延後至 Phase A 之後**（來源：本計畫的紀律設計）。理由：本次工作已因憑推理
  猜測成因而誤判三次（內層容器 `scroll` 未捕獲、重複扣除鍵盤高度、`ACTION_CANCEL` 完全未處理），
  三次皆由實測推翻。機制未證實前選修法只會是第四次。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- 現象的原始記錄與擷取數據：`.kn-project/plans/2608111609-webview-keyboard-avoidance/tasks.md`
  的「界外發現」段落
- 上游：`https://github.com/pichillilorenzo/flutter_inappwebview`（`upstream` remote，主幹 `master`）
