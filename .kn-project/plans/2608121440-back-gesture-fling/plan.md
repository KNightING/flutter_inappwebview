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

### 推測機制（**待 Phase A 驗證，勿當定論**）

Android 的手勢返回需要觀察一段軌跡才能判定。判定完成前，`ACTION_DOWN` 與數個 `ACTION_MOVE`
已經送進 WebView，Chromium 的速度追蹤器開始累積速度。系統確認手勢後補發 `ACTION_CANCEL`，
但 fling 已經以既有速度啟動，`CANCEL` 並未使其中止。

此為假設。Phase A 必須先取得真實的 `MotionEvent` 序列（含 `CANCEL` 的時間點）與 fling 起始時間，
確認兩者的因果與時序後才進 Phase B。

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
三個候選，皆須 Phase A 驗證機制後才能評估：

- [ ] A. `ACTION_CANCEL` 時以 `WebView.flingScroll(0, 0)` 中止慣性（建議先試）：改動最小。
  風險是誤傷其他合法的 `CANCEL`（多指觸控、父層攔截），可能讓正常的甩動捲動被中斷。
- [ ] B. 於 `ACTION_DOWN` 記錄捲動位置，`CANCEL` 時還原：確定能消除位移。
  但會讓所有 `CANCEL` 都回捲，副作用比 A 大。
- [ ] C. 僅對起點落在系統手勢區內的觸控特殊處理：範圍最小、副作用最低。
  代價是需自行計算手勢區寬度（`WindowInsets.getSystemGestureInsets()`），且該寬度隨裝置與
  使用者設定變動。

狀態：⏳ 待確認（Phase A 之後再決）

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
