# 2608111609 - webview-keyboard-avoidance

- Created: 2026-08-11 16:09 / Archived: 2026-08-13 01:05
- Issue: N/A（無 issue 追蹤基準——計畫建立時本 repo 的 GitHub Issues 判定為不可用）

## Summary

軟鍵盤彈出時「讓焦點輸入框保持可見」這件事收進套件，使用端零程式碼即可獲得，Android 與 iOS 皆已交付。

Android 走**壓制 + 平移**：攔下 IME window insets 讓 Chromium 收不到鍵盤、不再自行捲動，
再由套件以 `setTranslationY` 平移 PlatformView，成為唯一執行者，消滅前身計畫「兩個執行者打架」
的位移加倍。iOS 走**補齊**：WebKit 的焦點揭露本身正確且無公開 API 可停用，故不壓制，
改為補它缺的兩段——保留鍵盤插邊撐出捲動餘裕（短頁面才捲得動）、鍵盤收起時還原捲動位置。
**兩平台是兩套不同機制，對使用端的承諾相同**，Dart 註解已按平台切分說明。

新增設定項 `keyboardAvoidance`（預設開啟）。使用端仍須自行宣告
`Scaffold.resizeToAvoidBottomInset: false`——那是 Flutter framework 依 engine `viewInsets` 做的
版面計算，與套件攔截的通道各自獨立，套件擋不到。影響 `flutter_inappwebview_android`、
`flutter_inappwebview_ios` 與 `flutter_inappwebview_platform_interface`。

## Cross-Repo Scope

| Repo | 職責 | 相依順序 |
| :--- | :--- | :--- |
| `KNightING/flutter_inappwebview`（本 repo） | 提供避讓能力與設定項；契約提供方 | **先** |
| `sld-digital-lwd/upcc-middle-app` | 換用本套件、移除使用端自建的避讓機制 | 後 |
| `KNightING/nuxt-flutter-app` | iOS 問題的來源與驗證場；交付後可移除其 `useKeyboardAvoidance` | 後 |

兩個使用端的後續皆為**消費方 repo 的獨立計畫**，不在本計畫範圍。
`nuxt-flutter-app` 於本次僅作為量測宿主（臨時 `pubspec_overrides.yaml` 指向本機工作區，
驗畢即刪），**該 repo 無任何被追蹤檔案變更**。

## Key Decisions

- **基底改為本 repo、不改套件名** — 與上游 master 零分歧，平台基準較新，使用端零遷移。
- **變更以新增為主** — 對既有邏輯改寫愈少，上游同步的衝突面愈小。實測最終 delta 為 +2151/−34。
- **避讓由套件內部完成整套**（Q2）— 只暴露鍵盤高度等於把問題推回使用端。
- **`keyboardAvoidance` 預設開啟**（Q3，原決議為關閉後翻轉）— 本 fork 存在的目的就是內建此行為。
- **Android 優先、iOS 未排除**（Q4）— 證據皆來自 Android，iOS 需獨立調查，不得由 Android 結論推導。
- **Goals 第 1 項（`resizeToAvoidBottomInset`）退出範圍** — framework 的 layout 通道，架構上擋不到。
- **Phase B 先於 Phase A 執行** — 讓每一步皆可驗證，不需「暫時把預設值設成 true」的權宜。
- **攔截以 `ViewCompat.setOnApplyWindowInsetsListener` 實作** — 覆寫 `onApplyWindowInsets` 會讓
  「關閉時不安裝監聽」的文件承諾字面上不成立。
- **`keyboardAvoidance` 只能於 `initialSettings` 啟用**（C6）— 注入腳本在 `prepare()` 登記，
  事後補不回來；只套用插邊攔截會消音 Chromium 卻無人接手位移，比不開更糟，故拒絕套用而非做半套。
- **Android 僅支援 API 30+** — IME 插邊自 API 30 才是獨立 inset type，更早版本硬拆等於猜測。
- **iOS 改採公開 API 補齊，不壓制 WebKit**（Q7）— 無公開 API 可停用 WebKit 焦點捲動
  （`isScrollEnabled = false` 亦無效），私有 API 會讓使用端上架被擋；而 WebKit 的揭露本身正確，
  缺陷只在收回時不還原。使用端零介入以「補齊」達成，不需以「壓制」達成。
- **iOS 還原延後一個 runloop 並經兩道閘門**（Q8）— session token（鍵盤是否又出現）與
  `presentedViewController`（畫面上是否有原生浮層）。**first responder 不可用**：實測 blur 後
  與 `<select>` 浮層期間皆為 true，毫無鑑別力，此點同時否證了「以 first responder 判斷」的方案。
- **跳過還原時清除捕捉值** — 確立「一個位置只能被捕捉它的那個鍵盤週期還原」的不變式；
  否則下一個週期會繼承過期錨點（使用者實測指出）。
- **iOS 保留完整實作以達成使用端無腦使用**（Q9）— 一度決議 iOS 收手，釐清「縮減範圍後使用端
  仍須自行處理且處理不了」後改回保留。代價是 iOS 帶約 97 行上游 delta。
- **iOS 驗證宿主為使用端而非 example** — example 的 WebView 是分割版面中的小面板，
  鍵盤與它幾乎不重疊，量不到避讓行為；改以全屏 WebView 的使用端為宿主。

## Deviations

- **A3b（autofill 建議下拉）未驗證即結案**。測試裝置無 autofill 資料，無候選即無下拉；
  依該項自身要求「不得以沒看到問題視為通過」，維持未完成並結轉。
- **D1／C4／D5 由使用者實機驗收，非本流程量測**。使用者於 2026-08-13 表示已自行在 Android 實機
  測試且滿意。本次模擬器複驗僅取得部分訊號（`avoid=ON` 時 `vvOffsetTop` 全程為 0，與 Phase A
  指紋一致），因 example 面板過小、且用的是不建議的 `resize=true` 組態，不足以獨立支撐驗收。
- **D2 掉幀量測只涵蓋 Flutter 層**。hybrid composition 下 WebView 繪製於自己的 surface，
  `gfxinfo` 量不到；「0 掉幀」的正確讀法是「Flutter UI 不再因鍵盤重排而掉幀」。
- **「這個功能是否必要」未收斂**。`keyboardAvoidance` 從未與「使用端零介入、平台獨演」做對照量測，
  兩次嘗試皆因無法產生可比互動而失敗，使用者於 2026-08-12 決定停止投入。
  iOS 這次的漂移重現（204／265px）為該問題提供了第二個平台的實證，但仍非受控量測。
- **界外發現：邊緣返回手勢造成頁面 fling**，經實測確認為上游缺陷、與鍵盤無關，依 Rule 8 另立計畫。

## Impact Files

### Android
- `flutter_inappwebview_android/.../in_app_webview/InputAwareWebView.java:78`
  （`setKeyboardAvoidanceEnabled`）— 以 `ViewCompat.setOnApplyWindowInsetsListener` 消耗 IME 插邊。
- `flutter_inappwebview_android/.../in_app_webview/InAppWebView.java:369`、`:631`、`:1166`
  — 設定套用、注入腳本掛載、`setSettings` 的執行期切換閘控。
- `flutter_inappwebview_android/.../in_app_webview/InAppWebViewSettings.java:136`、`:426`、`:584`
  — 欄位、`parse` case、`toMap`。
- `flutter_inappwebview_android/.../plugin_scripts_js/KeyboardAvoidanceJS.java` (new)
  — 回報焦點元素位置，走專屬 `@JavascriptInterface` 而非 `callHandler`（避開 Dart 往返）。
- `flutter_inappwebview_android/.../KeyboardAvoidanceController.java` (new) — 位移計算與套用。

### iOS
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebView.swift:125`（`keyboardWillShow`）
  — 啟用時保留鍵盤插邊作為捲動餘裕並捕捉 `contentOffset`；關閉時走上游原路徑。
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebView.swift:168`（`keyboardWillHide`）
  — 還原 `contentInset`（不分開關，修上游既有不對稱）並排程捲動位置還原。
- `flutter_inappwebview_ios/.../InAppWebView/InAppWebViewSettings.swift:95` — `keyboardAvoidance` 欄位。

### 跨平台
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1245`
  — `@SupportedPlatforms([AndroidPlatform(), IOSPlatform()])` 與按平台切分的文件註解；
  同目錄 `.g.dart` 為產生檔。

## Details

**iOS 實測數據（2026-08-12～13）**。修正前：鍵盤收起後 document 捲動位置不回原點，
殘留 204px（鍵盤收合鍵）與 265px（`blur()`），兩條路徑皆重現，且在**完全沒有使用端避讓程式碼**
的探針頁上同樣發生。修正後三輪皆歸位（0→559→0）；鍵盤開啟時點 `<select>` 維持 559 不還原、
浮層正確錨定；「開鍵盤→select→再開鍵盤→收鍵盤」序列還原至 559 而非 0。
彈出階段數值與修正前一致（559），確認未干擾 WebKit 的揭露行為。

**量測陷阱（兩則，日後重測必看）**：① 文件必須有捲動餘裕，否則量到的是「WebKit 無法作為」
而非「沒有作為」——本次前兩輪因此得出完全相反的錯誤結論。② 模擬器的 `ConnectHardwareKeyboard`
由 Simulator.app 啟動時讀取，重開裝置無效；另按 iPad 鍵盤右下收合鍵會使鍵盤停在浮動工具列狀態，
之後 focus 不再彈出軟鍵盤，量測會靜默失效。

**Phase A / D 的 Android 實測數據**（`offsetTop` 三格對照、掉幀表、三條關閉路徑、
D4b 的兩個鍵盤高度來源不一致）已隨計畫完成而移入 Wiki 的 keyboard-avoidance 節點。
