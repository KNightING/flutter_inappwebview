# Tasks for 2608200109

> Phase 順序依「先確立事實、再動對外 API、最後才動實作」安排。
> Phase 1 的結論會直接決定 Q3 的假設是否成立；若不成立，Phase 3 的範圍會擴大，
> 必須回到 Phase 2 重新請示，不得就地擴張。

## Phase 1 — 確立 Java 端 21 處分支的語義

- [x] 逐一檢視 `InAppWebView.java` 的十處（`:217` / `:445` / `:539` / `:651` / `:1124`
      / `:1712` / `:1746` / `:1755` / `:1766` / `:2236`），判定 HCPP 應走 HC 支或 TLHC 支
- [x] 逐一檢視 `FlutterWebView.java` 的五處（`:67` / `:173` / `:179` / `:185` / `:192`），
      特別是 `:67` 的 `containerView` 傳入與否
- [x] 逐一檢視 `InputAwareWebView.java` 的四處守衛（`:209` / `:230` / `:271` / `:349`）
- [x] 檢視 `InAppWebViewSettings.java` 的 `:135` / `:425` / `:585`
- [x] 產出判定表寫入 `plan.md` 的 `## Key Decisions`；**若有任何一處 HCPP 不與 HC 同側，
      停止並回到 Phase 2 重新請示 Q3**

## Phase 2 — 對外 API（依 Q1 決議）

- [x] `in_app_webview_settings.dart`：新增 `AndroidCompositionMode_? androidCompositionMode`，
      `useHybridComposition` 標 `@Deprecated` 並補 `leaveDeprecatedInToMapMethod: true`
- [x] `in_app_webview_settings.g.dart`：以 build_runner 產生（+46/-2，無其他 `.g.dart` churn）
- [x] 新增 `types/android_composition_mode.dart` 與其產生檔，並加入 `types/main.dart` 的 export
- [x] 優先順序規則已定義並寫入欄位文件（新欄位非 null 時勝出，否則沿用舊布林）；
      **實際套用的邏輯在 Phase 3 的 widget 端**
- [x] 撰寫欄位文件註解：載明 API 34+ / Vulkan 需求、manifest 必須由 app 端啟用、
      以及不可用時的行為（依 Q2 決議）

## Phase 3 — Dart 端模式選擇（依 Q2 決議）

- [x] `in_app_webview.dart`：`_resolveCompositionMode()` 解析新設定，新欄位優先、
      未設時沿用 deprecated 布林，HCPP 不支援時退回 TLHC
- [x] `_createAndroidViewController()` 新增 `PlatformViewsService.initHybridAndroidView` 分支
- [x] `registerWith()` 啟動 `precacheHybridCompositionPlusPlusSupport()` 並快取；
      競態處置為「未解析即視為不支援」，並於函式文件說明理由
- [x] HCPP 模式下對 native 送 `useHybridComposition: true`（於 `settingsMap` 覆寫）
- [x] `flutter analyze` 通過（example 帶 path override，0 errors；`_android` 單獨 analyze
      因從 pub 解析 platform_interface 而無法驗證新 API，屬既有 monorepo 特性）

## Phase 4 — 驗證（依 Q4 決議）

> HCPP 需 API 34+ 且 Vulkan。現有裝置（U2 / API 29、模擬器 / API 32）皆不符合。

- [x] 建立 API 36 模擬器並確認 Vulkan 與 SurfaceControl 可用
      （`isSurfaceControlEnabled=true`，需 `ImpellerBackend=vulkan` 才會選 Vulkan 後端）
- [x] example manifest 加 `EnableHcpp` —— 實測有效（release build 從 launcher 一般啟動即生效）
- [x] 欄位文件的 opt-in 說明已更正為正解：release 用 `EnableHcpp` manifest meta-data，
      開發期用隱藏旗標 `flutter run --enable-hcpp`
- [x] example 的 HCPP 啟用方式已確定：manifest `EnableHcpp`（release）／`flutter run --enable-hcpp`（debug）。
      不需要依賴即將被移除的 Intent extra 手動注入
- [x] HCPP 模式：頁面正常渲染（模擬器截圖確認）
- [x] HCPP 模式：捲動正常（實體 Android 16 平板）
- [x] HCPP 模式：**`keyboardAvoidance` 正常**——實體平板上注音輸入法 composing、候選字列、
      頁面上移讓焦點框保持可見皆正常，Phase 1 對四處守衛的判定得到實機佐證
- [x] HCPP 模式：長按選單與文字選取正常（原生 action mode，即 HC 支）
- [x] HCPP 模式：影片播放正常——內嵌 `<video>`（`test_assets/sample_video.mp4` base64），
      以 `currentTime` 前進為判準（2.72→3.77／秒，`paused=false`），畫面亦正常顯示
- [x] **回歸**：TLHC 與 HC 於實體平板上切換後渲染正常；三種模式影片皆播放
      （HC 5.74→6.78、TLHC 5.85→6.88，皆 `advanced=true`）
- [x] U2（API 29）：`checkIfSupported` 穩定為 `false`，模式降級為 TLHC，無 FATAL、行程存活
- [x] U2 的**視覺**確認：HCPP 被選取但 `support=false`，頁面正常渲染、無白畫面，
      靜默降級為 TLHC。Q2A 的設計目標達成

## Phase 5 — 收尾

- [x] 逐項覆核未超出 `## Impact Files` 所列範圍（7 檔 + example manifest，Java 端零改動）
- [x] 更新 `plan.md` 的 `- Status:` 與 `- Completed:`
- [x] 驗證限制（模擬器 vs 實機、裝置數量、未驗證項）已寫入 `plan.md`
