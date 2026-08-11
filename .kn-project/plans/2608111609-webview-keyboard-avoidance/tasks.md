# Tasks: WebView 軟鍵盤避讓內建化

> plan.md 的 Q2／Q3／Q4 已確認；Q1 由使用者決定延後，且不阻擋本計畫（作用對象是 App 端 repo）。
> 範圍：**Android 優先**（iOS 未排除，另行評估）；避讓由**套件內部完成整套**；
> 設定項 `keyboardAvoidance` **預設關閉**。

## Phase O — 已知良好基準
- [ ] O1. 動任何程式碼前先建置 `flutter_inappwebview/example`（Android），確認新基底可建置可執行
- [ ] O2. 記錄基準結果；若本來就不可建置，先停下回報，不得在壞掉的基準上開發

## Phase A — 攔截 IME 插邊（證實 Chromium 會停手）
- [ ] A1. 於 `InputAwareWebView` 掛 window insets 監聽，消耗 IME 那一段
- [ ] A2. 實機驗證：手勢返回時 `visualViewport.offsetTop` 是否維持 0（前身計畫實測為 0→57）
- [ ] A3. 確認副作用範圍：文字選取把手、autofill 下拉、`visualViewport` 在 JS 端的回報

## Phase B — 設定項
- [ ] B1. `platform_interface` 的 `in_app_webview_settings.dart` 宣告 `keyboardAvoidance`，
      **預設 `false`**（含 `.g.dart` 重新產生）
- [ ] B2. `InAppWebViewSettings.java` 解析並套用
- [ ] B3. app-facing 套件透傳確認
- [ ] B4. A1 的 insets 攔截改為受此設定閘控——關閉時連監聽都不掛，確保零介入

## Phase C — 避讓實作（套件內部完成整套，Q2=A）
- [ ] C1. 焦點元素位置的注入腳本（放 `plugin_scripts_js/`），回報焦點元素在 viewport 中的位置
- [ ] C2. 依鍵盤高度與 C1 的焦點位置計算位移量
- [ ] C3. 實作位移：於 `FlutterWebView`（PlatformView 層）或 WebView 內部捲動擇一，
      實作前先比較兩者對上游 delta 的影響，取較小者
- [ ] C4. 使用端零程式碼驗證：example 不宣告 `resizeToAvoidBottomInset: false`、
      不自行平移、不改 viewport meta 的情況下即可正常避讓
- [ ] C5. 關閉設定時完全不介入（回到上游原行為）— 保留鐵則的硬性要求，非選配

## Phase D — 驗證
- [ ] D1. 套件自帶 example 專案驗證開／關兩種設定
- [ ] D2. 掉幀量測（沿用使用端的 `gfxinfo` 5 輪開關鍵盤腳本）
- [ ] D3. 三條關閉路徑逐一驗證：點空白處、鍵盤收合鈕、邊緣滑動手勢
- [ ] D4. 轉向、以及焦點位於內部捲動容器的情境

## Phase E — delta 檢查（本 repo 特有）
- [ ] E1. `git diff upstream/master` 確認變更範圍未逸出計畫；新增為主、改寫既有邏輯降到最低
- [ ] E2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
