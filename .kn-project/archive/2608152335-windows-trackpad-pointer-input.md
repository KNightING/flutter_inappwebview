# 2608152335 - windows-trackpad-pointer-input

- Created: 2026-08-15 23:35 / Archived: 2026-08-16
- Issue: KNightING/flutter_inappwebview#14

## Summary

Windows 的觸控板手勢改以**合成觸控**（`SendPointerInput`）交給 WebView2，不再翻譯成滾輪事件，
因而取得慣性與斜滑同時捲動兩軸——兩者都是滾輪路徑先天做不到的（滾輪事件不帶速度與手勢階段，
且一次只能表達一個軸；Windows 的觸控板慣性事件流也未送達 Flutter）。

實作接的是套件既有、原本服務於觸控螢幕的 pointer input 管線：`panZoomStart` → `down`、
`panZoomUpdate` → `update`（座標＝起點＋累積 `pan`）、`panZoomEnd` → `up`。
**淨效果是程式碼減少 32 行**：軸鎖定與 `resetScrollRemainder` 整組管線因此失去存在意義而刪除；
殘量累加器與溢位飽和保留，因為滑鼠滾輪仍走 `sendScroll`。無新增設定項。

## Cross-Repo Scope

無（單一 repo）。使用端 `nuxt-flutter-app` 需新增第四個 `dependency_overrides`（目前未釘
windows）並讓四個 `ref` 指向同一個新 tag；發 tag 為本計畫的收尾工作，使用端調整屬該 repo。

## Key Decisions

- **改走 `SendPointerInput` 而非自行合成衰減**：自行合成拿不到斜滑兩軸，且我們的衰減曲線
  會疊在 Chromium 自己的平滑捲動動畫上，變成兩層緩動、難以調準。
- **不加設定項閘控**（推翻計畫原本的決策）：閘控的唯一論據是「網站可能切成行動版」，
  實測顯示 hover、拖曳與四項裝置能力查詢在兩條路徑下完全相同。留下開關的代價是一條必須
  永遠維護與測試的第二路徑。**接受的代價**：真撞到「收到 `touchstart` 就切行動版」的網站時，
  需改套件並重發 tag，而非改一行設定。
- **一併刪除軸鎖定與 `resetScrollRemainder`**：前者是滾輪路徑「一次只能表達一個軸」的補償，
  觸控路徑天生支援二維捲動；後者的唯一呼叫者是手勢邊界。留著即為死程式碼。
- **`scrollMultiplier` 不套用於觸控路徑**：放大位移等於偽造手指移動，會讓 Chromium 算出
  失真的速度與慣性。改以 doc comment 註明其僅作用於滾輪路徑。

## Deviations

- **設定項 `useTrackpadPointerInput` 曾完整實作（Dart 宣告、`.g.dart`、原生欄位／解析／
  回傳 map、Dart 端分流）並通過驗證，最後整個移除。** 歷程：依原決議實作為預設開啟 →
  使用者質疑「為什麼需要這個參數」→ 擴充測試頁做雙輪對照 → 實測推翻閘控論據 → 移除。
- **連帶刪除前一計畫（`2608152118`）剛交付的軸鎖定機制。** 那份工作並非白費：它查出
  「兩軸交錯會被 Chromium 吃掉」，而該認識正是選擇觸控路徑的依據之一。
- **範圍擴充：windows example 補上 `dependency_overrides`**。發現於回歸測試建置失敗——
  windows example 先前解析的是 pub 上的 platform_interface，**無法驗證任何新設定**；
  android 與 ios 的 example 早已有此覆寫，屬既有不一致。
- **C6（真實觸控螢幕不受影響）未執行**：手邊無觸控螢幕裝置。程式碼層面觸控螢幕走
  `onPointerDown/Move/Up` 且 pointer id 取自事件本身，與手勢路徑不共用狀態，但**未經實測**。

## Impact Files

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart`
  — `onPointerPanZoomStart/Update/End` 改送 `_setPointerUpdate`；刪除 `_latchPanAxis`、
  `_panAxis`、`_panTravel`、`_panAxisLockThreshold` 與 `_resetScrollRemainder`。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp`
  — 刪除 `resetScrollRemainder` 實作；殘量累加器註解改寫為僅描述滾輪。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.h`
  — 刪除 `resetScrollRemainder` 宣告。
- `flutter_inappwebview_windows/windows/custom_platform_view/custom_platform_view.cc`
  — 刪除該 method channel 的接線。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart`
  — `scrollMultiplier` 的 doc comment 註明僅作用於滾輪路徑（`.g.dart` 同步產生）。
- `flutter_inappwebview_windows/example/pubspec.yaml`
  — 新增指向本地 platform_interface 的 `dependency_overrides`。

## Details

**雙輪對照的完整結果（2026-08-16）**，測試頁含純 CSS `:hover`、Pointer Events 拖曳、
原生 HTML5 draggable 與裝置能力查詢：

| 項目 | 滾輪路徑 | 觸控路徑 |
| :--- | :--- | :--- |
| CSS `:hover` | 正常 | 正常 |
| Pointer Events 拖曳 | 正常 | 正常 |
| 原生 HTML5 draggable | 禁止游標 | 禁止游標 |
| `maxTouchPoints` / `ontouchstart` / `hover:hover` / `pointer:coarse` | 不變 | 不變 |

那些能力值反映的是實體裝置能力，不是收到的事件種類。

**原生 HTML5 拖放在兩種路徑下皆不可用**——composition 模式的 WebView2 需另接 OLE drop target，
套件未實作。屬既有限制，與本計畫無關，但值得記錄以免日後誤判為回歸。

**後續**：發 tag（與 `2608152118` 一併），供使用端 `nuxt-flutter-app` 釘用。
