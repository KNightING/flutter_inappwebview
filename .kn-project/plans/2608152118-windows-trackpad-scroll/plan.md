<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608152118 - Windows 觸控板捲動失效與不流暢

- Created: 2026-08-15
- Issue: `KNightING/flutter_inappwebview#12`
- Branch: `fix/2608152118-windows-trackpad-scroll`
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

修復 Windows 平台以**觸控板**捲動 WebView 時的兩個症狀（2026-08-15 使用者實測回報）：

1. 往上可捲動，**往下無反應**
2. 即使往上，**也不流暢**

滑鼠滾輪正常，故問題落在觸控板專屬的事件路徑，不是共用的捲動送出邏輯本身。

## Architecture

### 兩條輸入路徑（源碼佐證）

`flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart` 的 `Listener`
有兩個各自獨立的捲動入口：

| 路徑 | 事件 | 送出的值 | 錨點 |
| :--- | :--- | :--- | :--- |
| 滑鼠滾輪 | `onPointerSignal` → `PointerScrollEvent` | `-scrollDelta.dx/dy` | `custom_platform_view.dart:465` |
| 觸控板手勢 | `onPointerPanZoomUpdate` | `panDelta.dx/dy`（不取負） | `custom_platform_view.dart:473` |

> [!IMPORTANT]
> **原本記載「符號不一致是正確的、不得修正」，已於 2026-08-15 被實機量測推翻。**
> 當時的推導假設觸控板是「直接操作」語意（手指往下＝把內容往下拉），故不取負。
> 實測顯示這與 Windows 的實際語意相反，方向就是本題的根因，見下方「缺陷零」。

兩條路徑最後都進到 `in_app_webview.cpp:3820` 的 `setScrollDelta`，再到 `:3800` 的 `sendScroll`：

```cpp
auto offset = static_cast<short>(delta * settings->scrollMultiplier);
webViewCompositionController->SendMouseInput(COREWEBVIEW2_MOUSE_EVENT_KIND_WHEEL,
  virtualKeys_.state(), offset, lastCursorPos_);
```

### 缺陷零：兩軸交錯送出，Chromium 吃掉垂直捲動（**根因，2026-08-15 實驗證實**）

`setScrollDelta` 原本只要 `delta_x != 0.0` 就送一個 `HORIZONTAL_WHEEL`，緊接著再送垂直的。
觸控板幾乎每一幀都帶有微小的水平分量，於是每一幀都變成「水平 wheel 後面跟著垂直 wheel」
交錯送進 Chromium，Chromium 據此把整段序列當成水平捲動，垂直的位移被丟掉。

實測的方向不對稱正是這個機制的副產物：

| 手勢 | `dx` | `dy` | 結果 |
| :--- | :--- | ---: | :--- |
| 手指往下 | **精確 0.000** | +75 ~ +96 | 正常（水平事件根本沒送出） |
| 手指往上 | 3.99 ~ 19.93 | -70 ~ -166 | **完全不動**（每幀都先被水平事件開頭） |

**驗證方式**：暫時以 `if (false && delta_x != 0.0)` 關掉水平送出後重建，使用者實測
「上：正常 下：正常」——單一變因，直接證實。

**修法**：一次只送一個軸，且**每個手勢鎖定一次**（非逐幀）。逐幀判定會讓橫向滑動中
`|dy|` 偶然勝出的那些幀被送到垂直軸，水平位移逐幀漏失，實測表現為「距離偏小」。
軸的判定放在 Dart 端——手勢起訖只有那裡知道——原生端因此維持上游原樣。

### 缺陷零之二：水平方向相反

垂直不取負、水平要取負。兩軸的 wheel 語意本就不一致：垂直 wheel 正值＝畫面往上，
水平 wheel 正值＝畫面往右；而 `panDelta` 兩軸都是「內容跟著手指走」。手指往下（+dy）
要的是畫面往上，剛好是正的垂直 wheel；手指往右（+dx）要的是畫面往左，是**負的**水平 wheel。
兩個方向皆於 2026-08-15 實機驗證。

### 缺陷一：`static_cast<short>` 向零截斷

> **實測修正（2026-08-15）**：原本推測觸控板每幀只有 0.3–3 px、截斷後整幀歸零。
> **量測推翻此推測**——垂直 `dy` 實際為 10–114 px，截斷最多吃掉不到 1 px。
> 截斷因此**不是**主要症狀的成因，缺陷零才是。

截斷仍是真實缺陷，只是影響面小得多：**水平 `dx` 的量級確實在 0.1–8 px**（實測
0.081 / 0.373 / 0.534 / 1.137…），小於 1 的幀會被截成 0，且 `setScrollDelta` 仍會送出一個
offset 為 0 的 `HORIZONTAL_WHEEL`。慢速捲動時的殘量逐幀丟失，是「不流暢」的次要成因。

修法是**殘量累加器**：保留未送出的小數，跨幀累加，只送整數部分。

> **重要修正**：先前需求清單的 R1 寫「`panDelta` 是邏輯像素，`mouseData` 是 WHEEL_DELTA，
> 應乘以 120」。**該結論與「滑鼠滾輪正常」這項實測事實矛盾**：兩條路徑共用同一個
> `sendScroll`，若真的少乘 120，滑鼠也會慢 120 倍。實際情況是滑鼠一格的像素量恰好落在
> 120 附近，1:1 直送因此近似正確。**若照 R1 無條件乘 120，滑鼠會變成 120 倍速**。
> 正確做法是保持現有比例、只補累加器，見 Q1。

### 缺陷二：`lastCursorPos_` 在手勢期間不更新（往下無反應的推定主因）

`lastCursorPos_` 只在 `in_app_webview.cpp:3662` 的 `setCursorPos` 內被寫入，而該方法只由 Dart 端
`onPointerHover` / `onPointerMove` 觸發（`custom_platform_view.dart:388`、`:462`）。
**觸控板 pan 手勢期間不發 hover**，於是 wheel 事件被送到「上一次滑鼠停留處」——若該座標
從未建立過（使用者一進畫面就直接兩指滑動），`lastCursorPos_` 會是預設值，wheel 落在
視窗左上角；若該處是已捲到底的內層容器，就會出現**單向可捲**的症狀。

> [!CAUTION]
> **此推論已於 2026-08-15 被實機量測推翻，本計畫不修它。**
> 探針顯示 `lastCursorPos` 在每一筆 pan 事件上都**等於** `localPosition`（8 個不同座標全部同步）
> ——手勢開始前的 hover 已經把座標設好，手勢期間座標並未過期。依 Q3 的決議，
> 不得為已證偽的推論加入永遠不會生效的程式碼，故 Q2 的修法一併取消。

### 缺陷三：無 `onPointerPanZoomStart/End`

`custom_platform_view.dart` 完全沒有這兩個處理器（已 grep 確認）。缺了它們，累加器沒有
重置點，慣性捲動（fling）結束後的殘量會留到下一次手勢。

### 缺陷四：`short` 溢位不飽和

`scrollMultiplier` 為 `int64_t`（`in_app_webview_settings.h:33`）且**無上限**，
`static_cast<short>` 在超過 ±32767 時會繞回反號。上游 issue #2511 有使用者設 200 的紀錄，
乘上大 delta 即可能踩到。修法是先夾在 `short` 值域內再轉型。

### 與上游的關係

上游不會修：[#2511](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2511)
已 closed as not planned（stale、無根因分析），[#2503](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2503)
是同一問題的另一份回報。本 fork 自行修復，變更以**新增為主**（新增累加器成員與兩個事件處理器），
`sendScroll` 的既有結構盡量不動，以縮小日後同步的衝突面。

**與 Flutter 3.47 升級無關**：該套件的相關程式碼在 `2608151157` 升級中完全未動，上游 issue
也早於 3.47。

## Cross-Repo Scope

無（單一 repo）。

> 使用端 `nuxt-flutter-app` 目前的 `dependency_overrides` 只釘了 android / ios /
> platform_interface 三個套件，**未釘 windows**。本修復要在使用端生效，該 repo 需新增第四個
> `dependency_overrides` 條目並讓四個 `ref` 維持同一個 tag。該調整屬使用端，不在本計畫範圍，
> 於本計畫完成並發 tag 後由使用者處理。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-15 在 `main`（`5316a41ec`）實際確認。

### 既有

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart:473`
  — `onPointerPanZoomUpdate`，需補上手勢期間的游標座標更新；同檔 `:465` 的
  `onPointerSignal` 為滑鼠路徑，作為對照不動。`Listener` 於 `:380` 起始，
  `onPointerPanZoomStart/End` 需新增於此。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp:3800`
  — `sendScroll`，截斷、溢位與累加器皆在此處理；`:3820` 的 `setScrollDelta` 為其唯一呼叫者，
  `:3662` 的 `setCursorPos` 是 `lastCursorPos_` 的唯一寫入點。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.h`
  — 新增累加器成員（`sendScroll` 的宣告所在，需一併加入殘量欄位）。

### 佐證備註

- `scrollMultiplier` 宣告於 `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview_settings.h:33`
  （`int64_t`，預設 1），解析於 `in_app_webview_settings.cpp:42`，Dart 端宣告於
  `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:2373`。
- 本 repo 的 `.kn-project/wiki/` 目前只有 `features/keyboard-avoidance.md`，**無** Windows 捲動
  相關頁面；`archive/` 六份亦無相關計畫。本題為全新領域，無既有決策需承接。

## Open Questions / 待確認事項

### Q1. 觸控板的像素→wheel 換算比例 — 影響：修完的手感
累加器解決「小數被丟掉」，但仍需決定觸控板 1 邏輯像素對應多少 wheel 單位。

- [x] A. **與滑鼠同比例（1:1），只補累加器**（建議）：改動最小，滑鼠路徑完全不受影響，
  觸控板從「多數幀丟失」變成「不丟失」。手感若仍偏慢，使用端可用既有的 `scrollMultiplier` 調整。
- [ ] B. 觸控板另乘一個係數（例如 3）：手感可能更接近原生，但等於在套件內寫死一個經驗值，
  且與 `scrollMultiplier` 的語意重疊，使用端更難推理。
- [ ] C. 照原需求清單乘 120：**不建議**，會讓共用同一條 `sendScroll` 的滑鼠變成 120 倍速。

狀態：✅ 已確認（2026-08-15）

### Q2. 手勢期間的游標座標來源 — 影響：R4 修法
- [x] A. **在 `onPointerPanZoomStart/Update` 呼叫 `_setCursorPos(ev.localPosition)`**（建議）：
  與既有 `onPointerMove` 同一條路徑，改動最小。副作用是會多送 WebView2 的 MOVE 事件。
- [ ] B. 新增一條只更新 `lastCursorPos_`、不送 MOVE 的原生方法：無副作用，但需新增 method channel
  與原生方法，delta 較大。

狀態：✅ 已確認（2026-08-15）

### Q3. 驗證方式 — 影響：完成判準
本修復的判準是實際手感，自動化測試無法涵蓋（觸控板手勢需真實硬體輸入）。

- [x] A. **暫時性 log + 使用者實測**（建議）：Phase A 先掛 log 確認觸控板真的走
  `onPointerPanZoomUpdate`（而非驅動只送 `WM_MOUSEWHEEL` 走 `onPointerSignal`），
  拿到實際 `panDelta` 與 `lastCursorPos_` 後再定案 R4，修完移除 log，由使用者在 example 上實測。
- [ ] B. 直接修完再測：省一輪來回，但若機器的驅動根本不送 pan 手勢，R4 的修改就是無效程式碼，
  且會誤導日後的讀者。

狀態：✅ 已確認（2026-08-15）

## Key Decisions

- ~~**符號不一致維持現狀**~~ → **推翻：觸控板同樣取負**（來源：2026-08-15 實機量測）。
  理由：Windows 觸控板預設語意與滑鼠滾輪一致（手指往下＝頁面往下），實測證實現況為反向，
  且該反向就是「往下無反應」的根因。原決議建立在「直接操作語意」的假設上，該假設與平台不符。
- **不修 `lastCursorPos_`**（來源：Q2 的前提被實測推翻）。理由：探針證實座標全程同步，
  加了也不會生效；依 Q3 的決議不得加入已證偽的死程式碼。
- **推翻原需求清單的 R1（乘 120）**（來源：源碼 + 「滑鼠滾輪正常」的實測事實）。理由：兩條路徑
  共用 `sendScroll`，若真少乘 120，滑鼠也會慢 120 倍；實測滑鼠正常，證明現有比例近似正確。
- **觸控板與滑鼠同比例，只補累加器**（來源：Q1）。理由：滑鼠路徑零風險，觸控板的真正問題是
  丟幀而非倍率；手感不足時使用端已有 `scrollMultiplier` 可調，不需在套件內寫死經驗值。
- **游標座標沿用既有 `_setCursorPos` 路徑**（來源：Q2）。理由：與 `onPointerMove` 同一條路徑，
  改動最小；多送的 MOVE 事件是 WebView2 本就會收到的正常輸入。
- **先量測再定案 R4**（來源：Q3）。理由：Windows 觸控板手勢支援取決於驅動，若驅動只送
  `WM_MOUSEWHEEL`，Q2 的修改會是永遠不執行的程式碼。
- **本修復不含使用端的相依調整**（來源：Cross-Repo Scope）。理由：使用端目前未釘 windows 套件，
  該調整屬使用端且需四個 `ref` 同步發 tag，由使用者於本計畫完成後處理。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- 上游 issue（皆未修）：`https://github.com/pichillilorenzo/flutter_inappwebview/issues/2511`、
  `https://github.com/pichillilorenzo/flutter_inappwebview/issues/2503`
- Flutter 觸控板手勢語意：`https://docs.flutter.dev/release/breaking-changes/trackpad-gestures`

## Deviations（2026-08-15 實測後補記）

原始需求清單（另一 session 的 `windows-trackpad-scroll-requirements.md`）與本計畫規劃階段的
推論，**多數被實機量測推翻**。逐項記錄，避免日後重蹈：

| 假設 | 判定 | 依據 |
| :--- | :--- | :--- |
| R1：`panDelta` 需乘 `WHEEL_DELTA`(120) | 推翻 | 兩路徑共用 `sendScroll`，照做會讓滑鼠 120 倍速；滑鼠實測正常即證明現有比例近似正確 |
| R2：`panDelta` 僅 0.3–3 px，截斷後歸零 | 推翻 | 實測 `dy` 為 10–166 px；截斷最多吃掉 1 px |
| R4：`lastCursorPos_` 手勢期間停滯 | 推翻 | 探針顯示它每一筆都等於 `localPosition`，8 個座標全部同步 |
| 觸控板符號應取負 | 推翻（垂直） | 誤讀使用者回報所致；實機驗證取負會讓垂直反向。水平則確實要取負 |
| 原生端吃掉負值 | 推翻 | 1227 筆 `SendMouseInput` 全部 `S_OK`，`delta=-138.9` 完整轉為 `offset=-139` 送達 |
| **兩軸交錯送出** | **成立** | 關閉水平送出後兩方向皆正常（單一變因實驗） |

**實作與計畫的差異**：

- Q2 決議的「手勢期間更新游標座標」**未實作**——其前提（R4）被推翻，依 Q3 的決議不加
  已證偽的死程式碼。
- 軸判定最終**放在 Dart 端**而非原生端（計畫未預期）。理由：手勢起訖只有 Dart 知道，
  且這讓原生 `setScrollDelta` 維持上游原樣，delta 更小。
- 保留的殘量累加器、溢位飽和、手勢邊界重置**皆非根因**，但都是源碼可證的真實缺陷，
  且軸鎖定切換時累加器讓殘量不會亂跳，故一併保留。

## Follow-up（不在本計畫，另開迭代）

- **慣性與斜滑兩軸**：目前的合成滾輪路徑先天做不到——`SendMouseInput` 一次只能表達一個軸，
  且 Windows 的觸控板慣性事件流並未送達（手指離開後只剩幾幀 <1px 的殘值）。
  正解是改走 `SendPointerInput`（套件已有基礎設施：`InAppWebView::setPointerUpdate`
  與 Dart 端 `_setPointerUpdate`，目前用於觸控螢幕），讓 Chromium 走原生 fling。
  **風險**：頁面收到的會變成 `touchstart/touchmove` 與 `pointerType: touch`，網站可能
  切換為行動版互動（hover 失效等），故應以設定項閘控、預設維持現行 wheel 路徑。
  使用者於 2026-08-15 同意此方向。
- **`nuget` 應補進 `project.md` 的每機清單**：本機的 nuget.exe 位於使用者的 `tools` 目錄，
  但該目錄不在 user 或 machine 的 PATH 上，導致非繼承慣用終端機環境的情境（如 agent session）
  建置直接失敗於 `NUGET-NOTFOUND`。屬環境前置條件，不屬本計畫的程式修復。
