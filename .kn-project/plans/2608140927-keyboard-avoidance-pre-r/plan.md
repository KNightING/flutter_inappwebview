<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608140927 - keyboard-avoidance-pre-r
- Created: 2026-08-14
- Branch: feature/2608140927-keyboard-avoidance-pre-r
- Issue: KNightING/flutter_inappwebview#8
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

把 Android 的 `keyboardAvoidance` 支援下探到 **API 29（Android 10）以下**，讓現行卡在
`InputAwareWebView.java:91` 的 API 30 閘不再是「該版本完全沒有避讓者」的分水嶺。

動機來自使用端的實測：`sld-upcc-middle` 的目標機是 POS（`minSdk = 29`，現場機 Urovo U2
為 API 29），在該區間本套件完全不介入，使用端只能讓 `Scaffold.resizeToAvoidBottomInset`
維持 `true`，於是回到「framework 每幀 relayout WebView」的路徑——那正是本功能存在的理由。

**非目標**：不動 iOS（其版本下限來自 WebKit 行為，與本次無關）、不改設定項名稱與預設值、
不觸碰 `KeyboardAvoidanceController` 的位移演算法（它本身無 API 級別相依）。

## Architecture

### 現況：閘擋在哪、為什麼

`InputAwareWebView.setKeyboardAvoidanceEnabled()` 啟用時做兩件事，兩件都依賴
API 30 才有的獨立 `WindowInsetsCompat.Type.ime()`：

| # | 用途 | 目前寫法 | pre-R 的處境 |
|---|---|---|---|
| **(a) 量測** | 取鍵盤高度餵給 `KeyboardAvoidanceController.setKeyboardHeightPx()` | `getRootWindowInsets().getInsets(Type.ime()).bottom`（`InputAwareWebView.java:110`） | `Type.ime()` 回 `Insets.NONE`；真值併在 system window insets，與導航列混在一起 |
| **(b) 壓制** | 把 IME 插邊藏起來，避免 Chromium 自行 `ScrollFocusedEditableIntoView` 與平移疊加 | `setInsets(Type.ime(), Insets.NONE)`（`InputAwareWebView.java:115`） | 無法只歸零 ime 那一段 |

`.kn-project/wiki/features/keyboard-avoidance.md` 的「已知限制」把理由記為「硬拆等於猜測」。

### 新證據：那不是猜測，Flutter 已經在做而且準確

使用端 2026-08-14 於 Urovo U2（API 29）實測：`Scaffold.resizeToAvoidBottomInset: true`
把焦點欄位推到鍵盤上方的位置**完全正確**（含頁面最下方的欄位）。Flutter 的 resize 讀的是
engine 的 `viewInsets.bottom`，而 Flutter 的 Android embedding 在 pre-R 正是以
「system window inset bottom 扣掉導航列」推得該值。

也就是說：**這個推算在本專案的目標裝置上已被證明可用**，只是本套件還沒採用它。
pre-R 的對應寫法為 `systemWindowInsets.bottom − stableInsets.bottom`（後者在鍵盤開啟時
仍回報導航列，故可作為基準），結果夾在 `>= 0`。

### (b) 才是真正的未知數

pre-R 沒有「只歸零 ime」的手段。三條候選，**必須以實機實驗決定，不得先寫死**：

1. **整段消耗底部 system window inset**（連導航列一起）再自行補回——WebView 在使用端本就
   edge-to-edge，導航列插邊對它可能本來就無作用。
2. **不壓制**，賭 Chromium 在「WebView 尺寸從未改變」時不會觸發自己的捲動。使用端的 P8
   實驗曾走這條（搭配 viewport meta `interactive-widget=overlays-content`）並回報有效，
   但那是 Flutter 層的平移，不等同本套件的情境。
3. 若 1、2 皆不成立 → **回報並停下**，維持現行 API 30 閘，把實驗結論寫進 wiki 的已知限制。

### 一併會退化的東西（需接受）

`ViewCompat.setWindowInsetsAnimationCallback` 在 pre-R 由 AndroidX 以相容實作模擬，且該實作
沒有 ime 型別可回報。因此 pre-R 很可能**只拿得到 settled 值、拿不到逐幀進度**，位移會是
「跳一下」而非跟著鍵盤動畫走。這比「完全不避讓」好，但不等同 API 30+ 的體驗，須明確寫進文件。

## Cross-Repo Scope
- **本計畫所屬 repo**: `flutter_inappwebview`（fork，`KNightING/flutter_inappwebview`）
- **共用計畫 ID**: `2608140927-keyboard-avoidance-pre-r`　**共用分支名**: `feature/2608140927-keyboard-avoidance-pre-r`
- **參與 repo 與職責**:
  - `flutter_inappwebview`（本 repo）— 下探 API 下限、更新設定項文件與 wiki。issue: `待建立`
  - `sld-upcc-middle` — **消費方，不在本計畫內**。本次若成功，該 repo 需另開計畫：重釘 fork tag、
    `resizeToAvoidBottomInset` 一律 `false`、移除 `_detectKeyboardResizeFallback`，並評估撤除
    為此 bug 而生的 `data-orientation` / `screen-landscape:` 機制（其計畫為 `2608140010-template-sync-1-1-2`）。
- **執行順序相依**: 本 repo 先完成並發 tag，使用端才能重釘依賴。契約提供方先，消費方後。
- **跨 repo 檔案指涉**: `sld-upcc-middle` 的 `flutter-host/pubspec.yaml`（`dependency_overrides` 釘的 ref）、
  `flutter-host/lib/main.dart`（`_needsFrameworkKeyboardResize`）。

## Impact Files
- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InputAwareWebView.java:91`（`setKeyboardAvoidanceEnabled`）— 移除／下修 API 30 閘，並分岔出 pre-R 的量測與壓制路徑
- 同上 `:101`（`setOnApplyWindowInsetsListener`）— pre-R 分支改以 `systemWindowInsets.bottom − stableInsets.bottom` 取鍵盤高度
- 同上 `:125`（`setWindowInsetsAnimationCallback`）— pre-R 的逐幀能力需實測後決定保留或跳過
- `.../in_app_webview/KeyboardAvoidanceController.java`（`computeShiftPx`）— **預期不改**：位移計算以視窗座標進行，無 API 級別相依。若實測顯示 pre-R 需調整再回填此處
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1236`（`keyboardAvoidance` 的 `Requires Android 11 (API 30) or above`）— 版本敘述需隨實作更新；`.g.dart` 鏡像須以 build_runner 重新產生，不得手改
- `.kn-project/wiki/features/keyboard-avoidance.md`（「已知限制」與「使用端要做的事」的 CAUTION）— 由 Phase 5 的 wikification 依實際結果改寫

## Open Questions / 待確認事項

### Q1. fork delta 成長的取捨 — 影響範圍：`InputAwareWebView.java`
`project.md` 的保留鐵則寫明「delta 要保持極小……任何順手改一下都在花掉這筆資產，需個別評估」。
本次會在該檔加入一條 pre-R 分支（含量測與壓制兩處），使 fork 與上游的差距再擴大。
- [x] A：接受。理由：這正是 fork 存在的目的（把使用端重造的原生行為收進套件），且目標機就在該區間
- [ ] B：不接受，維持 API 30 閘，改由使用端各自處理
- **決議**：A（使用者以「繼續＝都照建議」概括核准）。狀態：✅ 已確認

### Q2. 實驗失敗時的處置 — 影響範圍：整體
若 (b) 的三條候選皆不成立（Chromium 仍與平移疊加，或壓制導致導航列插邊異常）：
- [x] A：停下並回報，把實驗結論寫進 wiki 已知限制，不合併任何實作（理由：半套的壓制比不開更糟——這正是現行程式碼於 `setSettings` 拒絕 `false → true` 的同一個理由）
- [ ] B：仍合併「不壓制」的版本，接受可能的疊加位移
- **決議**：A（使用者以「繼續＝都照建議」概括核准）。狀態：✅ 已確認

### Q3. pre-R 只有 settled 值（位移會跳一下）是否接受 — 影響範圍：pre-R 的體驗
- [x] A：接受，並在文件明列 pre-R 為降級體驗
- [ ] B：拿不到逐幀就不做
- **決議**：A（使用者以「繼續＝都照建議」概括核准）。狀態：✅ 已確認

## Key Decisions
- **[Q1]** 接受 fork delta 因 pre-R 分支而成長 — 理由：把使用端重造的原生行為收進套件正是本 fork 的目的，且目標機（Urovo U2 / API 29）就落在該區間。
- **[Q2]** 實驗若無法壓制 Chromium 即停下回報、不合併 — 理由：半套的壓制比不開更糟，與現行 `setSettings` 拒絕 `false → true` 同一紀律。
- **[Q3]** 接受 pre-R 只有 settled 值的降級（位移會跳一下），並於文件明列 — 理由：仍遠優於「完全不避讓」。
- **[Phase 0]** 目標 repo 判定為 `flutter_inappwebview`（fork）— 理由：閘位於 `InputAwareWebView.java:91`，屬套件層；使用端無法從上層抑制（wiki「使用端要做的事」已載明 resize 與套件走不同通道）。
- **[Phase 0]** 每機設定已確認：`gh repo set-default` 為 `KNightING/flutter_inappwebview`、`upstream` remote 已接上（`project.md` 的 checklist 兩項皆通過，故 `gh pr create` 不會誤射上游）。

## Git Completion Policy
- PR body 必須含 `Closes #${N}`，且**目標 repo 為 `KNightING/flutter_inappwebview`**（本 repo 是 `pichillilorenzo` 的 GitHub fork，`gh` 預設會指向 parent）。
- 經核准的 commit 後，完成前執行 `git rebase main` 與 `git push --force-with-lease --force-if-includes`（會重寫遠端工作分支歷史）。
- 本次若成功，需另發 tag 供使用端重釘（現行使用端釘於 `6.2.0-beta.3.2` = `1fd767b`）。
- PR/archive order: Archive automatically triggered on PR request。

## References
- 使用端的實測與決策脈絡：`sld-upcc-middle` 的 `.kn-project/plans/2608140010-template-sync-1-1-2/plan.md`
- 本 repo 既有歸檔：`.kn-project/archive/2608111609-webview-keyboard-avoidance.md`、`.kn-project/archive/2608132314-keyboard-avoidance-unsupported-os-doc.md`
- 現行文件：`.kn-project/wiki/features/keyboard-avoidance.md`
