# Tasks: 2608140927 - keyboard-avoidance-pre-r

> 測試機：Urovo U2（`01412420054591`，Android 10 / API 29 / 800×480）。
> 對照機：API 30+ 一台（確認本次改動未影響既有路徑）——目前手邊沒有，見 D3。

## Phase A — 前置
- [x] A1. 建立 GitHub Issue（`KNightING/flutter_inappwebview`）並回填 `plan.md` 的 `- Issue:`
- [x] A2. 以 `gh issue develop` 建立 `feature/2608140927-keyboard-avoidance-pre-r`（base `main`）並 `git switch`

## Phase B — 實驗：pre-R 能不能拿到準確的鍵盤高度
- [x] B1. 加了暫時性 probe，**兩條通道都測**
- [x] B2. U2 實機結果：
  - **insets 通道不可用**（推翻計畫原本的假設）：`getSystemWindowInsets().bottom` 與 `getStableInsets().bottom`
    **全程為 0**，且鍵盤彈出時**根本不再觸發** `onApplyWindowInsets`。原因是 App 為 edge-to-edge
    且 Flutter embedding 在 FlutterView 層就把 insets 消耗掉，子 View 收不到 IME。
  - **visible display frame 通道可用且精準**：橫向鍵盤彈出時
    `rootHeight=480 visibleBottom=229 candidate=251`，而同一時刻 IME 自報 HEADER 48 + BODY 203 = **251**，**完全吻合**。
    同時 `webViewHeight` 由 480 縮到 228，反映目前 App 仍走 framework resize。
- [~] B3. 不再適用：實作最終不採用 visible-display-frame 通道（見 C1／Phase C 結論），改由 Dart 層轉交。
  收鍵盤歸零改在 D4 以最終實作驗證。

### B 的方法學教訓（實作時要沿用）
- `getInsetsIgnoringVisibility(Type.systemBars())` 在 pre-R 會打到平台隱藏方法
  `android.view.WindowInsets$Type.systemBars()`（API 30 才公開），被 blacklist 擋下。pre-R 一律用
  `getSystemWindowInsets()` / `getStableInsets()`。
- `getViewTreeObserver()` 在 View 尚未 attach 時回傳暫時性 VTO，attach 後會被換掉——監聽器只會在
  啟動時響幾次就再也不觸發。必須在 `onViewAttachedToWindow` 之後掛到 **root view** 的 VTO 上。

## Phase C — 實驗：pre-R 要不要壓制 Chromium、怎麼壓
- [x] C1. 候選 2（不壓制）**結果推翻了計畫前提**：
  - 組態：App `resizeToAvoidBottomInset: false`（暫時改），套件在 pre-R 建立 controller + JS interface，
    高度來自 visible display frame，不消耗任何插邊。
  - **套件全程沒有動作**：`translationY=0.0`，frame 監聽器只在啟動時響 3 次（`keyboardHeight=0`），
    鍵盤彈出時**不再觸發**——因為 `resizeToAvoidBottomInset: false` 之下 Flutter 不重排，
    Android view 樹沒有 layout pass，OnGlobalLayoutListener 自然不響。
    （先前量到 251 那次是 `resize: true`，Flutter 的重排順帶製造了 layout pass。）
  - **但焦點欄位仍被正確讓開**——是 Chromium 自己的 `ScrollFocusedEditableIntoView` 做的。
    重啟後重測一次，結果一致（`c1b/c1c` 截圖）。
  - 意涵：pre-R 因為**沒有**壓制，Chromium 這個原生避讓者仍在運作。R+ 需要套件平移，正是因為
    套件在那裡把 Chromium 消音了。
  - ⚠ 與 fork 自己的 `archive/2608132314` 敘述衝突：該文件說 API 29 + `resize:false` 時
    「焦點欄位直接被鍵盤蓋住」。差異可能在頁面能否捲動（本次測的登入頁有捲動餘裕）。
- [x] C1b. 無捲動餘裕的頁面（登入頁根容器加 `overflow-hidden`，重新產種子包）：**焦點欄位仍被讓開**，
  套件仍然 `translationY=0.0`。推測 Chromium 平移的是 **visual viewport** 而非文件捲動——
  這與 fork wiki 對 R+ 的描述一致（「Chromium reacts to IME insets by running its own
  ScrollFocusedEditableIntoView, which translates the visual viewport」），而 visual viewport
  的平移不受 CSS `overflow` 影響。因此 `overflow:hidden` **並未真正製造出「Chromium 無計可施」的情境**。
- [x] C1c. **已釐清，且推翻 C1/C1b 的解讀**：在同一台 U2 上跑模板 `nuxt-flutter-app`（`resize:false`，
  其自身釘的 fork tag），焦點輸入框**完全被鍵盤蓋住、頁面零位移**——`archive/2608132314` 的記載正確。
  差異在網頁層而非裝置：模板根容器為 `min-h-dvh`（長頁面，min-height 不綁定，不重排），
  upcc 為 `h-dvh`（高度綁定動態 viewport，鍵盤縮短 dvh 時整個版面重排、卡片上移）。
  → **upcc 先前的「成功」是版面副作用，不是避讓機制**，長表單等不重排的頁面仍會被蓋住。
  → **Chromium 在 pre-R 確實不動作**，因此 pre-R **不需要壓制**，只需補上平移。Q2 的顧慮解除。

## Phase C 結論
pre-R 缺的只有「平移」這一半，且沒有第二個角色需要壓制。唯一缺口是鍵盤高度的來源——
原生端在 `resize:false` 下沒有任何可用通道（insets 全 0、無 layout pass），
但 Flutter engine 有（framework resize 能運作即為證據），故改由套件的 Dart 層轉交。
- [~] C2. 不適用：C1c 證實 Chromium 在 pre-R 不動作，沒有需要壓制的第二個角色。
- [x] C3. 結論如上。

## Phase D — 實作
- [x] D1. 依 B/C 結論實作，API 30+ 路徑完全未動：
  - `InputAwareWebView.setKeyboardAvoidanceEnabled`：pre-R 改為建立 controller + 掛 JS interface 後 return
    （不裝 insets listener、不消耗任何插邊）
  - `InputAwareWebView.setFrameworkKeyboardInsetPx(int)`：接收 framework 量到的鍵盤高度，
    R+ 直接忽略（該版本自有更即時的來源，避免兩個寫入者）
  - `WebViewChannelDelegateMethods` / `WebViewChannelDelegate`：新增 `setFrameworkKeyboardInset`
  - Dart `AndroidInAppWebViewController`：`startFrameworkKeyboardInsetReporting()` 以
    `WidgetsBindingObserver.didChangeMetrics` 觀察 `implicitView.viewInsets.bottom`（已是實體像素），
    變動才送、附去重
  - Dart `AndroidInAppWebViewWidget._onPlatformViewCreated`：`keyboardAvoidance` 啟用時開始回報
- [x] D2. 移除 probe log
- [x] D2b. **實作驗證通過**：同一台 U2 上，改動前後跑模板 App（`min-h-dvh` 長頁面、不重排、
  Chromium 不動作）——改動前輸入框被鍵盤蓋住且頁面零位移；改動後整頁均勻上移約 57px，
  輸入框可見於鍵盤正上方。位移來源只可能是套件的 `setTranslationY`。
  另於 upcc（`h-dvh`）直向確認版面維持直向、最下方欄位可見。
- [ ] D3. 迴歸驗證：API 30+ 機器上行為與改動前一致（**手邊無此機器，需你提供或延後**）
- [x] D4. U2 完整驗證**全數通過**（宿主為模板 `nuxt-flutter-app`，`min-h-dvh` 長頁面不重排、
  Chromium 不動作，位移只可能來自套件）：
  | 情境 | 結果 |
  |---|---|
  | 直向・焦點欄位 | 整頁上移約 57px，欄位可見於鍵盤正上方 |
  | 直向・失焦還原 | 頁面精準回到原位，無殘留位移（`onFocusCleared` 路徑正常） |
  | 橫向・焦點欄位 | 整頁上移約 104px，欄位可見於鍵盤正上方 |
  | 連續切換焦點 | 以 IME next 切換後再點回同一欄，位移**未累加**（與 `computeShiftPx` 的冪等設計相符） |
  | 橫向・失焦還原 | 頁面回到原位 |
  另於 upcc（`h-dvh`）直向確認版面維持直向、最下方密碼欄可見。

## Phase E — 文件
- [x] E1. `in_app_webview_settings.dart` 的 `keyboardAvoidance` 文件改寫，`.g.dart` 以 build_runner 重新產生：
  - 版本要求：Android 改為「所有支援版本皆可用，但機制分兩套」——API 30+ 讀獨立 IME inset 型別；
    以下由 Dart 端觀察 `didChangeMetrics` 轉交 `FlutterView.viewInsets.bottom`，且**不需壓制**
    （Chromium 在該區間不反應）。iOS 的 17.2 下限維持不變。
  - 「不得無條件設 `resize:false`」的 CAUTION 收斂為 **iOS 專屬**；Android 不再有此但書。
  - `visualViewport` 那段的理由補上兩條路徑：API 30+ 是插邊被套件消耗，以下是插邊根本沒送達
    （API 29 實測 system window 與 stable 底邊全程為 0）。
- [x] E1b. **`flutter analyze` 抓到一個真缺陷並修掉**：原本寫 `params.initialSettings?.keyboardAvoidance`，
  但本套件相依的是 **pub.dev 上的** platform interface（`pubspec.yaml:23`，本機 path 是註解狀態），
  fork 自加的設定在型別上不存在，standalone 分析必然失敗（App 端因三包一起 override 才碰巧能編）。
  改為 `initialSettings?.toMap()['keyboardAvoidance']`，改後 `flutter analyze lib` → No issues found，
  並重建 APK 於 U2 複驗行為不變。
- [ ] E2. wiki `keyboard-avoidance.md` 依實際結果改寫（Phase 5 交由 wikification）

## Phase F — 收尾
- [ ] F1. `git diff upstream/master` 檢視 delta 成長幅度，確認符合 Q1 決議
- [ ] F2. Commit（逐項取得核准）→ rebase main → force-with-lease push
- [ ] F3. PR（**目標 repo 須為 `KNightING/flutter_inappwebview`**）+ 歸檔 + wikification
- [ ] F4. 發新 tag 供使用端重釘（現行為 `6.2.0-beta.3.2`）

## 後續（不在本計畫，屬 sld-upcc-middle）
- [ ] 重釘 fork tag、`resizeToAvoidBottomInset` 一律 `false`、移除 `_detectKeyboardResizeFallback`
- [ ] 重新評估 `data-orientation` / `screen-landscape:` 是否還需要保留
