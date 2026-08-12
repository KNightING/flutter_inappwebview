<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608111609 - WebView 軟鍵盤避讓內建化

- Created: 2026-08-11
- Issue: N/A（無 issue 追蹤基準——本 repo 為 fork，GitHub Issues 已停用）
- Branch: `feature/2608111609-keyboard-avoidance-ios`（2026-08-12 迭代；原分支
  `feature/2608111609-webview-keyboard-avoidance` 已合併進 `main` 並刪除）
- Status: In Progress
- Completed: [Wait for Finish]

> [!WARNING]
> **2026-08-12：本分支已提前合併進 `main`，但計畫尚未完成，刻意不歸檔。**
>
> 合併原因與本計畫無關——`2608121003-agp-9-upgrade` 需要可建置的 example 作為基準，
> 而該修復（`1c12f440f`）只存在於本分支；使用者於該計畫的 Q1 選擇「先合併再做 AGP」。
>
> **`main` 上因此存在一個預設開啟、但下列驗證尚未執行的功能**：
> - Phase D 全部：掉幀量測、三條關閉路徑（點空白處／收合鈕／邊緣滑動手勢）、轉向、
>   焦點位於內部捲動容器
> - A3b：autofill 建議下拉未驗證（測試裝置無 autofill 資料）
> - C4／C5 尚未執行
>
> A1／A2／A3／A4 與 C1–C3 已實測通過。未完成項目見 `tasks.md`。
> **歸檔須待上述結清，不得因已合併而視為完成。**

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

### Phase A3 副作用檢查結果（2026-08-11，同裝置）

於最高風險狀態（`resize=false` + `avoid=true` + 鍵盤開啟）逐項檢查：

| 項目 | 結果 |
| :--- | :--- |
| `<select>` 原生下拉 | ✅ 置中 modal 完整可見。開啟時系統自動收鍵盤，本就不與鍵盤共存 |
| 游標把手 | ✅ 位置正確 |
| 選取把手 | ✅ 兩端精準貼齊選取範圍 |
| 選字浮動工具列（剪下／複製／全選） | ✅ 與鍵盤共存，向上開啟且完整可見 |
| `visualViewport` JS 回報 | ⚠️ 行為契約改變，見下 |
| autofill 建議下拉 | ❓ 裝置無 autofill 資料，**無法驗證**，非「已通過」 |

**原生彈出層不受影響的原因**：這些浮動視窗由系統的 `ViewRootImpl` 依真實 IME 狀態定位，
不是讀 WebView 這個子 View 收到的插邊——本計畫攔的是後者。兩者是不同的來源，因此互不干擾。

**`visualViewport` 是必然後果，不是缺陷**：攔截後 WebView 全程不知道鍵盤存在，`visualViewport`
的 `height` 與 `offsetTop` 皆不變。任何以「`visualViewport` 縮小」偵測鍵盤的網頁程式碼會**靜默
失效**——不報錯，只是永遠不觸發。已寫入 `keyboardAvoidance` 的 Dart 文件註解。

### iOS 實測結果與根因候選（2026-08-12，iPad iOS 26.6）

迭代來源：使用端 `KNightING/nuxt-flutter-app` 以 tag `6.2.0-beta.3.1` 建置 iOS release 裝上實機，
`Scaffold.resizeToAvoidBottomInset: false`（該使用端已於 2026-08-12 全平台設為 `false`）。實測：

- 鍵盤彈出：焦點輸入框會被推上來，**可見**。
- 鍵盤收回：**輸入框沒有回到原位**，畫面維持位移。

這正是本計畫「未解的架構問題」比較表中 `avoid=false` 那一欄所記的**頁面捲動位置漂移**，
在 iOS 上的具體重現——Android 因原生機制成為唯一執行者而不發生。該欄原本只是「單一意外觀察」，
現在有了第二個平台的重現，其作為本功能存在理由的份量隨之提高。

兩個根因候選，**尚未以量測區辨**：

1. **套件 iOS 端的插邊不對稱**。`InAppWebView.swift:125` 的 `keyboardWillShow` 在
   `scrollView.adjustedContentInset.bottom > 0`（同處註解第 129–130 行指明這正是使用端
   `resizeToAvoidBottomInset: false` 的情境）時，把 `scrollView.contentInset` 設成
   `adjustedContentInset` 的負值；而 `:144` 的 `keyboardWillHide` **只重設
   `_scrollViewContentInsetAdjusted` 旗標，未還原 `contentInset`**。負的 bottom inset
   因此在鍵盤收回後留存。此為上游既有程式碼（修 upstream issue #1947），非本 fork 引入，
   但**只有使用端關掉 Scaffold resize 時才會走到**——而那正是本計畫文件建議的搭配。
2. **使用端網頁層的補捲未還原**。`nuxt-flutter-app` 的 `useKeyboardAvoidance` 以
   `visualViewport` 縮短為觸發、`scrollBy` 往下捲，無鍵盤收回時的還原路徑。

**區辨方法**：鍵盤收回後比對 `window.scrollY` 與彈出前的值。已歸位但畫面仍位移 → 根因 1；
未歸位 → 根因 2。兩者可並存，不互斥。

**iOS 沒有等同 Android 的攔截點**：Android 攔的是 View 層的 IME insets；iOS 的焦點捲動由
WebKit 在 WKWebView 內部完成，套件層沒有公開 API 可停用。因此「把 `keyboardAvoidance`
原樣搬到 iOS」不是移植，是另一套機制——這也是 Q4 當初要求 iOS 必須獨立調查、
不得由 Android 結論推導的原因。

> [!NOTE]
> 本計畫原工作分支 `feature/2608111609-webview-keyboard-avoidance` 已於 2026-08-12 前合併進
> `main` 並刪除（遠端與本地皆不存在），故本次迭代需另切新分支，見核准閘。

### Phase F1/F2 實測結果（2026-08-12，模擬器 iPad (A16) / iOS 26.4）

量測方式：以使用端 `nuxt-flutter-app` 為宿主（`--dart-define=DEV_URL` 指向本機探針頁，
**未修改該 repo 任何檔案**），載入一個**不含 `useKeyboardAvoidance`** 的純 HTML 探針，
回報 `scrollY` / `visualViewport.height` / `offsetTop` / 焦點元素 rect。

> [!IMPORTANT]
> **關鍵混淆因子：文件必須有捲動餘裕，量測才有效。**
> 前兩輪（實機 + 模擬器）的 `docHeight` 皆 ≤ 可視高度，捲動範圍為零，量到「WebKit 沒有把
> 焦點欄位捲進可視區」。該結論**已作廢**——那是「無法作為」而非「沒有作為」。
> 補上 700px 尾部留白（`docHeight` 1721 / 可視 1180，餘裕 541）後結論完全相反。

**F2 結論：iOS 存在第二個執行者，與 Android 同構。** 有餘裕時 WebKit 主動捲動：

| 時點 | scrollY | vvHeight | vvOffsetTop | 焦點元素 top/bottom |
| :--- | ---: | ---: | ---: | ---: |
| 鍵盤彈出前 | 0 | 1180 | 0 | 956 / 1005 |
| 鍵盤彈出後 | **541** | 843 | 337 | 415 / 464（完整可見） |
| 鍵盤收回後 | **204** | 1180 | 0 | 752 / 801（**未回原位**） |

**F1 結論：症狀在沒有使用端補捲的情況下重現。** 收鍵盤後 `scrollY` 停在 204 而非 0，
焦點元素落在 752/801（原始為 956/1005）。這推翻了「根因候選 2（使用端網頁層未還原）」
作為**必要**條件——使用端完全不介入時症狀依然存在。

**第三輪複驗（不同的收鍵盤路徑：頁面按鈕呼叫 `blur()`，非鍵盤收合鍵）**：
`docHeight` 1782、餘裕 602。彈出後 `scrollY` 0→**559**（`vvOffsetTop` 337、焦點元素 397/446 可見）；
收回後 `scrollY` **265**、焦點元素 691/740（原始 956/1005）。**漂移在兩條收鍵盤路徑上皆重現。**

| 輪次 | 收鍵盤方式 | 彈出後 scrollY | 收回後殘留 | `scrollY − vvOffsetTop` |
| :--- | :--- | ---: | ---: | ---: |
| 第二輪 | 鍵盤收合鍵 | 541 | **204** | 204（吻合） |
| 第三輪 | `blur()` | 559 | **265** | 222（**不吻合**，差 43） |

> [!WARNING]
> **「WebKit 只還原 visual viewport 那一段」的結構性推論不成立。** 第二輪的
> `541 = 337 + 204` 精確吻合，第三輪的 `559 − 337 = 222` 與實測殘留 265 差 43px。
> 該等式是巧合而非規律，**不得據以推導修正方案**。
> **穩固的事實只有一項：收鍵盤後 document 捲動位置不會回到原點**（殘留 204 / 265）。

方向仍與根因候選 1（`keyboardWillHide` 未還原 `contentInset`）一致，但**因果未證實**——
證明需在套件端改動後以同一組探針複驗（F7 → F8）。

**尚未取得**：`avoid` 機制介入後的對照組。

**量測環境備忘**：模擬器須以 `ConnectHardwareKeyboard = false` 啟動 **Simulator.app**（重開裝置無效，
該設定由 app 啟動時讀取）；另外**不要按 iPad 鍵盤右下的收合鍵**——它會把鍵盤留在浮動工具列狀態，
之後 focus 不再彈出軟鍵盤，量測會靜默失效。探針改以頁面按鈕 `blur()` 收鍵盤即可避開。

### 與上游 delta 的約束

本 repo 與上游 master 零分歧是刻意維持的資產（見 `.kn-project/project.md` 保留鐵則）。
本計畫的變更應**盡可能集中在新增**：新增設定項、新增注入腳本、在 `InputAwareWebView` 掛一個監聽。
對既有邏輯的改寫愈少，日後上游同步的衝突面愈小。設定關閉時必須完全不介入，回到上游原行為。

## Cross-Repo Scope

| Repo | 職責 | 相依順序 |
| :--- | :--- | :--- |
| `KNightING/flutter_inappwebview`（本 repo） | 提供避讓能力與設定項；契約提供方 | **先**——設定項與行為可被驗證後，使用端才能接 |
| `sld-digital-lwd/upcc-middle-app` | 換用本套件、移除使用端自建的避讓機制 | 後 |
| `KNightING/nuxt-flutter-app` | 使用端（2026-08-12 迭代的問題來源與驗證場）；已釘用 tag `6.2.0-beta.3.1`，`resizeToAvoidBottomInset: false` 全平台 | 後——本 repo 修正後由它重建驗證 |

App 端不在本計畫範圍，其計畫歸屬見 Open Questions Q1。

`nuxt-flutter-app` 於本迭代**不需要程式碼變更**（使用者已決議由套件端對齊 Android）；
它的角色是提供 iOS 實機驗證環境，以及 Q5-A 量測的執行場。

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

### 既有（iOS，2026-08-12 於本 repo 確認）

- `flutter_inappwebview_ios/ios/flutter_inappwebview_ios/Sources/flutter_inappwebview_ios/InAppWebView/InAppWebView.swift:125`
  — `keyboardWillShow`，設定負 `contentInset` 之處（根因候選 1）。
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebView.swift:144`
  — `keyboardWillHide`，只重設旗標未還原 `contentInset`；最小修正的落點。
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebView.swift:380`
  — 兩個 keyboard notification observer 的註冊處（`keyboardWillShowNotification` /
  `keyboardWillHideNotification`）。
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebViewSettings.swift`
  — iOS 端設定解析；`keyboardAvoidance` 若要延伸至 iOS 需在此加入解析。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1227`
  — `@SupportedPlatforms(platforms: [AndroidPlatform()])`，緊接 `:1229` 的 `bool? keyboardAvoidance`。
  延伸至 iOS 必須改此註記並重新產生同目錄的 `.g.dart`。

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
- [ ] A. `keyboardAvoidance`，預設**關閉**：本 repo 的保留鐵則要求 delta 極小且行為與上游
  一致；預設開啟等於讓 fork 與上游有隱性行為差異，日後同步時難以察覺。使用端明確打開即可。
- [x] B. 預設**開啟**：內建行為即為期望行為，使用端不必知道它存在。但與上游行為分歧。

**2026-08-11 決議翻轉為 B**：使用者指定預設開啟。這推翻了原本 A 的決議，也接受了「fork 與上游
有隱性行為差異」這個代價——理由是本 fork 存在的目的就是內建這個行為，預設關閉等於每個使用端
都要重新發現它。

翻轉前的前置條件（已滿足）：必須先讓 A4（`resize=true` + `avoid=true`）通過。該格是預設開啟後
**多數使用端會落在的狀態**（`Scaffold.resizeToAvoidBottomInset` 本身預設就是 `true`），而它當時
是唯一未量測的組合，實測也確實在該格抓到位移過頭的缺陷。若先翻預設再驗證，等於把未驗證的路徑
設為主要路徑。

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

### Q5. iOS 的做法 — 影響：上游 delta 大小與可行性（2026-08-12 迭代）
使用者已決定「對齊 Android」由本 repo 承擔（不改使用端網頁層）。剩下的是**改到哪一層**。

- [ ] A. **先量測區辨根因，再決定改哪一層**（建議，理由：兩個根因都能單獨產生同一症狀，
  改錯層等於白工；量測只需在使用端跑 `pnpm flutter:dev:ios-device` 並在 Safari Web Inspector
  讀三個時點的 `window.scrollY`，成本遠低於任一實作）
- [ ] B. 直接修 `keyboardWillHide` 還原 `contentInset`：delta 極小、純屬既有邏輯的對稱性修復，
  符合保留鐵則。若根因為 2 則無效。
- [x] C. 完整把 `keyboardAvoidance` 延伸到 iOS：需停用 WebKit 內建的焦點捲動，
  套件層無公開 API，可能涉及私有 API 或 swizzling，與保留鐵則（delta 極小）正面衝突。
- [ ] D. 其他（請補充）

- **決議**：**C**（使用者於 2026-08-12 拍板）。附帶要求：**使用端未來不應對此做任何處理**——
  能力完整落在套件層，`nuxt-flutter-app` 的 `useKeyboardAvoidance` 待本 repo 交付後移除
  （消費方 repo，依 Cross-Repo Scope 的相依順序另開計畫，不在本計畫範圍）。
  狀態：✅ 已確認

> [!WARNING]
> **C 與保留鐵則（與上游 delta 極小）正面衝突，此為已知取捨。** 使用者在知悉
> 「可能需要私有 API 或 swizzling」的前提下仍選擇 C。因此 Phase F 的第一步不是實作，
> 而是**可行性調查**：先確認 WKWebView 的內建焦點捲動能否以公開 API 停用。
> 若結論為只能靠私有 API，需回到本節重新請示，不得逕自落地。

### Q6. 本迭代是否納入 `avoid=false` 對照量測 — 影響：「未解的架構問題」能否收斂
「未解的架構問題」記錄本功能從未與「不裝它」比較過，使用者已於 2026-08-12 決定停止投入。
iOS 這次的漂移重現正是該表 `avoid=false` 欄唯一的實證，**但仍非受控量測**。

- [x] A. 不納入，維持停止投入的決議（建議，理由：本迭代的目標是修好 iOS 的可用性，
  架構評估是另一件事，混進來會讓兩者都拖長）
- [ ] B. 納入，順道補齊對照數據

- **決議**：**A**（使用者於 2026-08-12 拍板）。狀態：✅ 已確認

### Q7. F3 閘門的處置 — 影響：iOS 方案形狀（2026-08-12）
F2b 調查結論：**公開 API 無法停用 WebKit 的焦點捲動**。無 `WKWebView` /
`WKWebViewConfiguration` 層級開關；`scrollView.isScrollEnabled = false` 亦擋不住
（React Native issue #20793 即此症狀）。壓制只剩 `WKContentView` 私有方法
（`_zoomToRevealFocusedElement` 等）加 swizzling，使用端送審會被擋。

- [x] A. **公開 API 補齊**：套件 iOS 端管理 `contentInset` + `contentOffset`——鍵盤出現時
  給底部 inset 製造捲動餘裕（短頁面亦可揭露）、記住 `contentOffset`，收回時兩者還原，
  並修掉現有 `keyboardWillHide` 的不對稱。
- [ ] B. 私有 API / swizzling 完整複製 Android 架構。
- [ ] C. 只修 `contentInset` 不對稱，接受短頁面仍被鍵盤蓋住。

- **決議**：**A**（使用者於 2026-08-12 拍板）。狀態：✅ 已確認

> [!NOTE]
> **A 對「對齊 Android」的語意修正**：iOS 保留 WebKit 作為「揭露」的執行者，
> 套件只補它缺的還原與餘裕，因此**不是字面意義的同一套機制**。
> 但使用者的實質要求——**使用端零介入**——完全達成。
> 理由是 F2 實測顯示 iOS 沒有 Android 那個「兩個執行者打架」的可見缺陷：
> WebKit 的揭露本身是正確的，缺的只有收回時的還原。壓制一個運作正常的執行者
> 只為了架構對稱，代價是私有 API 與上架風險，不划算。

### Q8. 還原的觸發條件過寬 — 影響：iOS 實作正確性（2026-08-12，F9 發現）
F9 副作用檢查抓到：鍵盤開啟時點 `<select>`，鍵盤收起觸發還原（`scrollY` 559→0），
原生下拉浮層卻停在捲動前的位置，與元素本體錯開約 450pt。
根因是**還原規則過寬**——在任何 `keyboardWillHide` 都還原，包含「焦點移到另一個非文字元素」。

- [ ] A. 還原改為非動畫（`animated: false`）。最小改動，但**可能只是讓症狀不明顯**，
  未證實浮層的錨定時機在捲動之後。
- [ ] B. 延後一個 runloop 再還原；期間若出現新的 focus 或 `keyboardWillShow` 就取消。
  能同時涵蓋「欄位間切換焦點」與「點 `<select>`」兩種情境，代價是多一段非同步狀態。
- [ ] C. 僅在 WebView 不再是 first responder 時還原。語意最貼近「使用者真的離開輸入」，
  但需確認該時點的 first responder 狀態是否已更新。
- [ ] D. 其他（請補充）

- **決議**：**B**（使用者於 2026-08-12 拍板）。狀態：✅ 已確認（但第二道閘門的實作待重選，見下）

> [!WARNING]
> **B 的第一版實作失敗，且順帶否證了 C。** 實作為兩道閘門：
> (1) session token——鍵盤是否又出現（欄位間切焦點）；(2) `containsFirstResponder`——
> WebView 子樹是否仍持有焦點。**第 (2) 道是錯的**：實測 `blur()` 收鍵盤後，
> WKWebView 內部的 content view **仍然保持 first responder**，該 guard 永遠成立，
> 還原永遠被跳過——F8 原本會過的正常路徑因此回歸（`scrollY` 停在 559 未還原）。
>
> **推論**：first responder 無法區辨「使用者離開輸入」與「焦點移到 `<select>`」，
> 故 Q8 選項 C 亦不可行（同一前提）。第 (1) 道 token 閘門本身沒有問題，予以保留。
>
> **第二版實作（2026-08-13）：第二道閘門改為 `presentedViewController == nil`，兩情境皆通過。**
> 不再賭假設，先以暫時性原生除錯輸出取得事實（比照 D4b 的做法），量到：
>
> | 情境 | `containsFirstResponder` | `presentedViewController` |
> | :--- | :--- | :--- |
> | `blur()` 收鍵盤（該還原） | true | **nil** |
> | 點 `<select>`（不該還原） | true | **`_UIContextMenuActionsOnlyViewController`** |
>
> first responder 兩者皆 true、**毫無鑑別力**（這正是第一版失敗的原因，也同時否證 Q8-C）；
> `presentedViewController` 乾淨分離兩者。除錯輸出已於修正時移除。
>
> **殘留行為（已知且接受）**：使用者從 `<select>` 選完之後不會有鍵盤事件，故該次不會還原，
> 頁面維持在使用者當下互動的位置，直到下一個鍵盤週期。這比把元素從浮層底下抽走更合理。

### Q9. iOS 是否收手 — 影響：功能範圍（2026-08-13）
驗證全數通過後，使用者一度決議「iOS 就不要處理了」，範圍縮到只保留 `contentInset`
不對稱修正。隨即釐清該範圍的後果——**使用端無法移除 `useKeyboardAvoidance`，
且症狀不會解決**（漂移仍在、短頁面仍被蓋住；`useKeyboardAvoidance` 本身補不了這兩者，
它沒有還原路徑，也在無捲動餘裕時失效）——使用者改為「希望使用端能無腦使用」。

- [ ] A. iOS 收手，只保留 `contentInset` 不對稱修正。
- [x] B. **保留完整 iOS 實作**，使用端零介入。

- **決議**：**B**（使用者於 2026-08-13 拍板）。狀態：✅ 已確認
  拆除後又復原，復原版本與通過驗證的版本逐檔一致（Swift +90、設定 +1），並重新編譯確認。

## Key Decisions

- **iOS 保留完整實作以達成「使用端無腦使用」**（來源：Q9，2026-08-13）。理由：縮減範圍後
  使用端仍須自行處理鍵盤、且處理不了（`useKeyboardAvoidance` 無還原路徑、無餘裕時失效），
  等於保留一個治不好的症狀。代價是 iOS 帶約 90 行上游 delta。
  連帶：`nuxt-flutter-app` 的 `useKeyboardAvoidance` 可於本 repo 交付後移除（消費方 repo，另計畫）。
- **iOS 改採公開 API 補齊，不壓制 WebKit**（來源：Q7，2026-08-12）。理由：F2b 證實無公開 API
  可停用 WebKit 焦點捲動，私有 API 會讓使用端上架被擋；而 F2 顯示 WebKit 的揭露本身正確，
  缺陷只在收回時不還原。使用端零介入的目標以「補齊」達成，不需以「壓制」達成。
  代價：iOS 與 Android 是**兩套不同機制**（Android 壓制+平移、iOS 補齊+還原），
  文件必須說清楚，不得讓讀者以為 `keyboardAvoidance` 在兩平台語意相同。
- **基底改為本 repo、不改套件名**（來源：2026-08-11 實測比對）。理由：本 repo 與上游 master 零分歧，
  平台基準較新（AGP 8.13.1、`compileSdk` 跟隨 SDK、podspec 與 SPM 並存），且維持
  `flutter_inappwebview_*` 讓使用端零遷移。完整比對見 `.kn-project/project.md`。
- **變更以新增為主**（來源：保留鐵則）。理由：對既有邏輯改寫愈少，上游同步的衝突面愈小。
- **避讓由套件內部完成整套**（來源：Q2）。理由：使用端零程式碼才真正消滅「使用端各自重造」，
  只暴露鍵盤高度等於把問題推回去。代價是需在 PlatformView 層或 WebView 內部處理位移，delta 較大。
- ~~**`keyboardAvoidance` 預設關閉**（來源：Q3）~~ → **翻轉為預設開啟**（來源：使用者於
  2026-08-11 指定）。理由：本 fork 存在的目的就是內建這個行為，預設關閉等於每個使用端都要重新
  發現它。接受「與上游有隱性行為差異」的代價。前置條件為 A4 先通過——該格是預設開啟後多數使用端
  會落在的狀態，且實測在該格抓到位移過頭的缺陷（焦點座標於 Scaffold 縮放後過期），已修正。
- **API 30 以下改記 `Log.d` 而非 `Log.w`**（來源：預設開啟的連帶影響）。理由：選項既然預設開啟，
  舊裝置上會為每個 WebView 印出使用端沒要求、也無從處置的警告，那是純噪音。
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
- **`keyboardAvoidance` 只能於 `initialSettings` 啟用**（來源：C6，使用者於 2026-08-11 拍板）。
  理由：注入腳本在 `prepare()` 時登記，重載只重新注入 controller 內已登記者，事後補不回來；
  只套用插邊攔截會消音 Chromium 卻無人接手位移，比不開更糟，故**拒絕套用而非做半套**。
  未採「啟用當下補注入」是因為 `addJavascriptInterface` 仍需重載，回報路徑得改走 JS bridge，
  會讓所有情境退回 Dart 往返——代價由主要路徑承擔，只為服務邊緣案例。停用則不受限，隨時可生效。
- **iOS 對齊 Android，能力完整落在套件層**（來源：Q5，2026-08-12）。理由：使用者要求使用端
  未來不對鍵盤避讓做任何處理，讓「使用端零程式碼」在 iOS 上與 Android 一致。代價是明知
  可能需要私有 API 仍選擇此路，與保留鐵則衝突——故 Phase F 以可行性調查開場，
  結論若為「只能靠私有 API」須回頭重新請示。
- **不納入 `avoid=false` 對照量測**（來源：Q6，2026-08-12）。理由：本迭代目標是修好 iOS 可用性；
  架構評估（本功能是否必要）維持 2026-08-12 的停止投入決議，混入會讓兩者都拖長。
  iOS 的漂移重現已補記於「未解的架構問題」，日後重啟評估時可用。
- **iOS 的根因區辨降為輔助資訊**（來源：Q5 決議 C 的連帶影響）。理由：既然由套件成為唯一
  執行者，兩個候選根因都會被機制本身消除（比照 Android：WebView 不再得知鍵盤，
  `visualViewport` 不再變動，使用端的補捲自動失效）。仍保留量測作為修正前後的對照基準。
- **iOS 基準走模擬器，實機驗證交給使用端**（來源：F0 執行判斷，2026-08-12）。理由：example 的
  `DEVELOPMENT_TEAM` 是上游作者的 `PFP8UV45Y6`，改成自有 team 等於為了跑基準去製造上游 delta。
  模擬器足以驗證「可建置可執行」；需要真實軟鍵盤的驗證（F8）由已簽章的 `nuxt-flutter-app` 承擔。
- **example 建置的附帶檔案改寫一律還原**（來源：F0 執行判斷，2026-08-12）。理由：本機 Flutter
  與 CocoaPods 版本會自動改寫 `AppFrameworkInfo.plist` 與 `project.pbxproj`（共 21 行刪除），
  那是工具鏈差異不是本計畫的工作，納入 commit 會污染上游 delta 的可讀性。
- **實作驗證的宿主為套件 example，不動使用端 repo**（來源：使用者於 2026-08-12 選 B）。
  理由：讓 iPad 跑到**本機 fork 的程式碼**，只有兩條路——改使用端 `nuxt-flutter-app` 的
  `dependency_overrides` 指向本機 path（那是另一個 repo 的變更，且該 repo 未把
  `pubspec_overrides.yaml` 列入 `.gitignore`，有誤 commit 風險），或改用 example
  （本就以 path 依賴本機套件，改動即時生效）。使用者選後者。
  簽章以 **xcodebuild 命令列覆寫**達成（`DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER`
  作為建置設定傳入 + `-allowProvisioningUpdates`），**不編輯 `project.pbxproj`**，
  故上游 delta 仍為零——此為對「B 會動到上游檔案」的修正。
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

## 未解的架構問題 — 這個功能是否必要（2026-08-12）

**`keyboardAvoidance` 從未與「使用端零介入、Chromium 獨演」比較過。**

前身計畫的問題是**兩個執行者打架**：使用端自行平移 widget，Chromium 也平移 visual viewport。
本計畫的解法是消掉 Chromium，讓套件成為唯一執行者。但**消掉使用端那個也能達到單一執行者**——
Chromium 的 `ScrollFocusedEditableIntoView` 本就是為了讓焦點欄位可見而存在，單獨運作未必有問題。

本計畫所有量測皆在 `avoid=true` 之下進行（D2 比的是 `resize` 的差異），
**沒有任何一組是 `avoid=false` + 使用端不自行平移**。因此沒有證據顯示本功能優於「不裝它」。

### 已知的差異（各有代價）

| 面向 | `avoid=true`（套件平移） | `avoid=false`（Chromium 平移） |
| :--- | :--- | :--- |
| `visualViewport` | **不再回報鍵盤**，靠它偵測的網頁程式碼靜默失效 | 正常回報 |
| 頁面捲動位置 | 不受影響 | **反覆開關鍵盤會漂移**（實測觀察） |
| layout viewport | 不動，整個 WebView 平移 | 不動，只有 visual viewport 平移 |
| `position:fixed` 元素 | 隨 WebView 一起移動 | 停留在 layout viewport |
| 掉幀 | 未與對方比較過 | 未比較 |

唯一實質差異是**頁面捲動位置漂移**——對表單頁面是真實困擾，可能足以支撐本功能存在，
但那是單一意外觀察，非量測結果。

### 為何未完成量測

兩種產生「可比互動」的方法都失敗：

- **固定座標點擊**：`avoid=false` 時頁面捲動漂移，點擊落空。實測兩組互動次數為 10 vs 4，
  數字不可比（曾得到 0.38% vs 4.74%，**已作廢，不得引用**）。
- **JS `element.focus()`**：Android WebView 上不會叫出輸入法（需真實使用者手勢），
  5 輪跑完 `focusin` 為 0、僅渲染 47 幀，等於未測。

可行方向是每輪先以 JS 查出欄位當下螢幕座標再據此點擊，但需改造探針且每輪需來回一次。
使用者於 2026-08-12 決定**停止投入**，將問題記錄保留。

### 若日後要重啟評估

這是**架構問題，不是缺陷**——功能目前運作正常、無已知缺陷。若結論為「兩者相當」，
拿掉本功能可同時消除：`visualViewport` 契約退步、C6 的執行期啟用缺口、以及約 300 行的上游 delta。
