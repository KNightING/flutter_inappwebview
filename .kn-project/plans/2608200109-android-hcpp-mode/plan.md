# Plan: 2608200109 - android-hcpp-mode

- Created: 2026-08-20
- Branch: `feature/2608200109-android-hcpp-mode`
- Issue: KNightING/flutter_inappwebview#20
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

讓使用端能選用 Android 的 **Hybrid Composition++（HCPP）** 合成模式。HCPP 讓 platform view
與 Flutter 各自繪到原生 Surface、交由 SurfaceFlinger 合成，**同時取得 HC 的原生保真度與
TLHC 的效能**（不需要合併 raster 與 platform 執行緒）。

**本計畫不改動任何預設值。** HCPP 為第三種可選模式，預設不啟用——它需要 API 34+、Vulkan，
且必須由 app 端在 manifest 啟用，套件單方面決定不了。

| 面向 | 現況 | 目標 |
| :--- | :--- | :--- |
| 可選模式 | TLHC（預設）、HC | TLHC（預設）、HC、**HCPP** |
| 設定型別 | `bool? useHybridComposition` | 見 Q1（三值列舉或並存的新欄位） |
| 預設行為 | TLHC | **不變** |

## Architecture

### 現況

`AndroidInAppWebViewWidget.build()` 以 `PlatformViewLink` + `AndroidViewSurface` 建構平台視圖，
`_createAndroidViewController()` 依 `useHybridComposition` 二選一：

```
useHybridComposition == true  → PlatformViewsService.initExpensiveAndroidView  (HC)
useHybridComposition == false → PlatformViewsService.initSurfaceAndroidView    (TLHC，不支援時退回 HC)
```

### 目標

新增第三條 `PlatformViewsService.initHybridAndroidView`（HCPP）。**Flutter 端的 widget 結構
完全不變**——已於 Flutter 3.47 原始碼確認 `_HybridAndroidViewControllerInternals`（HC）與
`_Hybrid2AndroidViewControllerInternals`（HCPP）結構相同：兩者 `requiresViewComposition` 皆為
`true`，`setSize` / `setOffset` / `textureId` 皆拋 `UnimplementedError`。現有的
`PlatformViewLink` + `AndroidViewSurface` 對兩者一體適用。

### 已確認的前提（來自 Flutter 3.47 原始碼與 embedding jar bytecode）

- **view factory 註冊不需改動**：`FlutterEngine` 建構時執行
  `platformViewsController2.setRegistry(platformViewsController.getRegistry())`，兩個 controller
  共用同一個 registry，現有的 `binding.getPlatformViewRegistry().registerViewFactory(...)`
  已同時涵蓋 HCPP。
- **HCPP 走另一條 channel** `platform_views_2`，由 `PlatformViewsController2` 處理。
- **啟用權在 app**：manifest `io.flutter.embedding.android.EnableHcpp=true`（或本機測試用
  `flutter run --enable-hcpp`）。引擎端 `isHcppEnabled()` 實際呼叫
  `FlutterJNI.IsSurfaceControlEnabled()`。
- **執行期檢查存在但為非同步**：`HybridAndroidViewController.checkIfSupported()` 回傳
  `Future<bool>`，而 `_createAndroidViewController()` 是在 `onCreatePlatformView` 內同步呼叫，
  無法先查再選（見 Q2）。

### 本計畫最大的實作面：Java 端的布林語義

`useHybridComposition` 這個布林值在 Java 端被分支判斷 **21 處**（見 `## Impact Files`）。
逐一檢視後，這些分支問的其實是同一件事：**WebView 是否位於真實 view 階層中、是否有
`containerView`**。例如 `InputAwareWebView` 的四處守衛在 `true` 時一律略過 IME 代理
workaround 直接交給 `super`——那個 workaround 是為「view 不在真實階層」而存在的。

**HCPP 在真實 view 階層中，與 HC 同側。** 若此判斷對全部 21 處成立，Java 端可以完全不動：
Dart 在 HCPP 模式下對 native 送 `useHybridComposition: true` 即可。這是本計畫要逐點驗證的
核心假設（見 Q3）。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-20 在 `main`（`3c3724650`）上以 Grep 確認。

### A. Dart 端模式選擇

- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart:325`
  — `useHybridComposition` 的解析處（`initialSettings` / 舊 `initialOptions` 二擇一）。
- `.../in_app_webview.dart:384` — `_createAndroidViewController()`，新增第三條分支處。
- `.../in_app_webview.dart:392` / `:400` — 現有的 `initExpensiveAndroidView` 與
  `initSurfaceAndroidView` 兩條。

### B. 設定型別

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1177`
  — `bool? useHybridComposition` 宣告處。
- `.../in_app_webview_settings.dart:3449` — 建構子預設值 `false`。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.g.dart:1890`
  / `:2182` / `:2770` / `:3076` — 產生檔的對應宣告、預設值、`fromMap`、`toMap`。

### C. Java 端消費點（21 處，需逐點判定 HCPP 走哪一支）

- `.../webview/in_app_webview/InAppWebViewSettings.java:135` — 欄位宣告與預設。
- `.../InAppWebViewSettings.java:425` / `:585` — `fromMap` 與 `toMap`。
- `.../in_app_webview/InAppWebView.java:217` — 傳入 `InputAwareWebView` 建構子。
- `.../InAppWebView.java:445` / `:539` / `:651` / `:1124` / `:1712` / `:1746` / `:1755`
  / `:1766` / `:2236` — 其餘九處分支。
- `.../in_app_webview/FlutterWebView.java:67` — 決定是否傳入 `plugin.flutterView` 作為
  `containerView`（**語義最明確的一處：HC 時為 null**）。
- `.../FlutterWebView.java:173` / `:179` / `:185` / `:192` — 生命週期四處。
- `.../in_app_webview/InputAwareWebView.java:40` / `:44` / `:47` — 欄位與建構子。
- `.../InputAwareWebView.java:209` / `:230` / `:271` / `:349` — IME 代理 workaround 的四處守衛
  （`dispose` / `checkInputConnectionProxy` / `clearFocus` / `onFocusChanged`）。

### B-2. 執行中補列（2026-08-20）

- `flutter_inappwebview_platform_interface/lib/src/types/main.dart:9`
  — types 的匯出入口。新型別必須在此 `export` 才對外可見，規劃時漏列。
- `flutter_inappwebview_platform_interface/lib/src/types/android_composition_mode.dart` (new)
  — 新列舉的來源宣告（`AndroidCompositionMode_`）。
- `flutter_inappwebview_platform_interface/lib/src/types/android_composition_mode.g.dart` (new)
  — 由 build_runner 產生。

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:3482`
  — 建構子參數列。產生器由此推導 `InAppWebViewSettings({...})` 的具名參數，未加入則新欄位
  對使用端不可用（實測：`undefined_named_parameter`）。規劃時漏列。
- `flutter_inappwebview_android/lib/src/inappwebview_platform.dart:23`
  — `registerWith()`，HCPP 支援度探測的啟動點。規劃時漏列。

### D. 文件

- `.kn-project/wiki/features/android-platform-view-composition.md`
  — 現有節點已載明「HCPP 尚未支援」，本計畫完成後由 Phase 5 的 wikification 改寫。

### 新增

- 視 Q1 決議可能新增一個列舉型別檔（位置待定，若採 A 案）。

## Open Questions / 待確認事項

> 全部釐清前不得進入 Phase 3。

### Q1. 對外 API 如何表達三種模式？ — 影響範圍：`platform_interface` + `_android` dart + java ✅ 已確認

`useHybridComposition` 是 `bool?`，裝不下三種模式。這是對外 API 的破壞性程度問題。

- [x] **A. 新增 `androidCompositionMode` 列舉，`useHybridComposition` 標記為 deprecated 但保留**
      (建議，理由：對外零破壞，既有使用端與上游遷移者不受影響；新欄位語義清楚，未來要再加
      模式也不必再改型別。代價是兩個欄位需定義優先順序與一致性規則。)
- [ ] **B. 直接把 `useHybridComposition` 改成三值列舉** — 最乾淨，但**破壞既有 API**，
      且與上游分歧從「預設值不同」擴大為「型別不同」，遷移成本高。
- [ ] **C. 新增獨立的 `useHybridCompositionPlusPlus` 布林** — 改動最小，但兩個布林可以同時為
      `true`，是個註定要寫「若同時設定則以…為準」的組合。

### Q2. HCPP 不可用時如何處置？ — 影響範圍：`_android` dart ✅ 已確認

`checkIfSupported()` 是 async，`_createAndroidViewController()` 是同步；且 `initHybridAndroidView`
在 HCPP 未啟用時是否安全降級**尚未確認**（controller 層的 `textureId` 直接拋例外）。

- [x] **A. 在 plugin 初始化時查一次並快取，建立 controller 時讀快取決定實際模式**
      (建議，理由：使用端只需宣告意圖，不可用時自動退回 TLHC，行為可預測。代價是需處理
      「查詢尚未完成就要建立 view」的競態。)
- [ ] **B. 完全交給使用端**：設了 HCPP 就直接呼叫 `initHybridAndroidView`，不可用時的行為
      由 Flutter 引擎決定。實作最單純，但若引擎不安全降級，會是白畫面等級的失敗。
- [ ] **C. 先做 B，另提供一個公開的 `isHcppSupported()` 讓使用端自行判斷後再決定設定值。**

### Q3. Java 端的 21 處分支如何處理？ — 影響範圍：`_android` java ✅ 已確認

假設是「這些分支問的都是『是否在真實 view 階層』，HCPP 與 HC 同側」。

- [x] **A. 維持 Java 端布林不變，Dart 在 HCPP 模式下送 `useHybridComposition: true`**
      (建議，理由：Java 端零改動，delta 最小，且該布林的實際語義本就是二元的。
      前提是逐點驗證假設成立——本計畫會把這 21 處逐一列出判定結果。)
- [ ] **B. Java 端也改成三值**，每一處分支各自判定 — 語義最精確，但 delta 大上一個量級，
      且多數分支的處理方式會與 HC 完全相同。
- [ ] **C. 保留布林但改名**（例如 `viewInRealHierarchy`）以反映真實語義 — 語義清楚，
      但那是跨 Dart/Java 的欄位改名，與上游分歧再擴大。

### Q4. 驗證裝置怎麼解決？ — 影響範圍：驗收 ✅ 已確認

HCPP 需 **API 34+ 且 Vulkan**。目前可用裝置：Urovo U2（API 29）、Android 模擬器（API 32）、
iPad（無關）。**兩者皆不符合，現階段無法驗證任何 HCPP 實際行為。**

- [x] **A. 建立 API 34+ 模擬器並確認其 Vulkan 支援，以模擬器驗證**
      (建議，理由：唯一不需採購硬體的路徑。風險是模擬器的 Vulkan/SurfaceControl 行為
      未必等同實機，需在驗收紀錄中明確標註此限制。)
- [ ] **B. 實作完成但驗證延後**，於 `tasks.md` 明列為未驗證項，待日後有合適實機再補。
- [ ] **C. 暫緩本計畫**，等取得 API 34+ 實機再開始。

### Q5. 是否同時處理 `InAppBrowser` 與 headless 路徑？ — 影響範圍：`_android` ✅ 已確認

`_createAndroidViewController()` 只服務 `InAppWebView` widget。`InAppBrowser` 與
`HeadlessInAppWebView` 不經過 platform view，合成模式對它們無意義。

- [x] **是**：一併檢視並在文件標明不適用　(建議，理由：僅需一句文件說明，避免使用端誤解。)
- [ ] **否**：不處理

## Key Decisions

- **[Phase 4 實測]** 影片播放於 HCPP / HC / TLHC 三種模式**皆正常**——判準取
  `video.currentTime` 是否前進，而非目視單一幀（靜止幀與黑框都可能誤判為正常）。
  三種模式的 `currentTime` 皆在一秒內前進約 1.03 秒且 `paused=false`。
  探針影片沿用 repo 既有的 `test_assets/sample_video.mp4` 以 base64 內嵌，不依賴網路。

- **[Phase 4 實測，重要限制]** **不可為了 HCPP 而在 app 層強制 `ImpellerBackend=vulkan`。**
  該設定讓 API 36 模擬器得以走 Vulkan，但在 Urovo U2（Android 10）上造成啟動即崩潰：
  `FATAL: Check failed: android_context_->IsValid(). Could not create surface from invalid
  Android context.` 舊 GPU 給不出有效的 Vulkan context。已從 example manifest 移除。
  文件不得建議使用端這樣做——Vulkan 後端的選擇應交給引擎自行判斷。
- **[Phase 4 實測]** HCPP 於**實體 Android 16 平板**（model 25097RP43G）驗證通過：
  渲染、`keyboardAvoidance` + 注音輸入法 composing、長按選單與文字選取（原生 action mode）、
  以及 HC / TLHC 兩種既有模式的回歸皆正常。該裝置**不需要**強制 Vulkan，引擎自行選用。
  這比模擬器更有說服力，Q4 的模擬器限制因此不再是主要驗證依據。
- **[Phase 4 修正判讀]** 曾一度觀察到「HCPP 下畫面空白」，實為**捲動捲過頁面內容**
  （探針頁面底部有 120vh 空白）所致。乾淨啟動下 HCPP 渲染正常，該判讀已推翻。

- **[Phase 4 實測，推翻文件]** HCPP 的 opt-in **不是** `io.flutter.embedding.android.EnableHcpp`
  manifest meta-data——Flutter 3.47 的 embedding jar 完全沒有該字串，`flutter run` 也沒有
  `--enable-hcpp` 旗標。真正的開關是引擎 switch **`enable-hcpp-and-surface-control`**
  （字串出現在 `libflutter.so`，且由 `FlutterShellArgs.fromIntent()` 讀取）。
  官方文件那頁在此版本已過時。**已提交的欄位文件註解據此描述，必須修正。**
  另註：Flutter 已警告「經由 Intent extra 設定引擎旗標」即將移除
  （flutter/flutter#180686），長期的正確設法待查。
- **[Phase 4 實測，發現並修正實作 bug]** 在 `registerWith()` 呼叫 `checkIfSupported()`
  會得到 `false`，即使裝置完全支援——實測 API 36 模擬器：`registerWith` 時為 `false`，
  同一支 app 在 `initState` 問則為 `true`。原實作把該 `false` 永久快取，等於讓 HCPP
  整個 session 失效。**修法：只快取正面結果**，負面結果允許之後重問，並在 widget `build()`
  順手重探一次讓後續 WebView 自癒。此為 Q2A「查一次並快取」的必要修正。
- **[Phase 4 實測]** API 36 模擬器（Apple Silicon）**可以跑 HCPP**，但需要
  `ImpellerBackend=vulkan`——預設會選 OpenGLES 後端，而 HCPP 要求 Vulkan。
  Q4A 的假設成立，但成立條件比預期嚴格。

- **[執行中]** 新設定欄位必須**同時**加到來源建構子的參數列——
  理由：產生器由來源建構子推導具名參數。只宣告欄位不加參數，`InAppWebViewSettings(...)`
  就用不到它（實測 `undefined_named_parameter`），且同樣不會在產生時報錯。
- **[執行中]** HCPP 支援度探測掛在 `AndroidInAppWebViewPlatform.registerWith()`——
  理由：那是本套件最早執行 Dart 的時點，而 platform view 工廠是同步的、無法 await。
  探測未完成時一律視為不支援並退回 TLHC：退回只損失效能，猜錯方向則是空白 WebView。
- **[執行中]** `_android` 套件無法單獨 `flutter analyze` 驗證新 API——
  理由：它從 pub 解析 `platform_interface`，看不到本地新增的型別；只有帶
  `dependency_overrides` 的 example 能驗證完整相依圖。這是既有的 monorepo 特性，非本次引入。

- **[執行中]** 本計畫**重跑 build_runner** 產生 `.g.dart`，而非沿用前一計畫的手改作法——
  理由：新增型別的產生檔有上百行，手寫易錯。已實測確認產生器只動相關檔案
  （`in_app_webview_settings.g.dart` +46/-2、新增 `android_composition_mode.g.dart`），
  **未對其他 `.g.dart` 造成 churn**，前一計畫擔心的風險在此情境不成立。
- **[執行中]** 設定欄位型別必須寫**帶底線的來源類別** `AndroidCompositionMode_`，
  不是產生後的 `AndroidCompositionMode`——理由：這是本 repo 既有慣例
  （`MixedContentMode_? mixedContentMode`）。寫成產生後的名字會讓產生器輸出
  `InvalidType`，且不會報錯，是靜默失敗。
- **[執行中]** `useHybridComposition` 加上 `@Deprecated` 之後，**必須同時加上**
  `@ExchangeableObjectProperty(leaveDeprecatedInToMapMethod: true)`——
  理由：實測發現只加 `@Deprecated` 會讓產生器把該欄位從 `toMap()` 移除，deprecated 設定
  將靜默停止送達 native，是回歸而非棄用。既有的 `forceDark` 即採此組合。
- **[執行中]** 新列舉必須加入 `lib/src/types/main.dart` 的 `export`——
  理由：該檔是 types 的匯出入口，未 export 則使用端取用不到。規劃時漏列該檔。

- **[Phase 1 判定表]** 21 處分支逐點檢視完成，**全部與 HC 同側，Q3 的假設成立**——
  Java 端因此可維持布林不變。判定依據與結果：

  | 位置 | 分支內容 | HCPP 應走 | 依據 |
  | :--- | :--- | :--- | :--- |
  | `FlutterWebView.java:67` | `useHybridComposition ? null : plugin.flutterView` 作為 containerView | **HC 側**（null） | HCPP 在真實 view 階層，不需要 containerView 代理 |
  | `FlutterWebView.java:173` / `:179` | `onInputConnectionLocked/Unlocked` 僅在非 hybrid 時鎖定 | **HC 側**（略過） | 該鎖定服務於 texture/virtual-display 模式 |
  | `FlutterWebView.java:185` / `:192` | `onFlutterViewAttached/Detached` 僅在非 hybrid 時 `setContainerView` | **HC 側**（略過） | 同上 |
  | `InAppWebView.java:217` | 傳入 `super(context, containerView, useHybridComposition)` | 直通 | 非分支，僅轉發 |
  | `InAppWebView.java:445` / `:1124` | hybrid 時才 `setLayerType(HARDWARE/NONE)` | **HC 側**（套用） | HCPP 繪到自己的原生 Surface，與 HC 同性質。**此處是本表推理最間接的一項，需於 Phase 4 實測確認** |
  | `InAppWebView.java:539` | 非 hybrid 時建立 `checkContextMenuShouldBeClosedTask` | **HC 側**（略過） | 自訂浮動選單機制，HCPP 可用原生 action mode |
  | `InAppWebView.java:651` | 非 hybrid 時注入隱藏選單的 plugin script | **HC 側**（略過） | 同上 |
  | `InAppWebView.java:1712` | `onCreateInputConnection` 的收鍵盤 workaround | **HC 側**（略過） | 另有 `containerView != null` 守衛，HCPP 下 containerView 為 null，雙重短路 |
  | `InAppWebView.java:1746` / `:1755` | hybrid 時直接用 `super.startActionMode` | **HC 側**（用原生） | 真實階層下原生 action mode 正常運作 |
  | `InAppWebView.java:1766` | `rebuildActionMode` 中的 `onWindowFocusChanged` | **HC 側**（略過） | 同樣受 `containerView != null` 守衛 |
  | `InAppWebView.java:2236` | 收鍵盤時取 containerView 的 window token | **HC 側**（用自身 token） | 同樣受 `containerView != null` 守衛 |
  | `InputAwareWebView.java:209` / `:230` / `:271` / `:349` | IME 代理 workaround 的四處守衛 | **HC 側**（略過） | 該 workaround 為「view 不在真實階層」而存在 |
  | `InAppWebViewSettings.java:135` / `:425` / `:585` | 宣告 / `fromMap` / `toMap` | 直通 | 非分支 |

  **結構性觀察**：多數 `!useHybridComposition` 分支另有 `containerView != null` 守衛，而
  containerView 只有在 `!useHybridComposition` 時才非 null（`FlutterWebView.java:67`）。
  兩道守衛由建構方式保證一致，這是「布林語義即為是否在真實 view 階層」的直接佐證。

- **[Q1]** 新增 `androidCompositionMode` 列舉，`useHybridComposition` 標記 deprecated 但保留——
  理由：對外零破壞，既有使用端與從上游遷移者不受影響；新欄位語義清楚，未來要再加模式不必再改型別。
  需另定義兩個欄位並存時的優先順序與一致性規則。
- **[Q2]** plugin 初始化時呼叫 `checkIfSupported()` 並快取，建立 controller 時讀快取決定實際模式——
  理由：使用端只宣告意圖，不可用時自動退回 TLHC，行為可預測且不會出現白畫面等級的失敗。
  需處理「查詢尚未完成就要建立 view」的競態。
- **[Q3]** Java 端布林維持不變，Dart 在 HCPP 模式下對 native 送 `useHybridComposition: true`——
  理由：該布林的實際語義是二元的（WebView 是否在真實 view 階層），HCPP 與 HC 同側。
  delta 最小。**此決策成立的前提是 Phase 1 逐點驗證 21 處分支皆與 HC 同側；若有任一處不成立，
  必須停止並回到 Phase 2 重新請示。**
- **[Q5]** 一併檢視 `InAppBrowser` 與 headless 路徑，並於欄位文件標明合成模式對其不適用——
  理由：兩者不經過 platform view，僅需一句文件說明即可避免使用端誤解。
- **[Q4]** 以 API 34+ 模擬器驗證——理由：唯一不需採購硬體的路徑。
  模擬器的 Vulkan/SurfaceControl 行為未必等同實機，此限制必須明確寫入驗收紀錄。

## Git Completion Policy

- Issue 綁定後，PR body 必須含 `Closes #${N}`（`${N}` 取自上方 `- Issue:`，**不是** `${ID}`），
  歸檔完成後於該 issue 張貼由 archive 蒸餾的結案留言 (Rule 20)。
- 經核准的 commit 之後，完成前會執行 `git rebase main` 與
  `git push --force-with-lease --force-if-includes`（`main` 由 `refs/remotes/origin/HEAD` 判定）。
- PR 請求會自動觸發歸檔與 wikification。
- 單一 repo，不涉及跨 repo PR。

## References

- Flutter 官方說明：`https://docs.flutter.dev/platform-integration/android/platform-views`
  ——**注意該頁把 HC 與 TLHC 的 API 對應寫混了**（宣稱 HC 用 `initSurfaceAndroidView`）。
  本計畫的 API 對應一律以 Flutter 3.47 的
  `packages/flutter/lib/src/services/platform_views.dart:134-238` 為準。
- 前置計畫：[2608191735-webview-render-perf](../../archive/2608191735-webview-render-perf.md)
  ——把 `useHybridComposition` 預設翻為 TLHC，本計畫建立在該事實上。
- 現有 Wiki 節點：[android-platform-view-composition](../../wiki/features/android-platform-view-composition.md)
- 現有 Wiki 節點：[keyboard-avoidance](../../wiki/features/keyboard-avoidance.md)
  ——`InputAwareWebView` 的四處守衛直接關係到該功能，是本計畫最高風險面。
- 活躍計畫 `2608121440-back-gesture-fling`（Status: Planning）同樣動 `InAppWebView.java`，
  落在 `onTouchEvent`；本計畫落在合成模式相關分支。兩者若同期推進，合併時需注意同檔案不同區段。
