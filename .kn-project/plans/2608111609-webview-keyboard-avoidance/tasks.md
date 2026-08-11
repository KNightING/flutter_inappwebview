# Tasks: WebView 軟鍵盤避讓內建化

> 進 Phase 3 前需先結清 plan.md 的 Open Questions（Q1–Q4）。
> Phase C 的細目待 Q2（避讓執行位置）與 Q4（平台範圍）決議後補齊。

## Phase O — 已知良好基準
- [ ] O1. 動任何程式碼前先建置 `flutter_inappwebview/example`（Android），確認新基底可建置可執行
- [ ] O2. 記錄基準結果；若本來就不可建置，先停下回報，不得在壞掉的基準上開發

## Phase A — 攔截 IME 插邊（證實 Chromium 會停手）
- [ ] A1. 於 `InputAwareWebView` 掛 window insets 監聽，消耗 IME 那一段
- [ ] A2. 實機驗證：手勢返回時 `visualViewport.offsetTop` 是否維持 0（前身計畫實測為 0→57）
- [ ] A3. 確認副作用範圍：文字選取把手、autofill 下拉、`visualViewport` 在 JS 端的回報

## Phase B — 設定項
- [ ] B1. `platform_interface` 的 `in_app_webview_settings.dart` 宣告新設定（含 `.g.dart` 重新產生）
- [ ] B2. `InAppWebViewSettings.java` 解析並套用
- [ ] B3. app-facing 套件透傳確認

## Phase C — 避讓實作
- [ ] C1. 焦點元素位置的注入腳本（放 `plugin_scripts_js/`）
- [ ] C2. 依 Q2 決議實作位移
- [ ] C3. 關閉設定時完全不介入（回到上游原行為）— 這是保留鐵則的硬性要求，非選配

## Phase D — 驗證
- [ ] D1. 套件自帶 example 專案驗證開／關兩種設定
- [ ] D2. 掉幀量測（沿用使用端的 `gfxinfo` 5 輪開關鍵盤腳本）
- [ ] D3. 三條關閉路徑逐一驗證：點空白處、鍵盤收合鈕、邊緣滑動手勢
- [ ] D4. 轉向、以及焦點位於內部捲動容器的情境

## Phase E — delta 檢查（本 repo 特有）
- [ ] E1. `git diff upstream/master` 確認變更範圍未逸出計畫；新增為主、改寫既有邏輯降到最低
- [ ] E2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
