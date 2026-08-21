# Plan: 2608211304 - android-hcpp-auto-default

- Created: 2026-08-21
- Branch: `feature/2608211304-android-hcpp-auto-default`
- Issue: KNightING/flutter_inappwebview#22
- Status: Awaiting Archive
- Completed: 2026-08-21

## Goals

讓 Android 的平台視圖合成模式**預設自動選擇**：能跑 HCPP 就跑 HCPP，不能就退回 TLHC，
使用端不需要設定任何套件欄位。

| 面向 | 現況 | 目標 |
| :--- | :--- | :--- |
| 不設任何欄位 | TLHC | **HCPP（可用時）／ TLHC（否則）** |
| `androidCompositionMode: HCPP` | HCPP 或退回 TLHC | 不變 |
| `androidCompositionMode: TLHC` | TLHC | 不變（明確指定仍可強制） |
| `useHybridComposition: true`（deprecated） | HC | **不變**（相容性不得破壞） |

**這是刻意的對外行為變更。** 已經因為其他原因啟用 `EnableHcpp` 的 app，其 WebView 會靜默
改走 HCPP。風險與驗證需求見下方 Architecture。

## Architecture

### 現況

`_resolveCompositionMode()`（`in_app_webview.dart`）：

```
androidCompositionMode ?? (useHybridComposition ? HC : TLHC)
        ↓ 若結果為 HCPP 但不支援
      TLHC
```

不設任何欄位時 → `null ?? (false ? HC : TLHC)` → **TLHC**。

### 目標

只改上式的 else 分支，把 `TLHC` 換成「auto」：

```
androidCompositionMode ?? (useHybridComposition ? HC : auto)

auto = isHybridCompositionPlusPlusSupported ? HCPP : TLHC
```

逐案對照：

| 使用端寫法 | 解析結果 | 相容性 |
| :--- | :--- | :--- |
| 什麼都不設 | auto | **變更**（原為 TLHC） |
| `useHybridComposition: true` | HC | 不變 |
| `androidCompositionMode: TLHC` | TLHC | 不變 |
| `androidCompositionMode: HC` | HC | 不變 |
| `androidCompositionMode: HCPP` | HCPP／退回 TLHC | 不變 |

**這是單一運算式的改動**，且明確指定的四種寫法全部維持原行為，只有「什麼都不設」改變。

### 必須繞過的地雷：舊布林不可為 null

直覺作法是讓 `useHybridComposition` 可為 null 以區分「沒設」與「設了 false」。**不可行**：

- `in_app_webview_settings.dart:3483` 是 `this.useHybridComposition = false`，該欄位**永遠非 null**。
- Java 端 `InAppWebViewSettings.java:135` 為 `public Boolean useHybridComposition = false;`，
  而 `:426` 的 `fromMap` 直接 `useHybridComposition = (Boolean) value;`。一旦送 `null` 過去，
  native 的 21 處 `if (customSettings.useHybridComposition)` 會發生 **unboxing NPE**。

因此本計畫**不動舊布林的型別或預設值**，僅改 Dart 端的 else 分支。native 端維持零改動
（HCPP 仍送 `useHybridComposition: true`，語義為「在真實 view 階層中」）。

### 已知風險

1. **對外行為變更**：啟用了 `EnableHcpp` 的 app 會自動獲得 HCPP。若該 app 是為了別的
   platform view 才開的，WebView 的合成方式會靜默改變。
2. **探測競態**：支援度探測是非同步的，而模式在 platform view 建立當下就定死。
   依 Q2 決議，auto 路徑在支援度未知時會**延後建立** WebView 直到探測完成，
   因此不會出現「同一支 App 內第一個與後續 WebView 模式不同」的情形。
   代價是第一個 WebView 的建立延後一個 channel 往返。
3. **HCPP 上游仍標 experimental**，已知限制為透明 platform view 在複雜疊層下顯示不正確。
4. app 端的 opt-in 閘門仍在，套件拿不掉——本計畫只改「套件這一層要不要設欄位」。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-21 在 `main`（`2352609e1`）上以 Grep 確認。

- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`
  — `_resolveCompositionMode()`，本計畫**唯一的邏輯改動點**（else 分支由 TLHC 改為 auto）。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1188`
  — `androidCompositionMode` 的欄位文件，需說明 null 的新語義（auto）。
- `.../in_app_webview_settings.g.dart` — 文件變更後由 build_runner 同步。
- `flutter_inappwebview_platform_interface/lib/src/types/android_composition_mode.dart`
  — 列舉的類別層文件需說明預設為 auto；若 Q1 選新增 `AUTO` 成員，成員亦加於此。
- `.kn-project/wiki/features/android-platform-view-composition.md`
  — 現有節點寫明「預設 TLHC」與「HCPP 完全是 opt-in」，本計畫完成後由 Phase 5 改寫。

### 不改動

- `flutter_inappwebview_platform_interface/.../in_app_webview_settings.dart:3483`
  — `useHybridComposition` 的預設值 `false`，**維持不變**（見上方地雷）。
- Java 端全部檔案 — 維持零改動。

### 新增

- 無（除非 Q1 選 A，屆時仍是既有檔案內新增列舉成員）。

## Open Questions / 待確認事項

> 全部釐清前不得進入 Phase 3。

### Q1. 是否新增顯式的 `AUTO` 列舉成員？ — 影響範圍：`platform_interface` ✅ 已確認

改動後「不設」即為 auto，但使用端無法**明確**表達 auto（例如想覆寫某個 wrapper 已設的值）。

- [x] **A. 不新增**，以 `null`／不設代表 auto　(建議，理由：改動最小，且 auto 是預設，
      需要明確表達的情境罕見；新增成員會讓列舉多一個「不是真正合成模式」的值，語義較混。)
- [ ] **B. 新增 `AUTO` 成員**，並讓它成為建構子預設 — 語義最明確，但需重新定義與
      `useHybridComposition: true` 的優先順序（新欄位變成永遠非 null，會蓋掉舊布林），
      相容性風險比 A 高。

### Q2. 探測競態如何處理？ — 影響範圍：`_android` dart ✅ 已確認

App 啟動後立刻建立的第一個 WebView 可能在支援度探測完成前決定模式，拿到 TLHC；
之後建立的則拿到 HCPP。作為預設，這種不一致比 opt-in 時更難解釋。

- [ ] **A. 接受並記錄於文件**，維持現有的「未解析即視為不支援」——「有沒有吃到 HCPP」
      會變成取決於 App 自己的啟動時序。**註：原評估稱此情境「屬少數」，但實際未量測過
      「App 第一幀就建 WebView」的案例，該評估為推測而非實證。**
- [x] **B. auto 模式下，支援度未知時延後建立 WebView 直到探測完成**（採用）——
      唯一能保證每次都真的用到 HCPP 的作法。
      **更正**：原敘述稱此法「改動 widget 樹結構」，不正確。做成**延後建立**（未解析時先給
      placeholder，解析完才建 WebView）時，WebView 只會被建立一次，不會發生 remount／重載。
      代價僅為第一個 WebView 延後一個 channel 往返（毫秒級）與其前的一兩幀 placeholder，
      且**只在「auto 且支援度未知」時才等**；明確指定模式或探測已完成皆直接建立、零延遲。
- [ ] **C. 在偵測到「探測完成且結果與已建立的 WebView 不同」時記 warning** — 不改行為，
      只讓問題可見。

### Q3. 是否提供關閉 auto 的逃生門？ — 影響範圍：`platform_interface` + `_android` ✅ 已確認

使用端若在 HCPP 下遇到問題（例如透明 platform view 疊層），需要能退回。

- [x] **A. 不需要**：明確指定 `androidCompositionMode: TEXTURE_LAYER_HYBRID_COMPOSITION`
      即可強制 TLHC，這已經是逃生門　(建議，理由：既有機制已足夠，且是逐 WebView 的
      細粒度控制。)
- [ ] **B. 另提供全域開關**（例如靜態旗標）讓 App 一次關掉 auto — 對「大量 WebView 的
      既有 App 想快速回退」較友善，但多一個全域狀態。

### Q4. 驗證範圍？ — 影響範圍：驗收 ✅ 已確認

- [x] **A. 完整重跑一輪實機驗證**（渲染／捲動／`keyboardAvoidance`／長按／影片／回歸）
      　(建議，理由：這是預設值變更，影響所有未設定的使用端，等同上一次 TLHC 翻預設的
      風險等級。上次的 TLHC 翻預設就是以完整清單驗收。)
- [ ] **B. 只驗「不設欄位時確實走 HCPP」與「明確指定仍生效」** — 較快，理由是 HCPP 本身
      的功能面已於前一計畫驗證過；風險是驗證的是同一批功能在**不同觸發路徑**下的表現。

## Key Decisions

- **[Phase 2 實測，四種寫法全數符合規格]**（實體 Android 16 平板，app 已 opt-in）：
  不設欄位 → `HYBRID_COMPOSITION_PLUS_PLUS`；`useHybridComposition: true` →
  `HYBRID_COMPOSITION`（**相容性防線通過**）；pin TLHC → `TEXTURE_LAYER_HYBRID_COMPOSITION`；
  pin HCPP → `HYBRID_COMPOSITION_PLUS_PLUS`。
- **[Phase 2 實測，風險大幅低於預期]** **未 opt-in 的 app 行為完全不變**——移除 example
  manifest 的 `EnableHcpp` 後，`support=false` → AUTO 解析為 TLHC。由於絕大多數使用端不會
  opt-in，這次預設變更對他們是零影響。
- **[Phase 2 修正假設]** manifest 的 `EnableHcpp` **對 debug build 一樣生效**，不限 release
  ——不帶任何 intent extra 從 launcher 啟動 debug APK 仍得到 `support=true`。
  先前「manifest 路徑只走 release」的假設不成立。
- **[Phase 2 方法論]** 引擎的 `Using HCPP platform view rendering strategy` log **每個 process
  只印一次**，無法歸屬到個別 WebView。曾據此誤判 AUTO 沒走到 HCPP；改以套件內暫時儀器直接
  印出解析結果才取得可靠證據（儀器已於驗證後移除）。
- **[Phase 1 方法論]** `flutter analyze lib/`（於 example）**涵蓋不到套件原始碼**——
  重構後遺漏的 `context` 參數是 `flutter build` 編譯時才被抓到。套件端的正確性檢查須以編譯為準。

- **[Q1]** 不新增 `AUTO` 列舉成員，以 `null`／不設代表 auto——改動最小；新增一個「不是真正
  合成模式」的列舉值會讓語義變混，且 auto 既然是預設，需要明確表達的情境罕見。
- **[Q2]** auto 模式下支援度未知時**延後建立 WebView 直到探測完成**——只有這樣才能保證
  每次都真的用到 HCPP。採 A 會讓「有沒有吃到 HCPP」取決於 App 啟動時序，而預設值最不該
  具備的性質就是不可預測。代價（一個 channel 往返 + 一兩幀 placeholder）只發生在
  「auto 且未探測完成」的路徑上。
- **[Q3]** 不另提供全域逃生門——明確指定 `TEXTURE_LAYER_HYBRID_COMPOSITION` 已是逐 WebView
  的細粒度控制，足以回退。
- **[Q4]** 完整重跑一輪實機驗證——這是預設值變更，影響所有未設定的使用端，風險等級等同
  上一次 HC → TLHC 的翻預設，沿用該計畫的驗收清單。


### 驗證涵蓋範圍與限制

- **正面驗證**：實體 Android 16 平板（model 25097RP43G）。AUTO 模式下渲染、捲動、
  `keyboardAvoidance`（注音輸入法 composing、候選字列、焦點框保持可見）、長按選單、
  影片播放（`currentTime` 7.51 → 8.53，`advanced=true`）皆正常。
- **退回路徑**：U2（API 29）AUTO → TLHC，頁面與影片正常、無崩潰；平板移除 opt-in 後
  AUTO → TLHC。
- **相容性**：四種設定寫法逐一以套件內儀器驗證解析結果，全部符合規格。
- **未驗證**：延後建立造成的第一幀 placeholder 未做視覺確認（僅確認 WebView 未被建立兩次）；
  `InAppBrowser` 與 headless 不經 platform view，未實跑；其他平台未回歸。
- **裝置數量**：正面驗證僅一台實機，非裝置矩陣。

## Git Completion Policy

- Issue 綁定後，PR body 必須含 `Closes #${N}`（取自上方 `- Issue:`，**不是** `${ID}`），
  歸檔完成後於該 issue 張貼由 archive 蒸餾的結案留言 (Rule 20)。
- 經核准的 commit 之後，完成前會執行 `git rebase main` 與
  `git push --force-with-lease --force-if-includes`（`main` 由 `refs/remotes/origin/HEAD` 判定）。
- PR 請求會自動觸發歸檔與 wikification。
- 單一 repo，不涉及跨 repo PR。

## References

- 前置計畫：[2608200109-android-hcpp-mode](../../archive/2608200109-android-hcpp-mode.md)
  ——新增 HCPP 為可選模式，本計畫把它變成預設的自動選擇。該檔含 native 21 處分支的判定表、
  探測時序的坑、以及不可強制 `ImpellerBackend=vulkan` 的實測結論。
- 前置計畫：[2608191735-webview-render-perf](../../archive/2608191735-webview-render-perf.md)
  ——上一次的預設值變更（HC → TLHC），其 Phase 5 實機驗證清單可作為本計畫 Q4 的範本。
- 現有 Wiki 節點：[android-platform-view-composition](../../wiki/features/android-platform-view-composition.md)
- 現有 Wiki 節點：[keyboard-avoidance](../../wiki/features/keyboard-avoidance.md)
  ——合成模式決定 `InputAwareWebView` 的 IME 代理路徑是否啟用，是預設值變更的最高風險面。
