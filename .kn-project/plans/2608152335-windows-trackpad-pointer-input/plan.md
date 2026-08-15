<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608152335 - Windows 觸控板改走 SendPointerInput（慣性與斜滑兩軸）

- Created: 2026-08-15
- Issue: `KNightING/flutter_inappwebview#14`
- Branch: `feat/2608152335-windows-trackpad-pointer-input`
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

讓 Windows 的觸控板捲動具備兩件現行合成滾輪路徑**先天做不到**的行為：

1. **慣性**——手指離開後畫面逐漸減速停止
2. **斜滑同時捲動兩軸**——不再只走主導軸

做法是把觸控板手勢改送 `SendPointerInput`（合成觸控），由 Chromium 走它原生的 fling 與
二維捲動路徑，而不是由套件把手勢翻譯成一維滾輪。

## Architecture

### 為什麼滾輪路徑做不到

`SendMouseInput` 的 `WHEEL` / `HORIZONTAL_WHEEL` **一次只能表達一個軸**，且滾輪事件本身
不帶速度或手勢階段資訊，Chromium 因此無從產生 fling。前一個計畫
（`.kn-project/archive/2608152118-windows-trackpad-scroll.md`）也已量到：Windows 的觸控板
慣性事件流並未送達 Flutter——手指離開後只剩幾幀 <1px 的殘值，**不是套件把它吃掉**。

因此這兩項不是調參數能解決的，必須換輸入通道。

### 基礎設施已存在（本計畫的關鍵前提）

合成觸控**不需要從零打造**，套件已有完整實作，目前服務於觸控螢幕：

- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp:3670`
  — `InAppWebView::setPointerUpdate()`：以 `ICoreWebView2Environment3::CreateCoreWebView2PointerInfo`
  建立 pointer info，設定 `PT_TOUCH`、`POINTER_FLAG_DOWN/UPDATE/UP`、`TOUCH_MASK_CONTACTAREA |
  TOUCH_MASK_PRESSURE`、`PixelLocationRaw`、`TouchContactRaw`（±2px 接觸矩形），再呼叫
  `SendPointerInput`。**down / update / up 三個階段皆已備妥。**
- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart:184`
  — Dart 端 `_setPointerUpdate`，經 method channel 傳入 pointer id、階段、座標、size、pressure。
- 同檔 `:460` / `:478` / `:508`
  — `onPointerDown` / `onPointerUp` / `onPointerMove` 在 `ev.kind == PointerDeviceKind.touch`
  時走這條路徑，滑鼠則走 `setPointerButtonState`。

本計畫要做的是**把觸控板的 pan 手勢接上這條既有路徑**，不是新增通道。

### 手勢到觸控的映射

| Flutter 事件 | 送出 |
| :--- | :--- |
| `onPointerPanZoomStart` | `down`，座標取手勢起點（游標所在位置） |
| `onPointerPanZoomUpdate` | `update`，座標為起點 + 累積的 `pan`（非 `panDelta`） |
| `onPointerPanZoomEnd` | `up`，座標為最後一次的位置 |

符號**不需轉換**：`pan` 本就是直接操作語意（內容跟著手指走），與觸控拖曳一致。這也消掉了
現行滾輪路徑那個「垂直不取負、水平取負」的不對稱。

慣性由 Chromium 依 `up` 之前的座標序列自行計算速度產生，套件不需要也不應該自行合成衰減。

### 風險：頁面看得到的行為會改變

這是本計畫最重要的一件事，也是必須閘控的理由。改走觸控後頁面收到的是
`touchstart` / `touchmove` / `touchend` 與 `pointerType: touch`，而非 `wheel`。許多網站據此
判定「這是觸控裝置」並切換為行動版互動：hover 效果失效、`:hover` 樣式不觸發、拖曳行為改變、
可能出現下拉更新一類的手勢。對桌面 App 而言，使用者用觸控板捲動就讓網站以為自己在手機上，
是實打實的回歸風險。

> [!IMPORTANT]
> **上述風險已於 2026-08-16 以雙輪對照實測，結論是它遠比預期小，因此設定項閘控被取消。**
> 詳見下方「風險的實測結果」。

### 風險的實測結果（2026-08-16）

以擴充後的測試頁（純 CSS `:hover`、Pointer Events 拖曳、原生 HTML5 draggable、
裝置能力查詢）在**滾輪路徑**與**觸控路徑**各測一輪，結果**兩輪完全相同**：

| 項目 | 滾輪路徑 | 觸控路徑 |
| :--- | :--- | :--- |
| CSS `:hover` | 正常 | 正常 |
| Pointer Events 拖曳 | 正常 | 正常 |
| 原生 HTML5 draggable | **禁止游標** | 禁止游標（基準線即如此，與本計畫無關） |
| `maxTouchPoints` / `ontouchstart` / `hover:hover` / `pointer:coarse` | 不變 | **不變** |

原因：那些能力值反映的是**實體裝置能力**，不是收到的事件種類。把捲動手勢包裝成觸控接觸點
並不會讓系統變成觸控裝置，因此多數網站的「是不是觸控裝置」判斷不受影響。

**殘留風險（測試頁涵蓋不到，仍然真實）**：以「收到過 `touchstart` 就記旗標」判定觸控的網站，
在觸控路徑下**會**被觸發。這是比原先描述窄得多的一類。

原生 HTML5 拖放在**兩種路徑下皆不可用**——composition 模式的 WebView2 需另接 OLE drop target，
套件未實作。屬既有限制，非本計畫造成。

## Cross-Repo Scope

無（單一 repo）。

> 使用端 `nuxt-flutter-app` 需新增第四個 `dependency_overrides`（目前未釘 windows）並讓四個
> `ref` 指向同一個新 tag。使用者已決定**待本計畫完成後一併發 tag**，屬使用端工作，不在本計畫範圍。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-15 在 `main`（`613b28ce5`）實際確認。

### 既有

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart:485`
  — `onPointerPanZoomStart/Update/End` 三個處理器，需依設定分流至觸控或現行滾輪路徑；
  現行的軸鎖定（`_latchPanAxis`、`_panAxis`、`_panTravel`）在觸控模式下不適用，需繞過而非刪除。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp:3670`
  — `setPointerUpdate`，合成觸控的既有實作，預期**不需修改**（若需區分合成與真實觸控才動）。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview_settings.h:33`
  — Windows 端設定結構（`scrollMultiplier` 所在），新增設定項於此。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview_settings.cpp:42`
  — 設定解析（`get_fl_map_value`）與 `:77` 的回傳 map，需一併加入。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:2372`
  — Windows-only 設定的宣告樣式（`@SupportedPlatforms(platforms: [WindowsPlatform()])`），
  新設定依此宣告；`in_app_webview_settings.g.dart` 為產生檔，需以 `build_runner` 重新產生。

### 佐證備註

- 現行滾輪路徑的完整說明見 `.kn-project/wiki/features/windows-scroll-input.md`，
  本計畫若交付需同步該頁（Phase 5）。
- `_pointerKind` 於 `custom_platform_view.dart:313` 記錄最後一次的指標種類，
  合成觸控是否需要與之協調（例如避免 hover 狀態衝突）待實作時確認。

## Open Questions / 待確認事項

### Q1. 設定項的預設值 — 影響：既有使用者的行為
- [ ] A. ~~預設關閉（建議）~~：現行滾輪路徑維持預設，使用端明確開啟才改走觸控。
  理由：本變更會改變**頁面**收到的事件種類，可能讓網站切換為行動版互動——那不是捲動手感的
  改善，是網站行為的改變，不應該無聲套用到所有既有使用者身上。
- [x] B. **預設開啟**：新使用者直接獲得慣性與斜滑。但與上游行為分歧擴大，且回歸風險由所有人承擔。

狀態：✅ 已確認（2026-08-15）

### Q2. 設定項名稱 — 影響：API
- [x] A. **`useTrackpadPointerInput`（建議）**：直述「觸控板改用 pointer input」，
  與既有的 `useHybridComposition` / `useShouldInterceptRequest` 等 `useXxx` 命名一致。
- [ ] B. `trackpadScrollMode`（列舉：`wheel` / `touch`）：語意更明確且未來可擴充，
  但需新增列舉型別與產生器支援，delta 較大。

狀態：✅ 已確認（2026-08-15）

### Q3. 開啟後 `scrollMultiplier` 的角色 — 影響：語意一致性
觸控路徑不經過 `sendScroll`，`scrollMultiplier` 自然失效。

- [x] A. **文件註明「僅作用於滾輪路徑」（建議）**：不動程式碼，只在兩個設定的 doc comment
  互相指明。觸控模式下的捲動距離由 Chromium 依實際位移決定，本就不該再乘係數。
- [ ] B. 在觸控模式下把 `scrollMultiplier` 套在座標位移上：語意可疑（放大位移等於偽造手指移動），
  且會讓 Chromium 算出錯誤的速度、慣性跟著失真。

狀態：✅ 已確認（2026-08-15）

### Q4. 驗證方式 — 影響：完成判準
- [x] A. **實機手動驗證（建議）**：觸控板手勢需真實硬體，自動化測試無法涵蓋。
  驗證項：慣性存在且會停、斜滑兩軸同時動、關閉設定時行為與現行完全一致、
  真實觸控螢幕不受影響、頁面確實收到 touch 事件（以測試頁的事件記錄確認）。
- [ ] B. 另增自動化測試：本題的判準是手感與事件種類，難以自動化，成本高於效益。

狀態：✅ 已確認（2026-08-15）

## Key Decisions

- **改走既有的 `SendPointerInput` 路徑而非自行合成衰減**（來源：2026-08-15 使用者選定 B 方案）。
  理由：自行合成拿不到斜滑兩軸，且我們的衰減曲線會疊在 Chromium 自己的平滑捲動動畫上，
  變成兩層緩動、難以調準。
- ~~**必須以設定項閘控**~~ → **推翻：不加設定項，觸控板一律走觸控路徑**（來源：2026-08-16
  雙輪對照實測 + 使用者拍板）。理由：閘控的唯一論據是「網站可能切成行動版」，而實測顯示
  hover、拖曳與四項裝置能力查詢在兩條路徑下完全相同。留下開關的代價是一條必須永遠維護與
  測試的第二路徑，換一個論據已被削弱的逃生口。**接受的代價**：真撞到「收到 touchstart 就
  切行動版」的網站時，需改套件並重發 tag，而非改一行設定。
- ~~**設定預設開啟**（Q1=B）~~、~~**命名為 `useTrackpadPointerInput`**（Q2=A）~~
  → **兩者皆作廢**：設定項本身已不存在（見上一條）。實作歷程保留於 Deviations。
- **一併刪除軸鎖定機制**（來源：設定項取消的連帶結果）。理由：`_latchPanAxis` /
  `_panAxis` / `_panTravel` 是滾輪路徑「一次只能表達一個軸」的補償，觸控路徑天生支援
  二維捲動，留著即為死程式碼。`resetScrollRemainder` 同理——其唯一呼叫者是手勢邊界。
- **`scrollMultiplier` 不套用於觸控路徑**（來源：Q3）。理由：放大位移等於偽造手指移動，
  會讓 Chromium 算出失真的速度與慣性；改以文件互相指明適用範圍。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

**本計畫完成後發 tag**（使用者於 2026-08-15 指定）：與前一個計畫的 Windows 捲動修復一併發布，
供使用端 `nuxt-flutter-app` 釘用。

## References

- 前一個計畫（現行滾輪路徑的來源）：
  `.kn-project/archive/2608152118-windows-trackpad-scroll.md`
- 現行行為的 Wiki：`.kn-project/wiki/features/windows-scroll-input.md`
- Flutter 觸控板手勢語意：`https://docs.flutter.dev/release/breaking-changes/trackpad-gestures`

## Deviations（2026-08-16）

- **設定項 `useTrackpadPointerInput` 曾完整實作並通過驗證，最後整個移除。**
  歷程：依 Q1=B 實作為預設開啟 → 實作完成後使用者質疑「為什麼需要這個參數」 → 擴充測試頁做
  雙輪對照 → 實測顯示閘控的論據不成立 → 使用者選擇移除。**本計畫的淨效果因此是程式碼減少
  32 行**，而非新增一個設定。
- **連帶刪除前一個計畫（`2608152118`）剛交付的軸鎖定機制**。那份工作並非白費：它查出
  「兩軸交錯會被 Chromium 吃掉」，而該認識正是選擇觸控路徑的依據之一。程式碼留在 git 歷史。
- **範圍擴充：windows example 補上 `dependency_overrides`**（`example/pubspec.yaml`）。
  發現於 C4 建置失敗——windows example 先前解析的是 pub 上的 platform_interface，
  **無法驗證任何 platform_interface 的新設定**；android 與 ios 的 example 早已有此覆寫，
  只有 windows 沒有。屬既有不一致，順手補齊。
- **C6（真實觸控螢幕不受影響）未執行**：手邊無觸控螢幕裝置。程式碼層面觸控螢幕走的是
  `onPointerDown/Move/Up` 且 pointer id 取自事件本身，與手勢路徑不共用狀態，但**未經實測**。
