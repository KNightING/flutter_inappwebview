# Windows 視圖幾何與 texture 更新

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)

## Summary

Windows 的 WebView2 畫面走 texture，尺寸與位置由 Flutter 端主動上報到一個不可見的宿主
HWND。本頁說明這兩條路徑目前的行為：texture 只在有新影格時才複製，而幾何上報**刻意保留
重複**——那些看似多餘的重送其實是 WebView2 尚未就緒時的重試機制。宿主視窗的其他職責見
[Windows WebView 焦點模型](windows-webview-focus.md)。

## texture 只在 dirty 時複製

`TextureBridge` 在基底類別持有「自上次取用後有無新影格」的旗標，`OnFrameArrived()` 取得
未被 fps limit 丟棄的影格時設起。GPU 與 fallback 兩條路徑都只在 dirty（或目標 surface
尚未建立）時才執行 `ProcessFrame`：

- `texture_bridge_gpu.cc` 的 `GetSurfaceDescriptor()`：整張全尺寸 `CopyResource` + `Flush`
- `texture_bridge_fallback.cc` 的 `CopyPixelBuffer()`：`pixel_buffer_` 為空時強制處理

沒有這道判斷時，Flutter 每次取用 texture 都會做一次全螢幕複製，即使影格根本沒更新。

## 幾何上報：重複是刻意的

> [!CAUTION]
> **不要對 `_reportSurfaceSize` / `_reportWidgetPosition` 全面去重。** 實測結果是
> WebView 整片空白。
>
> 根因：`custom_platform_view.cc` 的 `setSize` handler 同時負責 `texture_bridge_->Start()`
> 與 `put_Bounds`，而 `InAppWebView::setSurfaceSize` 在 `webViewController` 尚未建立時會
> 直接 return。初期那幾次「重複」的上報，實際上是等 controller 就緒的重試。去掉它們，
> texture 就永遠不會 Start。

### 位置上報的作用對象

`setPosition` 移動的是**宿主 HWND**，不是畫面——頁面內容由 texture 呈現，與這個座標無關。
它唯一的作用是決定 WebView2 自繪彈出物（`<select>` 下拉、右鍵選單、自動填入、IME 候選字
視窗）的落點。

宿主是 FlutterView 的 `WS_CHILD` 子視窗，因此 `SetWindowPos` 收的是**相對 parent client
area 的座標**，與 Dart 端上報的 widget 位置同一個原點，不需要轉換為螢幕座標、也沒有標題列
或邊框要扣。

## 幾何上報的去重範圍

目前只有 `onPointerDown` 這一條路徑做去重（`_reportGeometryIfMoved()`）——它是純粹因應
使用者互動而重送的，值未變時沒有任何理由再走一次 `put_Bounds` + `SetWindowSize`。
生命週期與初始化路徑一律照送。

## 已知限制

- **視窗縮放時網頁內容會被短暫拉伸**。texture 先被縮放到新的 widget 尺寸，WebView2
  重新排版後的新影格才跟上。此為**上游既有行為**，已在未套用任何本 fork 改動的基準版上
  重現，非本 fork 造成。

## References

- 歸檔計畫：[2608191735-webview-render-perf](../../archive/2608191735-webview-render-perf.md)
- 同檔案的另一條路徑（輸入合成）：[Windows 捲動輸入](windows-scroll-input.md)

---

[📈 專案](../../project.md) | [🏠 Wiki](../index.md)
