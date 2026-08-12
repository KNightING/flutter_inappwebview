# Tasks: WebView 軟鍵盤避讓內建化

> plan.md 的 Q2／Q3／Q4 已確認；Q1 由使用者決定延後，且不阻擋本計畫（作用對象是 App 端 repo）。
> 範圍：**Android 優先**（iOS 未排除，另行評估）；避讓由**套件內部完成整套**；
> 設定項 `keyboardAvoidance` **預設開啟**（Q3 原決議為關閉，2026-08-11 由使用者翻轉，
> 見 plan.md 的 Q3 與 Key Decisions）。

## Phase O — 已知良好基準
- [x] O1. 動任何程式碼前先建置 `flutter_inappwebview/example`（Android），確認新基底可建置可執行
- [x] O2. 記錄基準結果；若本來就不可建置，先停下回報，不得在壞掉的基準上開發
      → **基準本來就壞**：`JetifyTransform` 在 `-Xmx1536M` 下 `Java heap space`，已停下回報並取得處置決議
- [x] O3. 修復基準：移除未使用的 `com.android.support:multidex:1.0.3`（minSdk 實測 24，原生支援
      multidex，且無 `MultiDexApplication` 引用），並關閉 `android.enableJetifier`
      → 重建通過：`√ Built app-debug.apk`，且耗時由失敗的 6m23s 降為 119s（不再 jetify engine jar）。
      `-Xmx1536M` 未調整——根因是 Jetifier，加記憶體只會遮住它
- [ ] O4. 同步修復 `flutter_inappwebview_android/example`（使用者於 2026-08-11 追加要求）——
      該 example 有完全相同的 multidex + Jetifier 組合，不修會在首次建置時撞同一面牆。
      額外發現：該 example 另有**上游既有的依賴解析缺陷**——`flutter_inappwebview_android` 把
      `platform_interface` 宣告為 hosted 依賴，example 用 path，pub 無法統一兩種來源而
      version solving failed。已補 `dependency_overrides` 覆寫該套件（僅此一項，非照抄
      app-facing example 的 7 套件清單）
- [x] O5. 實機執行 `flutter_inappwebview/example` 確認可執行（裝置 `M4AIB763K212ZBA`）
      → 安裝成功、啟動後進程存活（PID 27727）、logcat 無 FATAL
- [ ] O6. 基準結果提交後才進 Phase A

## Phase O 遺留（不在本計畫修，但已知）
- Gradle wrapper 為 8.13.0，Flutter 警告即將要求 ≥ 8.14.0。目前仍可建置，未來需處理。

## Phase A — 攔截 IME 插邊（證實 Chromium 會停手）
> 實際執行順序為 B → A，理由見 plan.md 的 Key Decisions。
- [x] A1. 於 `InputAwareWebView` 掛 window insets 監聽，消耗 IME 那一段
      → `setKeyboardAvoidanceEnabled()`，以 `ViewCompat.setOnApplyWindowInsetsListener` 實作，
      僅 API 30+ 生效；於 `InAppWebView.prepare()` 與 `setSettings()` 兩處接上
- [x] A2. 實機驗證 → **通過**。`resize=false` 時，關閉避讓量到 `offsetTop 0→346.9`（Chromium 平移
      5 幀），開啟避讓後 `offsetTop` 與 visual `height` **皆全程不變**，連 `resize` 事件都沒有。
      完整三格數據見 plan.md 的「Phase A 實測結果」
- [x] A3. 副作用檢查 → 原生 UI **全數通過**（`<select>` 下拉、游標把手、選取把手、選字浮動
      工具列皆位置正確且不被鍵盤遮蔽）。`visualViewport` 的回報行為改變已記入文件註解。
      完整結果見 plan.md 的「Phase A3 副作用檢查結果」
- [ ] A3b. **autofill 建議下拉未能驗證**——測試裝置無 autofill 資料，無候選即無下拉。
      需在有 autofill 資料的裝置或建立測試資料後補驗，不得以「沒看到問題」視為通過
- [x] A4. 第 4 格（`resize=true` + `avoid=true`）已補量 → **抓到位移過頭的缺陷並修正**：
      `focusin` 回報焦點座標後，Scaffold 才縮小 WebView，該座標隨即過期，位移超出約一個鍵盤高度。
      修正為腳本加掛 `window` 與 `visualViewport` 的 `resize` 監聽，版面變動即重新回報。
      重驗通過。**此格是預設開啟後多數使用端會落在的狀態**，若未先補量即翻預設會是開箱即壞

## Phase B — 設定項
- [x] B1. `platform_interface` 的 `in_app_webview_settings.dart` 宣告 `keyboardAvoidance`
      （`.g.dart` 已重新產生：欄位／建構子／fromMap／toMap／toString／支援查詢）。
      預設值最初為 `false`，2026-08-11 依使用者指示翻轉為 **`true`**（見 plan.md 的 Q3）
- [x] B2. `InAppWebViewSettings.java` 欄位、`parse` 的 case、`toMap`
- [x] B3. app-facing 透傳確認 → 設定走 map 序列化，`toMap`/`fromMap` 接通即生效，無額外透傳程式碼
- [x] B4. 攔截受設定閘控——`setKeyboardAvoidanceEnabled(false)` 將監聽器設回 `null`，不安裝任何東西

## Phase C — 避讓實作（套件內部完成整套，Q2=A）
- [x] C1. `KeyboardAvoidanceJS`（`plugin_scripts_js/`）回報焦點元素 `getBoundingClientRect().bottom`
      與 `devicePixelRatio`。走專屬 `@JavascriptInterface` 而非 `callHandler`——後者需往返 Dart，
      對要趕在鍵盤動畫內落地的位移太慢，且會為從不離開原生層的資料鋪 Dart 管線
- [x] C2. `KeyboardAvoidanceController` 以攔下來的 IME inset 高度計算位移，夾在鍵盤高度以內
- [x] C3. 位移實作：**平移 PlatformView**（使用者於 2026-08-11 拍板）。`setTranslationY` 於
      WebView 本身，內容不重排；露出的空白條被鍵盤蓋住，故位移量必須 ≤ 鍵盤高度
- [x] C3b. 焦點欄位浮於鍵盤上方；**鍵盤開啟時跨欄位移動焦點亦正確重算**（先前標記的缺口不存在）。
      ⚠️ **本項原記錄「間距 24px 與 22px 吻合」是縮圖判讀錯誤，已更正**：以當時的參數回推，
      `overlap` 算出 905 但被 `Math.min(905, 883)` 夾成 883，欄位下緣落在視窗 1450、鍵盤上緣 1451，
      **實際間距只有 1px**（欄位貼死在鍵盤上）。當時看起來「差不多對」純屬巧合。
      修正 D4b 的插邊來源缺陷後重新驗算，間距為**確切的 22px**（見 D4b）
- [ ] C4. 使用端零程式碼驗證：example 不自行平移、不改 viewport meta 即可正常避讓
      （`resizeToAvoidBottomInset: false` 仍需使用端宣告，見 Goals 的修正）
- [x] C5. 關閉設定時完全不介入 → **已由實測反證確認**。2026-08-12 使用者實機操作的擷取中：
      `avoid=true` 期間約 90 秒（含多次鍵盤開關與邊緣手勢），`visualViewport` 平移事件 **0 筆**；
      於 14:07:51 關閉後兩秒內出現 **18 筆** `vv-scroll`（`physBottom` 在 1550/1643/1767/1952 間跳動）。
      關閉即回到上游的 Chromium 自行平移行為，正是本功能要消滅的那個現象

## Phase C 已知缺陷 — 執行期切換無效
- [x] C6. **已處置：採 B（文件限定 + 拒絕套用）**。使用者於 2026-08-11 拍板。
      `setSettings` 偵測到 `false → true` 時記 warning 並**拒絕套用**，不做半套；
      `true → false` 仍允許且立即生效（監聽移除、位移歸零、controller 再也收不到鍵盤高度，
      算出的位移恆為 0）。Dart 文件註解已載明只能於 `initialSettings` 指定。
      未採 A 的理由：`addJavascriptInterface` 仍需重載才綁得上，回報路徑得改走 JS bridge，
      會讓**所有**情境退回 Dart 往返，代價由主要路徑承擔卻只為服務邊緣案例。

<details><summary>原始缺陷描述（保留以供追溯）</summary>

      `keyboardAvoidance` 於 `setSettings` 執行期由 `false` 改為 `true` **不會生效**，
      且會產生比不開更糟的狀態：插邊攔截立刻生效（純 View 層），但注入腳本未註冊、
      無人回報焦點位置，於是兩個執行者都不動作，輸入框被鍵盤完全遮住。
      成因：`addPluginScript` 在 `prepare()` 時依當下設定登記；重新載入只會重新注入
      controller 內已登記的腳本，**補不回當初沒登記的**（此點經實測推翻「重載即可」的初判）。
      處置二擇一，待決：
      - A. 啟用當下以 `evaluateJavascript` 補注入。代價：`addJavascriptInterface` 仍需重載才綁得上，
        故回報路徑得改走既有 JS bridge，退回原本刻意避開的 Dart 往返
      - B. 文件明確限定只能於 `initialSettings` 指定，`setSettings` 偵測到變更時記 warning。
        範圍最小、行為最誠實，代價是失去彈性

</details>

## Phase D — 驗證
- [ ] D1. 套件自帶 example 專案驗證開／關兩種設定
- [x] D2. 掉幀量測（`gfxinfo`，5 輪開關鍵盤，兩組各 10 次焦點事件、幀數相當）：

      | 組態 | 總幀數 | 掉幀 | 90th | 95th | 99th |
      | :--- | ---: | ---: | ---: | ---: | ---: |
      | `resize=true` + `avoid=true` | 272 | **12 (4.41%)** | 17ms | 19ms | 23ms |
      | `resize=false` + `avoid=true` | 264 | **0 (0.00%)** | 10ms | 10ms | 13ms |

      證實掉幀來自 **Flutter 的 Scaffold 縮放 WebView**，非 Chromium；也量化了建議組態的效益。

      **量測範圍限制（重要）**：hybrid composition 下 WebView 渲染於自己的 `SurfaceView`
      （`dumpsys SurfaceFlinger --list` 可見），`gfxinfo <pkg>` 只涵蓋 Flutter 那一層。
      「0 掉幀」的正確讀法是「Flutter UI 不再因鍵盤重排而掉幀」，**不是**「WebView 內部也零掉幀」。
      後者需改用 `dumpsys SurfaceFlinger --latency <layer>`，本次未做。

      > 執行時犯了兩次同樣的錯：未先確認開關狀態就開始量測，導致第一次量到的其實是
      > `resize=true`（App 沿用了前次的狀態，而 `monkey` 只把既有實例帶到前景，不會重設）。
      > 正確做法是 `am force-stop` 後重啟，並以截圖確認標頭再開始。
- [x] D3. 三條關閉路徑**全數通過**（組態 `resize=false` + `avoid=true`，30fps 錄影抽幀判讀）：
      - **鍵盤收合鈕**：焦點不變、`focusout` 不觸發，位移純靠 `setKeyboardHeightPx(0)` 歸零 → 平順
      - **邊緣滑動手勢**：前身計畫記錄抖動最嚴重的一條（實測 `offsetTop` 0→57）→ 平順，無位移加倍
      - **點空白處**：失焦與收鍵盤同時發生 → 平順
      三條皆為「輸入框貼著鍵盤上緣一起下降」，無瞬跳、無間隙。
      另確認：`resize=false` 時**沒有**先前在 `resize=true` 觀察到的淡色帶，
      證實該色帶成因是 Scaffold 縮放動畫與平移動畫各自獨立跑，非本功能缺陷
- [x] D4a. **轉向通過**。橫式下可用空間僅約 114px（鍵盤佔絕大部分），焦點欄位完整可見，
      位移被 `Math.min(overlapPx, keyboardHeightPx)` 正確夾住而非把欄位推出畫面
- [x] D4b. **焦點位於內部捲動容器 → 抓到真缺陷並修正**。
      症狀：欄位下緣被鍵盤切掉約 44px。
      **成因不是內層容器**——是鍵盤高度有兩個不一致的來源，一直存在，只是先前沒被看見：

      | 來源 | 值 |
      | :--- | ---: |
      | 派送到 WebView 的 `insets`（監聽器） | 883 |
      | `ViewCompat.getRootWindowInsets()` | 949 |
      | 動畫回呼 `onProgress` 最終值 | 949 |

      差 66px = 24dp @ density 2.75，即導航列手勢區。WebView 位於 Flutter 視圖樹深處，
      祖先已先消耗掉那一段；而位移是在**視窗座標**下計算的，需要視窗層級的值。
      逐幀動畫先算出正確的 484，最後監聽器在 1ms 後以 883 覆蓋成 418——最後寫入的贏。

      修正：**消耗**仍作用於派送來的 `insets`（那是擋住 Chromium 的機制），
      **量測**改從 `getRootWindowInsets()` 取。兩者拆開。
      重驗：內層欄位完整可見；底部釘住欄位間距為確切的 22px；D3 邊緣手勢動畫不受影響。

      > 診斷過程曾誤判兩次，皆已記錄：先誤以為是內層容器的 `scroll` 事件沒被捕獲，
      > 後誤以為是「重複扣除鍵盤高度」。兩次都是憑推理，實測皆推翻。第三次改為先加
      > 暫時性原生除錯輸出取得算式的全部輸入，才定位到真因。除錯輸出已於修正時移除。
- [ ] D5. 驗證使用端是否真的不再需要 `interactive-widget=overlays-content`（Goals 第 3 項）——
      Phase A 第 3 格顯示 visual viewport 完全不縮，該 meta 要壓抑的行為已不存在，但此為推論未直接驗證

## Phase E — delta 檢查（本 repo 特有）
- [ ] E1. `git diff upstream/master` 確認變更範圍未逸出計畫；新增為主、改寫既有邏輯降到最低
- [ ] E2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent

## 界外發現 — 邊緣返回手勢造成頁面 fling（**上游 bug，不屬本計畫**）
使用者於 2026-08-12 回報並實測確認：邊緣返回手勢若起始於 WebView 區域，頁面會往上捲動；
起始於其他 Flutter widget 則不會。在套件自帶的 example 亦可重現，**且與鍵盤無關**。

實測擷取（14:12:49，`keyboardAvoidance=false`，無鍵盤）：15 筆 `scroll:document` 集中於 250ms，
`physBottom` 由 1531 單調遞減至 41，逐幀差值 52→61→264→110→215→105→101→99→95→91→88→84→81→44
——先衝高再衰減，是典型的 fling 減速曲線。全程 `offsetTop=14.9` 不變，**visual viewport 未參與**，
純文件捲動。

推測機制：系統判定返回手勢前，`DOWN` 與數個 `MOVE` 已送入 WebView，Chromium 的速度追蹤器開始累積；
系統確認手勢（即使用者感受到的震動）後補發 `ACTION_CANCEL`，但 fling 已啟動且未被取消。
`InAppWebView.onTouchEvent`（`:1583`）對 `ACTION_CANCEL` 無任何處理。

**合成 `adb shell input swipe` 無法重現**——它繞過系統手勢辨識，不會震動也不會發 `CANCEL`。
需真實手指操作。

依 Rule 8 應另開計畫。候選方向（皆待實測，未預設何者正確）：
`ACTION_CANCEL` 時以 `flingScroll(0,0)` 中止；或記錄 `ACTION_DOWN` 捲動位置於 `CANCEL` 時還原；
或僅對起始於系統手勢區的觸控特殊處理。
