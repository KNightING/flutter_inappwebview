# 2608201704 - windows-webview-focus

- Created: 2026-08-20 17:04 / Archived: 2026-08-20
- Issue: KNightING/flutter_inappwebview#18

## Summary

Windows 上點擊網頁 `input` 後焦點會在 WebView2 與 FlutterView 之間互搶的問題已修正，WebView2 現在真正持有 Win32 焦點。

外顯是兩個症狀——第二下點擊焦點消失、`input` 聚焦時應用程式視窗標題列變灰——但成因是兩層。其一，`InAppWebViewManager::createInAppWebView` 以 `dwStyle = 0` 建立宿主 HWND，Win32 在沒有 `WS_CHILD` 時只把 `hWndParent` 當 owner，視窗仍是頂層的，WebView2 對它 `SetFocus` 就連帶停用 Flutter 主視窗。其二，composition controller 模式下 `SendMouseInput` / `SendPointerInput` 不含焦點語意，宿主必須自行呼叫 `MoveFocus`，而這個外掛從未呼叫過——先前「第一下有效」靠的正是第一層那個 bug 的副作用。影響範圍限於 `flutter_inappwebview_windows` 的 native 層，Dart 端與 headless 路徑未動。

## Cross-Repo Scope

無（單一 repo）。

## Key Decisions

- **[Q1]** 宿主 HWND 只加 `WS_CHILD`、不加 `WS_VISIBLE` — 理由：可見子視窗會疊在 FlutterView 之上攔截滑鼠訊息，破壞 Flutter 端的輸入合成路徑；隱藏視窗仍可持有 Win32 焦點與 IME，而畫面本來就走 texture。實機驗證中文輸入法 composing 與候選字位置正常，此決策成立。
- **[Q2]** 以實機手動驗證，不另建 harness — 理由：焦點與視窗啟用行為無法以自動化測試涵蓋。
- **[Q3]** 每次 pointer down 都無條件 `SetFocus` + `MoveFocus` — 理由：兩者皆為冪等操作，成本可忽略；加條件判斷等於自行維護一份必然與 Win32 真實狀態漂移的焦點狀態。
- **[執行中]** `WS_CHILD` 在迭代一未回退 — 理由：宿主若仍是頂層視窗，對它 `SetFocus` 會把整個視窗切走，等於把標題列變灰的症狀重新做回來。兩層修正互為前提。
- **[Phase 0]** 不動 `custom_platform_view.dart` 那段 50ms 延遲重試 `requestFocus` — 理由：上游程式碼，屬症狀補丁；根因修掉後成為無害的 no-op，主動刪除只會擴大與上游的 delta。
- **[Phase 0]** Headless 路徑不納入範圍 — 理由：其宿主視窗建立後立即 `SW_HIDE`，隱藏視窗無法被啟用，不產生本問題。

## Deviations

原計畫只有「加 `WS_CHILD` + 修 `setPosition` 座標」一層。實機驗證後確認它只解掉「視窗標題列變灰」，「第二下點擊失焦」仍在，因而追加迭代一（`moveFocusToWebView()` 與兩條 pointer down 路徑的接線）。追加的原因記於本檔 Summary 第二段：第一層修正拿掉了先前偶然提供焦點的副作用，暴露出「焦點從未被交付」這個一直存在的缺口。

## Impact Files

- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview_manager.cpp:126` (`InAppWebViewManager::createInAppWebView`) — `CreateWindowEx` 的 `dwStyle` 由 `0` 改為 `WS_CHILD`。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp` (`InAppWebView::setPosition`) — 改用 parent client 座標，移除 `GetWindowRect` 與 `SM_CYCAPTION` / `SM_CXBORDER` / `SM_CXPADDEDBORDER` 的扣算；`plugin` 不再被使用，guard 隨之收斂為只檢查 `webViewController`。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp` (`InAppWebView::moveFocusToWebView`) — 新增；`::SetFocus(宿主 HWND)` 後呼叫 `MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC)`。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.cpp` (`InAppWebView::setPointerButtonState`, `InAppWebView::setPointerUpdate`) — 兩條 pointer down 路徑在送出輸入事件**之前**呼叫 `moveFocusToWebView()`，讓頁面內的元素焦點仍由 WebView2 自行決定。
- `flutter_inappwebview_windows/windows/in_app_webview/in_app_webview.h` — `moveFocusToWebView()` 宣告。
