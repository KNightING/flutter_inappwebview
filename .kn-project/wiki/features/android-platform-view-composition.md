# Android 平台視圖合成模式

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)

## Summary

Android 的 WebView 以何種方式與 Flutter 畫面合成，由 `InAppWebViewSettings.androidCompositionMode`
決定，三種模式為 TLHC、HC、HCPP。**不設此欄位時自動選擇**：HCPP 可用就用 HCPP，否則 TLHC。
舊的布林 `useHybridComposition` 仍可用但已 deprecated。此設定只能於 `initialSettings` 指定，
且會決定 `InputAwareWebView` 的 IME 代理路徑是否啟用。

## 三種模式

| | `TEXTURE_LAYER_HYBRID_COMPOSITION` | `HYBRID_COMPOSITION` | `HYBRID_COMPOSITION_PLUS_PLUS` |
| :--- | :--- | :--- | :--- |
| 慣稱 | TLHC | HC | HCPP |
| Flutter API | `initSurfaceAndroidView` | `initExpensiveAndroidView` | `initHybridAndroidView` |
| 合成方式 | WebView 繪到 texture，由 Flutter 合成 | WebView 進入真實 view 階層，Flutter 內容改繪到 `FlutterImageView` | 兩者各自繪到原生 Surface，由 SurfaceFlinger 合成 |
| 成本 | Flutter 只付自己的合成 | **Flutter 需為畫在 WebView 之上的所有內容付出合成代價**，且 raster 與 platform 執行緒合併 | 無上述兩項成本 |
| 額外需求 | 無 | 無 | **API 34+、Impeller on Vulkan、app 端 opt-in** |
| `InputAwareWebView` IME 代理 | **啟用** | 停用 | 停用（與 HC 同側） |

TLHC 在不支援的裝置上由 Flutter 引擎自動退回 HC。HCPP 在條件不滿足時由本套件退回 TLHC
（見下方「HCPP 的啟用與退回」），兩者都不會讓畫面消失。

> [!NOTE]
> Flutter 官方的 platform views 文件把 HC 與 TLHC 的 API 對應寫混了（宣稱 HC 用
> `initSurfaceAndroidView`）。上表以 Flutter 3.47 的
> `packages/flutter/lib/src/services/platform_views.dart` 為準。

## 設定方式

**什麼都不設就是自動選擇**——HCPP 可用時用 HCPP，否則 TLHC：

```dart
InAppWebView(
  initialSettings: InAppWebViewSettings(),
)
```

要固定某一種模式才需要指定。想明確排除 HCPP 就 pin TLHC：

```dart
InAppWebViewSettings(
  androidCompositionMode: AndroidCompositionMode.TEXTURE_LAYER_HYBRID_COMPOSITION,
)
```

優先順序：`androidCompositionMode` 非 null 時勝出；為 null 且 deprecated 的
`useHybridComposition` 為 `true` 時走 HC（既有程式碼行為不變）；兩者都未設才是自動選擇。

> [!NOTE]
> **自動選擇會等支援度探測完成才建立 WebView。** 合成模式在 platform view 建立當下就定死，
> 提早決定會讓「有沒有吃到 HCPP」取決於 App 的啟動時序。代價是每個 session 的**第一個**
> WebView 延後一個 platform channel 往返；之後的用快取答案、不延遲。明確指定模式則完全
> 不等待。

合成模式對 `InAppBrowser` 與 `HeadlessInAppWebView` **不適用**——它們不經過 platform view。

## HCPP 的啟用與退回

HCPP 需要三個條件同時成立，缺一即退回 TLHC：

1. **Android API 34+**
2. **Impeller 跑在 Vulkan 後端**（現代裝置上引擎會自行選用）
3. **App 端 opt-in**——套件無法代為開啟

opt-in 有兩條路徑，最終都落到引擎層的 `enable-hcpp-and-surface-control` switch：

| 情境 | 做法 |
| :--- | :--- |
| Release build | `AndroidManifest.xml` 加入 `io.flutter.embedding.android.EnableHcpp` = `true` |
| 開發期 | `flutter run --enable-hcpp`（隱藏旗標，`--help` 不會列出） |

> [!CAUTION]
> **不要為了 HCPP 而在 manifest 強制 `io.flutter.embedding.android.ImpellerBackend` = `vulkan`。**
> 舊裝置給不出有效的 Vulkan context，會造成**啟動即崩潰**
> （`Check failed: android_context_->IsValid()`，實測 Android 10 裝置）。
> Vulkan 後端的選擇交給引擎判斷即可。

支援度由引擎回答，而**問得太早會得到 `false`**：套件在 plugin 註冊時就先問一次，但那早於引擎
附著。因此只有正面結果會被快取，負面結果允許之後重問，並在每次建立 WebView 時順手重探。

要保證**第一個**建立的 WebView 就拿到 HCPP，可先 await：

```dart
await precacheHybridCompositionPlusPlusSupport();
```

## native 端只看「是否在真實 view 階層」

Java 端沒有三種模式的概念，只有一個布林 `useHybridComposition`，它在 native 被分支判斷
**21 處**。這些分支問的其實是同一件事：**WebView 是否位於真實 view 階層中、是否有 `containerView`**。

HCPP 在真實階層，與 HC 同側，因此 Dart 在 HCPP 模式下對 native 送 `useHybridComposition: true`。
分支可歸為四類：

| 類別 | 位置 | 非 hybrid（TLHC）時 |
| :--- | :--- | :--- |
| containerView 代理 | `FlutterWebView.java:67` / `:173` / `:179` / `:185` / `:192`、`InAppWebView.java:1712` / `:1766` / `:2236` | 以 FlutterView 作為 containerView 並代理 |
| IME 代理 workaround | `InputAwareWebView.java:209` / `:230` / `:271` / `:349`（**四處**） | 執行 workaround |
| 自訂浮動選單 | `InAppWebView.java:539` / `:651` / `:1746` / `:1755` | 用套件自建的浮動選單 |
| layer type | `InAppWebView.java:445` / `:1124` | 不設 `setLayerType` |

結構性佐證：多數 `!useHybridComposition` 分支另有 `containerView != null` 守衛，而 containerView
只在非 hybrid 時才非 null（`FlutterWebView.java:67`），兩道守衛由建構方式保證一致。

## 預設值必須三處一致

deprecated 的 `useHybridComposition` 有三個字面預設值，改動時必須同步，否則「不傳設定」與
「傳了部分設定」會走到不同分支：

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart`
  ——建構子預設值（另有同步的 `.g.dart`）
- `flutter_inappwebview_android/lib/src/in_app_webview/in_app_webview.dart` ——widget 端的 `?? false`
- `.../webview/in_app_webview/InAppWebViewSettings.java` ——native 欄位預設

## 已知限制

- **僅能於 `initialSettings` 指定**。合成模式在 platform view 建立當下就決定，之後
  `setSettings` 改不動。
- **與上游行為分歧**。上游預設 HC；從上游遷移且依賴 HC 行為的使用端，需自行指定
  `AndroidCompositionMode.HYBRID_COMPOSITION` 還原。
- **未 opt-in 的 app 不受自動選擇影響**。沒有宣告 `EnableHcpp`（或未以 `--enable-hcpp`
  執行）時支援度為 `false`，自動選擇一律得到 TLHC。
- **HCPP 的驗證涵蓋兩台裝置**（一台 Android 16 實機、一台 API 36 模擬器），非裝置矩陣。
  模擬器需強制 Vulkan 後端才走得到 HCPP，實機不需要。

## References

- 歸檔計畫：[2608191735-webview-render-perf](../../archive/2608191735-webview-render-perf.md)
  （預設改為 TLHC）、[2608200109-android-hcpp-mode](../../archive/2608200109-android-hcpp-mode.md)
  （新增 HCPP）、[2608211304-android-hcpp-auto-default](../../archive/2608211304-android-hcpp-auto-default.md)
  （預設改為自動選擇）
- 相關節點：[軟鍵盤避讓](keyboard-avoidance.md)——本頁的 IME 代理路徑直接關係到該功能
- Flutter 官方說明：`https://docs.flutter.dev/platform-integration/android/platform-views`
  （API 對應有誤，見上方註記）

---

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)
