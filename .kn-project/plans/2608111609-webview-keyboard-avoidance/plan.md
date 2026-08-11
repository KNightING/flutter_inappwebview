<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608111609 - WebView 軟鍵盤避讓內建化

- Created: 2026-08-11
- Issue: N/A（無 issue 追蹤基準——本 repo 為 fork，GitHub Issues 已停用）
- Branch: `feature/2608111609-webview-keyboard-avoidance`（尚未建立）
- Status: Planning
- Completed: [Wait for Finish]

> 前身為 `KNightING/camelot_inappwebview` 的計畫 `2608111504`，隨基底改為本 repo 而移轉。
> 下方「問題的本質」是該計畫的實測結論，與基底無關，直接沿用未重新調查；
> `## Impact Files` 則已全部改以本 repo 重新取證。

## Goals

把「軟鍵盤彈出時讓焦點輸入框露出」這件事收進套件，使用端（模板／App）不再需要自行處理。

具體要消滅的是使用端目前被迫做的四件事：宣告 `Scaffold.resizeToAvoidBottomInset: false`、
自行平移 WebView widget、以 viewport meta 壓抑瀏覽器行為、以及自建一條 JS→原生的焦點位置回報橋接。

> [!IMPORTANT]
> **2026-08-11 實測修正：第 1 項做不到，必須留給使用端。**
> `Scaffold.resizeToAvoidBottomInset` 是 Flutter framework 依 engine 的 `viewInsets` 做的版面
> 計算，與本計畫攔截的 Android `View` 插邊是**兩條各自獨立的通道**；套件在 PlatformView 底下
> 攔插邊，擋不到上層的 Scaffold。實測見下方「Phase A 實測結果」第 1 格：該項維持預設 `true` 時，
> WebView 仍被縮小（`innerHeight` 766→402）。
>
> 第 3 項（`interactive-widget` meta）依實測**推測不再需要**（第 3 格連 visual viewport 都沒縮，
> 該 meta 要壓抑的行為已不存在），但尚未直接驗證，列為 Phase D 的待驗項。
>
> 因此本計畫實際消滅的是第 2 與第 4 項，並使第 3 項很可能變得多餘。

## Architecture

### 問題的本質（實測結論，非推論）

WebView 內的軟鍵盤避讓有**兩個互相打架的執行者**：

1. **Flutter 層**——`Scaffold` 依 `viewInsets` 縮小 WebView。縮小會讓 WebView 逐幀重排整頁，是掉幀主因。
2. **Chromium 層**——WebView 收到 IME 插邊後自行執行 `ScrollFocusedEditableIntoView`，平移 visual viewport。

使用端關掉第 1 項後，第 2 項仍在，且**它平移的量幾乎正好等於使用端自行平移 widget 的量**
（實測兩組：位移 64.6 → 平移 57；位移 120.6 → 平移 113，固定差 7.6），造成位移加倍後再歸零的抖動。
`interactive-widget=overlays-content` 只擋掉 Chromium 縮 layout viewport，擋不掉這條平移。

Chromium 那段實作在 Android System WebView 內，無法修改；但**它的觸發前提是 WebView 這個 View
收得到 IME 插邊**——那是套件層可以攔截的。

### 方案

在 Android 的 WebView 上攔截 window insets，把 IME 那一段消耗掉，Chromium 即不會自行避讓；
讓位改由套件以已知的鍵盤高度完成，成為單一執行者。

避讓量需要「焦點元素位置」，該資訊只有 DOM 有，故套件需自備一段注入腳本回報，不再由使用端各自搭橋。

新增的跨平台設定沿既有路徑：`platform_interface` 宣告 → `_android` 解析 → app-facing 透傳。

### Phase A 實測結果（2026-08-11，裝置 `M4AIB763K212ZBA`，Android 1080x2400 / density 440）

量測工具為 `kb_probe`（scratchpad 內的獨立 App，不在本 repo）：單一 WebView、輸入框
`position:absolute;bottom:0`、頁面 `200vh`，於 `visualViewport` 的 `resize` / `scroll` 與輸入框的
`focus` / `blur` 回報四個數字。`Scaffold.resizeToAvoidBottomInset` 與 `keyboardAvoidance` 各自可切換。

| `resize` | `avoid` | `offsetTop` | visual `height` | `innerHeight` | 誰在動 |
| :--- | :--- | :--- | ---: | ---: | :--- |
| `true` | `false` | 全程 0 | 750.9 → 394.5 | 766 → 402 | **只有執行者 1**（Flutter 縮 WebView） |
| `false` | `false` | **0 → 346.9**（5 幀） | 750.9 → 418.9 | 766 不變 | **執行者 2 現形**（Chromium 平移） |
| `false` | `true` | 14.9 不變 | 750.9 不變 | 766 不變 | **兩者皆靜默** |

**結論一：攔截有效，核心假設成立。** 第 3 格連一次 `resize` 事件都沒有——不只是不平移，WebView
完全不知道鍵盤存在。`ScrollFocusedEditableIntoView` 確實只在該 View 收得到 IME 插邊時才觸發。

**結論二：兩個執行者不會同時出現，是互斥的。** 第 1 格證明 Flutter 縮 WebView 之後，釘在底部的
輸入框重排後仍可見，Chromium 沒有東西需要捲進視野，執行者 2 因此不觸發。原計畫「兩者互相打架」
的敘述需修正為：**執行者 2 只在使用端關掉執行者 1 之後才登場**。使用端當初正是為了消掉掉幀而
關掉執行者 1，才撞上執行者 2。

**結論三：鍵盤高度不需另外查詢。** 攔截後 visual viewport 不縮，套件唯一且最直接的鍵盤高度來源
就是它自己攔下來的那個 inset 值。Phase C 的注入腳本因此只需回報焦點元素位置，不需回報視窗幾何。

### 與上游 delta 的約束

本 repo 與上游 master 零分歧是刻意維持的資產（見 `.kn-project/project.md` 保留鐵則）。
本計畫的變更應**盡可能集中在新增**：新增設定項、新增注入腳本、在 `InputAwareWebView` 掛一個監聽。
對既有邏輯的改寫愈少，日後上游同步的衝突面愈小。設定關閉時必須完全不介入，回到上游原行為。

## Cross-Repo Scope

| Repo | 職責 | 相依順序 |
| :--- | :--- | :--- |
| `KNightING/flutter_inappwebview`（本 repo） | 提供避讓能力與設定項；契約提供方 | **先**——設定項與行為可被驗證後，使用端才能接 |
| `sld-digital-lwd/upcc-middle-app` | 換用本套件、移除使用端自建的避讓機制 | 後 |

App 端不在本計畫範圍，其計畫歸屬見 Open Questions Q1。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-11 在本 repo 實際確認。

### 既有

- `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InputAwareWebView.java:25`
  — `public class InputAwareWebView extends WebView`。**非 final**，是掛 insets 監聽最自然的位置
  （其子類 `InAppWebView` 為 final，不宜再往下塞）。
- `flutter_inappwebview_android/.../webview/in_app_webview/InAppWebView.java:119`
  — `final public class InAppWebView extends InputAwareWebView implements InAppWebViewInterface`，
  設定套用與注入腳本的掛載點。
- `flutter_inappwebview_android/.../webview/in_app_webview/InAppWebViewSettings.java:28`
  — `public class InAppWebViewSettings implements ISettings<InAppWebViewInterface>`，Android 端設定解析。
- `flutter_inappwebview_android/.../webview/in_app_webview/FlutterWebView.java:31`
  — `public class FlutterWebView implements PlatformWebView`，若避讓需在 PlatformView 層平移則動此處。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart`
  — 跨平台設定宣告處；同目錄的 `in_app_webview_settings.g.dart` 為產生檔，需一併重新產生。

### 新增

- `flutter_inappwebview_android/.../plugin_scripts_js/`（檔名待定）`(new)`
  — 回報焦點元素位置的注入腳本。該目錄現有 `JavaScriptBridgeJS.java`、`InterceptAjaxRequestJS.java`、
  `OnWindowFocusEventJS.java` 等，是套件既有注入腳本的固定位置。

### 佐證備註

本 repo 的 Android 套件中，`onApplyWindowInsets` / `setOnApplyWindowInsetsListener` **僅有一處**：
`flutter_inappwebview_android/.../in_app_browser/InAppBrowserActivity.java:125`，作用對象是 toolbar，
**不是 WebView**。IME 插邊目前是直接穿透到 WebView 的——這是本計畫要填的缺口。

## Open Questions / 待確認事項

### Q1. App 端的計畫歸屬 — 影響：跨 repo 命名對齊
App 端要移除的東西（`_KeyboardShift`、`keyboardFocus` 橋接、`overlays-content`）**只存在於 P8 分支**，
不在 `main`。

- [ ] A. 視為 P8 的迭代四：留在 `fix/2608061146-p8-portrait-ux` 疊加。代價是兩 repo 的計畫 ID
  與分支名不一致，偏離 Rule 19 的共用命名慣例（本計畫已於 Cross-Repo Scope 揭露）。
- [ ] B. 先把 P8 合併進 main 再開新計畫：命名可對齊，但 P8 尚有 5 項未完成任務（D3/D4 實機、
  F17b/F18b、F10），現在歸檔並不適當。

狀態：⏳ 待確認（2026-08-11 使用者決定延後）

**不阻擋本計畫進入 Phase 3。** 本題的作用對象是 `sld-digital-lwd/upcc-middle-app`，
依 `## Cross-Repo Scope` 宣告的相依順序，該 repo 本就排在本 repo 之後——契約提供方先完成
並可被驗證，消費方才開始。待套件端的設定項與行為可驗證後再回頭拍板即可。

### Q2. 避讓的執行位置 — 影響：架構與 API 形狀
攔下 IME 插邊之後，實際的位移由誰做？

- [x] A. 套件內部完成整套：套件自行平移 PlatformView 或內部捲動，使用端零程式碼。
  符合本計畫「使用端不再負責」的目標。
- [ ] B. 套件只攔插邊並把鍵盤高度暴露給使用端，位移仍由使用端做。範圍小，但沒有真正解決
  「使用端要重造」的問題。

狀態：✅ 已確認

### Q3. 新設定項的名稱與預設值 — 影響：使用端 API 與上游 delta
- [x] A. `keyboardAvoidance`，預設**關閉**：本 repo 的保留鐵則要求 delta 極小且行為與上游
  一致；預設開啟等於讓 fork 與上游有隱性行為差異，日後同步時難以察覺。使用端明確打開即可。
- [ ] B. 預設**開啟**：內建行為即為期望行為，使用端不必知道它存在。但與上游行為分歧。

> 註：此題的建議與前身計畫（`camelot_inappwebview` 的 `2608111504`）相反。該計畫建議預設開啟，
> 理由是「使用端不必知道它存在」；在零分歧為資產的新基底下，隱性行為差異的代價變高，故翻轉建議。

狀態：✅ 已確認

### Q4. 平台範圍 — 影響：工作量
- [x] A. **Android 優先**：問題與證據皆來自 Android；iOS 的 WKWebView 行為不同，需另行調查。
- [ ] B. Android + iOS 一起做。

狀態：✅ 已確認

**「優先」不等於「只做」**：使用者的決議是 Android 先行，**iOS 未被排除**。本計畫的 Phase A–E
只涵蓋 Android；iOS 待 Android 端驗證完成後另行評估，且評估前需先實測 WKWebView 在
軟鍵盤彈出時的實際行為（是否也有第二個執行者、`ScrollFocusedEditableIntoView` 有無對應機制），
不得沿用 Android 的結論推導。屆時依 Rule 8 判定為本計畫的 Iteration 或另開新計畫。

## Key Decisions

- **基底改為本 repo、不改套件名**（來源：2026-08-11 實測比對）。理由：本 repo 與上游 master 零分歧，
  平台基準較新（AGP 8.13.1、`compileSdk` 跟隨 SDK、podspec 與 SPM 並存），且維持
  `flutter_inappwebview_*` 讓使用端零遷移。完整比對見 `.kn-project/project.md`。
- **變更以新增為主**（來源：保留鐵則）。理由：對既有邏輯改寫愈少，上游同步的衝突面愈小。
- **避讓由套件內部完成整套**（來源：Q2）。理由：使用端零程式碼才真正消滅「使用端各自重造」，
  只暴露鍵盤高度等於把問題推回去。代價是需在 PlatformView 層或 WebView 內部處理位移，delta 較大。
- **`keyboardAvoidance` 預設關閉**（來源：Q3）。理由：預設開啟會讓 fork 與上游產生隱性行為差異，
  日後拉取上游更新時難以察覺衝突；本 repo 以零分歧為資產，行為一致的優先序高於使用端便利。
  **此決策與前身計畫相反**，因基底的取捨前提改變。
- **Android 優先，iOS 未排除**（來源：Q4）。理由：實測證據皆來自 Android。iOS 需先獨立調查
  WKWebView 的實際行為才能規劃，不得由 Android 結論推導。
- **App 端歸屬延後決定**（來源：Q1，2026-08-11）。理由：依 Cross-Repo Scope 的相依順序，
  消費方本就排在契約提供方之後，不阻擋本 repo 進入 Phase 3。
- **Goals 第 1 項（`resizeToAvoidBottomInset`）退出範圍**（來源：Phase A 實測第 1 格）。
  理由：那是 Flutter framework 讀 engine `viewInsets` 的行為，與套件攔截的 Android View 插邊是
  兩條獨立通道，架構上就擋不到。使用端仍須自行宣告。已同步修正 `keyboardAvoidance` 的 Dart 文件註解。
- **Phase B 先於 Phase A 執行**（來源：2026-08-11 執行判斷）。理由：B4 要求攔截受設定閘控且
  Q3 決議預設關閉；照原順序做，A1 完成到 B4 之間會有一段無條件改變上游行為的狀態，且 A2 的實機
  驗證無從打開開關。改為 B→A 後每一步皆可驗證，且不需要「暫時把預設值設成 true」這種易忘的權宜。
- **攔截以 `ViewCompat.setOnApplyWindowInsetsListener` 實作，而非覆寫 `onApplyWindowInsets`**
  （來源：2026-08-11 實作判斷）。理由：文件承諾「關閉時不安裝監聽」，覆寫的話該承諾字面上不成立。
  監聽器內必須顯式呼叫 `ViewCompat.onApplyWindowInsets` 把改過的插邊交回，否則 WebView 會收到
  「完全沒有插邊」而非「沒有 IME 插邊」，狀態列與導航列的讓位會一起壞掉。
- **僅支援 API 30+**（來源：2026-08-11 實作判斷）。理由：IME 插邊自 API 30 才是獨立的 inset type；
  更早版本它混在 system window insets 內，與導航列無法分離，硬拆等於猜測。低於此版本記錄 warning
  並不介入，不佯裝有效。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- 上游：`https://github.com/pichillilorenzo/flutter_inappwebview`（`upstream` remote，主幹為 `master`）
- 前身計畫（已終止）：`KNightING/camelot_inappwebview` 的
  `.kn-project/plans/2608111504-webview-keyboard-avoidance/plan.md`
- 使用端的實測紀錄：`sld-digital-lwd/upcc-middle-app` 的
  `.kn-project/plans/2608061146-p8-portrait-ux/plan.md`「迭代三」
