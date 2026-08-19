# Android 平台視圖合成模式

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)

## Summary

Android 的 WebView 以何種方式與 Flutter 畫面合成，由 `InAppWebViewSettings.useHybridComposition`
決定。**本 fork 的預設值為 `false`（TLHC），與上游的 `true`（Hybrid Composition）不同**。
此值只能於 `initialSettings` 指定，且會決定 `InputAwareWebView` 的 IME 代理路徑是否啟用。

## 兩種模式

| | `useHybridComposition: false`（本 fork 預設） | `useHybridComposition: true`（上游預設） |
| :--- | :--- | :--- |
| 名稱 | Texture Layer Hybrid Composition (TLHC) | Hybrid Composition (HC) |
| Flutter API | `PlatformViewsService.initSurfaceAndroidView` | `PlatformViewsService.initExpensiveAndroidView` |
| 合成方式 | WebView 繪製到 texture，由 Flutter 合成 | WebView 進入真實 view 階層，Flutter 內容改繪到 `FlutterImageView` |
| 成本 | Flutter 只付自己的合成 | **Flutter 需為畫在 WebView 之上的所有內容付出合成代價**，且 raster 與 platform 執行緒合併 |
| `InputAwareWebView` IME 代理 | **啟用** | 停用（兩處 `if (useHybridComposition) return;` 直接返回） |

TLHC 在不支援的裝置上會由 Flutter 引擎自動退回 HC，故翻預設不會讓任何裝置失去畫面。

## 為什麼本 fork 改了預設

HC 讓 Flutter 為 WebView 上方的每一層內容付出合成成本，那是每幀都在付、而多數使用情境並不需要的代價。
TLHC 沒有這條成本，也不需要合併 raster 與 platform 執行緒。

代價是啟用了一條在 HC 下休眠的路徑：`InputAwareWebView` 的 IME 代理。該路徑負責在 platform view
情境下把輸入法連線接回正確的 view，直接關係到 [軟鍵盤避讓](keyboard-avoidance.md) 能否運作。

## 三處預設值必須一致

翻動預設時三個字面值必須同步，只翻其中一處會讓「不傳設定」與「傳了部分設定」走到不同分支：

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart`
  ——建構子預設值（另有同步的 `.g.dart`）
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart`
  ——widget 端解析 `initialSettings` 時的 `?? false`
- `.../webview/in_app_webview/InAppWebViewSettings.java` ——native 欄位預設

## 已知限制

- **僅能於 `initialSettings` 指定**。合成模式在 platform view 建立當下就決定，之後
  `setSettings` 改不動。
- **與上游行為分歧**。從上游遷移過來、且依賴 HC 行為的使用端，需自行傳
  `useHybridComposition: true` 還原。
- **HCPP 尚未支援**。Flutter 另有 Hybrid Composition++（`initHybridAndroidView`，需 API 34+
  與 Vulkan），本套件目前未提供該選項。

## References

- 歸檔計畫：[2608191735-webview-render-perf](../../archive/2608191735-webview-render-perf.md)
- Flutter 官方說明：`https://docs.flutter.dev/platform-integration/android/platform-views`

---

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)
