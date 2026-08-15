# 2608152118 - windows-trackpad-scroll

- Created: 2026-08-15 21:18 / Archived: 2026-08-15 23:58
- Issue: KNightING/flutter_inappwebview#12

## Summary

Windows 觸控板捲動「單向無反應且不流暢」的根因是**兩軸交錯送出**，已修復。
`setScrollDelta` 原本只要 `dx != 0.0` 就先送 `HORIZONTAL_WHEEL` 再送垂直的；觸控板幾乎每幀
都帶微小水平分量，交錯的事件讓 Chromium 把整段序列當成水平捲動、丟掉垂直位移。
另一個方向之所以正常，純粹因為該方向的 `dx` 恰好為 0.000。

修法是**每個手勢鎖定一次主導軸**（非逐幀），判定放在 Dart 端（手勢起訖只有那裡知道），
原生 `setScrollDelta` 因此維持上游原樣。同時修正水平軸方向（`-dx`、`+dy`），並補上三個
源碼可證但非本次症狀的缺陷：殘量累加器、`short` 溢位飽和、手勢邊界重置。
影響範圍限於 `flutter_inappwebview_windows`，滑鼠滾輪路徑行為不變。

## Cross-Repo Scope

無（單一 repo）。使用端 `nuxt-flutter-app` 目前未釘 `flutter_inappwebview_windows`，
本修復要在該 App 生效需新增第四個 `dependency_overrides` 並讓四個 `ref` 同步發 tag，由使用者處理。

## Key Decisions

- **不採用原需求清單的 R1（乘 `WHEEL_DELTA` 120）**：兩路徑共用 `sendScroll`，照做會讓滑鼠
  120 倍速；滑鼠實測正常即證明現有比例近似正確。
- **軸判定放在 Dart 端**：手勢起訖只有 Dart 知道，且讓原生端維持上游原樣，delta 更小。
- **軸鎖定以「每手勢一次」而非逐幀**：逐幀會讓次要軸偶然勝出的那些幀被送錯軸、位移逐幀漏失，
  實測表現為「距離偏小」。鎖定門檻為累積位移 3px，鎖定前的位移一併補送。
- **水平取負、垂直不取負**：兩軸的 wheel 語意不一致（垂直正值＝畫面往上，水平正值＝畫面往右），
  而 `panDelta` 兩軸皆為「內容跟著手指走」。
- **不修 `lastCursorPos_`**：其前提（手勢期間座標停滯）被實測推翻，不加已證偽的死程式碼。
- **慣性與斜滑兩軸不在本計畫**：合成滾輪先天做不到，需改走 `SendPointerInput`，另開迭代。

## Deviations

- **原需求清單的多數假設被實機量測推翻**，逐項如下（這是本計畫最主要的偏離）：

  | 假設 | 判定 | 依據 |
  | :--- | :--- | :--- |
  | R1 乘 120 | 推翻 | 共用 `sendScroll`，會讓滑鼠 120 倍速 |
  | R2 截斷歸零 | 推翻 | 實測 `dy` 為 10–166 px，非 0.3–3 |
  | R4 座標停滯 | 推翻 | `lastCursorPos` 每筆皆等於 `localPosition` |
  | 觸控板垂直應取負 | 推翻 | 誤讀使用者回報所致，實機驗證取負會反向 |
  | 原生端吃掉負值 | 推翻 | 1227 筆 `SendMouseInput` 全部 `S_OK`，`-138.9 → -139` 完整送達 |
  | 兩軸交錯送出 | **成立** | 關閉水平送出後兩方向皆正常（單一變因實驗） |

- **Q2 決議未實作**：其前提 R4 被推翻，依 Q3 的決議不加已證偽的死程式碼。
- **C5 未執行**：`scrollMultiplier` 設 3 / 200 的溢位驗證需手改 example 設定重建，且非本次症狀。
  程式碼層面已夾在 `short` 值域內，但**未經實測**，不得視為已驗證。
- **執行過程中一度把三個檔案的換行由 LF 改成 CRLF**（Python 文字模式在 Windows 的預設行為），
  使 diff 膨脹到 5171 增 / 5040 刪。已於 commit 前還原為 LF，實際改動為 135 行。

## Impact Files

- `flutter_inappwebview_windows/lib/src/in_app_webview/custom_platform_view.dart`
  — `_latchPanAxis` 與 `_panAxis` / `_panTravel` 狀態（軸鎖定），`onPointerPanZoomStart/Update/End`
  三個處理器，水平取負。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp:3800`
  — `sendScroll` 的殘量累加與溢位飽和；`resetScrollRemainder` 實作。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.h:253`
  — `scrollRemainderX_` / `scrollRemainderY_` 成員與 `resetScrollRemainder` 宣告。
- `flutter_inappwebview_windows/windows/custom_platform_view/custom_platform_view.cc`
  — `resetScrollRemainder` 的 method channel 接線。

## Details

**環境前置條件（值得記住）**：`flutter_inappwebview_windows` 的建置需要 `nuget` 在 PATH 上
（`windows/CMakeLists.txt:26` 的 `find_program(NUGET nuget)`）。本機的 `nuget.exe` 位於使用者的
`tools` 目錄，但該目錄不在 user 或 machine 的 PATH，導致不繼承慣用終端機環境的情境
（例如 agent session）直接失敗於 `NUGET-NOTFOUND`，且 CMake 會快取該結果、需清掉
`example/build/windows` 才會重新偵測。建議補進 `project.md` 的每機清單。

**後續工作**：慣性與斜滑同時捲兩軸需改走 `SendPointerInput`（基礎設施已存在：
`InAppWebView::setPointerUpdate` 與 Dart 端 `_setPointerUpdate`，目前用於觸控螢幕），
讓 Chromium 走原生 fling。**風險**：頁面收到的會變成 `touchstart/touchmove` 與
`pointerType: touch`，網站可能切換為行動版互動，故應以設定項閘控、預設維持現行 wheel 路徑。

**macOS 無對照實作**：macOS 用 `AppKitView`，WKWebView 是視圖樹中真正的原生 view，
AppKit 直接派送 `NSEvent`，`InAppWebView.swift` 連 `scrollWheel` 都未覆寫。整套合成輸入
只有 Windows 需要——WebView2 以 composition 模式繪製到 texture，不在 hit-test 樹中。
