<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# flutter_inappwebview

`pichillilorenzo/flutter_inappwebview` 的 fork，供 KNightING 自有專案以 **git 依賴**方式使用，
**不發佈至 pub.dev**。

fork 的目的不是追隨或改造上游，而是**把使用端反覆重造的原生行為收進套件**——最先處理的是
軟鍵盤避讓：那件事需要同時掌握「鍵盤高度」與「WebView 的原生視圖」，兩者都只有套件層拿得到，
放在模板或 App 層必然重複實作且互相打架。

## 保留鐵則

- **本 fork 不回貢上游，純為自用。** 不對 `pichillilorenzo/flutter_inappwebview` 發 PR、
  不以「上游會不會接受」作為設計考量。所有變更只服務 KNightING 自有專案的需求。
- **delta 要保持極小**：本 fork 於 2026-08-11 與上游 master 零分歧（同為 `17527cae5`）。
  這個狀態是刻意維持的資產——上游前進時**拉取**是 fast-forward，不是衝突解決。
  **注意此鐵則的動機是「讓拉取上游更新保持廉價」，與回貢無關**（見上一條）。
  任何「順手改一下」都在花掉這筆資產，需個別評估而非順手為之。
- **不改套件名、不改命名空間、不改 JS 橋接名**。維持 `flutter_inappwebview_*` 讓使用端的
  `import` 與網頁的 `window.flutter_inappwebview` 零遷移；改名會立刻讓上述零分歧優勢失效。
  此決定的完整比對見本檔末的「為何不是 zikzak fork」。
- **不發佈 pub.dev**：使用端一律以 `git:` + `path:` 依賴引用。若有 transitive 依賴從 pub.dev
  拉 `flutter_inappwebview`，使用端需以 `dependency_overrides` 收斂。
- **PR 一律指向 `KNightING/flutter_inappwebview`**：本 repo 是 GitHub 上 `pichillilorenzo` 的
  正式 fork，`gh pr create` **預設會指向 parent**——誤射會把變更送進他人的公開 repo。
  每次開 PR 前仍應確認目標 repo。

## 每台開發機首次 clone 後必做

下列設定都存於**該 clone 的 `.git/config`**，不隨 GitHub 帳號、也不隨 repo 傳遞。
在別台機器設過**不算數**，新機器一律要重做一次；兩項皆曾因此在實際作業中失效。

- [ ] **收斂 `gh` 的 PR 目標**，否則 `gh pr create` 會指向上游 parent：

  ```bash
  gh repo set-default KNightING/flutter_inappwebview
  ```

  驗證：`gh repo set-default --view` 應回報 `KNightING/flutter_inappwebview`。

- [ ] **接上 `upstream` remote**，否則任何 `git diff upstream/master` 的 delta 檢查會直接失敗：

  ```bash
  git remote add upstream https://github.com/pichillilorenzo/flutter_inappwebview.git && git fetch upstream
  ```

  注意 **上游主幹為 `master`，本 fork 為 `main`**，同步時分支名不同。

## Architecture

Federated plugin，一份 app-facing 套件 + 各平台實作 + 共用介面：

| 套件 | 職責 |
| :--- | :--- |
| `flutter_inappwebview` | app-facing 入口，使用端只依賴這一個 |
| `flutter_inappwebview_platform_interface` | 平台無關的介面與設定物件（`InAppWebViewSettings` 等） |
| `flutter_inappwebview_android` | Android 實作（Java，命名空間 `com.pichillilorenzo.flutter_inappwebview_android`） |
| `flutter_inappwebview_ios` / `_macos` / `_windows` / `_linux` / `_web` | 其餘平台實作 |
| `dev_packages/flutter_inappwebview_internal_annotations` | 程式碼產生用註記 |
| `dev_packages/generators` | 程式碼產生器 |

新增一個跨平台設定的路徑固定為：`platform_interface` 宣告 → 各平台實作解析 → app-facing 套件透傳
（`platform_interface` 另有 `.g.dart` 產生檔需一併更新）。

### Android 的 WebView 層次

`FlutterWebView`（`public class`，`implements PlatformWebView`）
→ `InAppWebView`（`final public class`）
→ `InputAwareWebView`（`public class`，**非 final**）
→ `android.webkit.WebView`。

`InputAwareWebView` 未被 final 修飾，是掛 window insets 監聽最自然的位置。

### 平台基準

- AGP 8.13.1；`compileSdk` 取 `flutter.compileSdkVersion`（跟隨 Flutter SDK，非硬寫）；`minSdkVersion 19`。
- iOS / macOS **同時**提供 `Package.swift`（SPM）與 `.podspec`（CocoaPods），兩者並存。
- AGP 9.0 尚未導入——若後續 Flutter SDK 要求，需自行升級。

### JS 橋接名稱

注入於網頁的全域物件名**是執行期可設定的**，非寫死常數：
`JavaScriptBridgeJS.set_JAVASCRIPT_BRIDGE_NAME()` / `get_JAVASCRIPT_BRIDGE_NAME()`，
Android / iOS / macOS 三平台的宣告皆位於各自的 `plugin_scripts_js` / `PluginScriptsJS`
目錄下的 `JavaScriptBridgeJS`。預設值 `flutter_inappwebview`，使用端的
`window.flutter_inappwebview.callHandler(...)` 依此。

## 待移植（來自 `KNightING/camelot_inappwebview`）

該 fork（`arrrrny/zikzak_inappwebview` 的下游）已停止作為開發基底，但有三項上游沒有、
本專案需要的東西待移植：

- **Windows virtual host mappings** — 繞過本地 CORS，約 414 行，跨 `platform_interface`
  與 `_windows` 兩個套件。
- **`ZikZakSecurityManager`** — 憑證釘選、HTTPS-only、fetch/XHR 請求攔截，661 行（Android）。
  移植時需重新命名（不沿用 ZikZak 字樣）。
- **macOS popup window 修正** — `window.open` 的 popup 視窗與事件遞送。移植前需先確認上游是否已修。

## 為何不是 zikzak fork（2026-08-11 決策）

曾以 `KNightING/camelot_inappwebview`（`arrrrny/zikzak_inappwebview` 下游）為基底，實測比對後改用本 repo：

| 項目 | zikzak fork | 本 repo |
| :--- | :--- | :--- |
| 與上游分歧 | 大幅改寫，同步即大規模衝突 | **零分歧** |
| AGP | 8.5.2 | 8.13.1 |
| `compileSdk` | 硬寫 36 | 跟隨 Flutter SDK |
| CocoaPods | **無 podspec**（已移除，SPM-only） | podspec 與 SPM 並存 |
| JS 橋接名 | 寫死 `final`，macOS 宣告誤置於 `FindInteractionJS.swift` | 執行期可設定，三平台位置一致 |
| 使用端遷移 | 需改依賴、`import`、JS 全域名 | **零遷移** |

軟鍵盤避讓所需的錨點（`InputAwareWebView` / `InAppWebView` / `InAppWebViewSettings`）兩邊相同，
改用本 repo 無工作損失。
