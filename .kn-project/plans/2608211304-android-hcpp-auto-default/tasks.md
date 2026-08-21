# Tasks for 2608211304

> 邏輯改動極小（單一運算式），風險集中在「這是預設值變更」本身，
> 因此 Phase 2 的驗證份量遠大於 Phase 1。

## Phase 1 — 實作與文件

- [x] `in_app_webview.dart` 的 `_resolveCompositionMode()`：else 分支由 TLHC 改為
      `isHybridCompositionPlusPlusSupported ? HCPP : TLHC`
- [x] auto 且支援度未知時**延後建立 WebView**：先給 placeholder，探測完成後才建立。
      **只在此路徑等待**——明確指定模式或探測已完成一律直接建立
- [x] 確認延後建立**不會**造成 WebView 被建立兩次或 remount——以記憶化 future +
      `initialData` 短路，且 auto 模式下 `FutureBuilder` 恆留在樹中，樹形不變
- [x] `androidCompositionMode` 欄位文件：說明 null／不設的新語義為 auto、如何強制 TLHC，
      以及 auto 路徑可能延後第一個 WebView 的建立
- [x] `AndroidCompositionMode` 類別層文件：說明預設為自動選擇
- [x] 以 build_runner 同步 `.g.dart`
- [x] **確認 `useHybridComposition` 的預設值與型別未被更動**（Java 端 unboxing NPE 防線）
- [x] `flutter analyze` 通過；**另以 `flutter build` 驗證套件原始碼**
      （analyze 只涵蓋 example 自己的 lib，重構遺漏的 `context` 參數是編譯才抓到）

## Phase 2 — 實機驗證（依 Q4 決議）

> 預設值變更影響所有未設定的使用端，風險等級等同上一次 HC → TLHC 的翻預設。

- [x] **不設任何欄位**時確實走 HCPP（Android 16 平板，app 已 opt-in）
- [x] **不設任何欄位**時在不支援的裝置退回 TLHC（U2 / API 29），正常渲染、無白畫面
- [x] `androidCompositionMode: TEXTURE_LAYER_HYBRID_COMPOSITION` 仍能強制 TLHC
- [x] `useHybridComposition: true`（deprecated）仍走 HC —— **相容性防線**
- [x] auto 走到 HCPP 時：渲染、捲動、導覽
- [x] auto 走到 HCPP 時：**`keyboardAvoidance` 正常**（最高風險項）
- [x] auto 走到 HCPP 時：長按選單、文字選取、影片播放
- [x] app **未** opt-in 時（無 `EnableHcpp`、無 `--enable-hcpp`）確實走 TLHC
      —— 順帶補上前一計畫未實證的推論

## Phase 3 — 收尾

- [x] 逐項覆核未超出 `## Impact Files` 所列範圍
- [x] 更新 `plan.md` 的 `- Status:` 與 `- Completed:`
- [x] 驗證涵蓋範圍與限制寫入驗收紀錄

### Phase 2 驗證紀錄（2026-08-21）

| 設定寫法 | 解析結果 | 預期 |
| :--- | :--- | :--- |
| 不設任何欄位（平板，已 opt-in） | `HYBRID_COMPOSITION_PLUS_PLUS` | ✅ |
| 不設任何欄位（平板，**未** opt-in） | `TEXTURE_LAYER_HYBRID_COMPOSITION` | ✅ |
| 不設任何欄位（U2 / API 29） | `TEXTURE_LAYER_HYBRID_COMPOSITION` | ✅ |
| `useHybridComposition: true` | `HYBRID_COMPOSITION` | ✅ 相容性 |
| pin TLHC | `TEXTURE_LAYER_HYBRID_COMPOSITION` | ✅ |
| pin HCPP | `HYBRID_COMPOSITION_PLUS_PLUS` | ✅ |

AUTO（走到 HCPP）下的功能驗證：渲染、捲動、`keyboardAvoidance`（注音 composing 正常）、
長按選單、影片播放（`advanced=true`）皆正常。U2 退回 TLHC 後同樣正常、無崩潰。
