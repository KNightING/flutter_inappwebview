<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608121003 - 升級至 AGP 9.3.0 / Gradle 9.5.0

- Created: 2026-08-12
- Issue: N/A（無 issue 追蹤基準——本 repo 為 fork，GitHub Issues 已停用）
- Branch: `feature/2608121003-agp-9-upgrade`（尚未建立）
- Status: Planning
- Completed: [Wait for Finish]

## Goals

把 Android 建置工具鏈由 AGP 8.13.x / Gradle 8.13 升級至 **AGP 9.3.0 / Gradle 9.5.0**，
並清掉隨之過時的 `build.gradle` 寫法。

本計畫**只做工具鏈升級**，不夾帶任何行為變更。

## Architecture

### 版本落差與 Flutter 的相容性判定（實測，非推論）

| 位置 | 現值 | 目標 |
| :--- | :--- | :--- |
| `example/android/settings.gradle` 的 AGP（**實際生效**） | 8.13.2 | 9.3.0 |
| 套件 `android/build.gradle` 的 classpath AGP（宣告用） | 8.13.1 | 9.3.0 |
| 兩個 example 的 Gradle wrapper | 8.13 | 9.5.0 |

AGP 9.3.0 依 Android 官方文件最低需要 Gradle 9.5.0，故兩者必須同時升。

**Flutter 3.44.8 的判定**（取自本機 SDK 原始碼 `packages/flutter_tools/lib/src/android/gradle_utils.dart`）：

- `maxKnownAndSupportedGradleVersion = '9.3.1'`（`:85`）
- `maxKnownAndSupportedAgpVersion = '9.1'`（`:98`）
- `maxKnownAgpVersionWithFullKotlinSupport = '9.0.1'`（`:104`）

但 `:807` 的分支對「比已知版本新」的 AGP 是**放行**的：

```dart
if (isWithinVersionRange(agpV, min: maxKnownAndSupportedAgpVersion, max: '100.100')) {
  // Assume versions we do not know about are valid but log.
  final bool validGradle = isWithinVersionRange(gradleV, min: '9.1.0', max: '100.00');
  return validGradle;
}
```

AGP 9.3.0 落入此分支，Gradle 9.5.0 在 `[9.1.0, 100.00]` 內，因此**版本檢查會通過**。
`maxKnownAndSupportedGradleVersion` 只作用於已知 AGP 版本的分支，管不到這裡。

### 已知代價（不是待決項，是要記住的事實）

目標版本**超出 Flutter 實際驗證過的範圍**。`flutter create` 於本機 Flutter 3.44.8 產生的是
**AGP 9.0.1 + Gradle 9.1.0**，且 9.0.1 正是 `maxKnownAgpVersionWithFullKotlinSupport` 的值。
選擇 9.3.0 等於採用 Flutter 字面上「不認得、姑且當它有效」的組合，風險自行承擔。
此為使用者於 2026-08-12 明確指定，已於提出時揭露。

已知的正面證據：本套件的 Java 原始碼**已在 AGP 9.0.1 + Gradle 9.1.0 下建置成功**——
軟鍵盤避讓計畫所用的 `kb_probe` 探針即由 `flutter create` 產生，完整編譯了本套件。
因此「原始碼相容 AGP 9.x」不是待驗證項，剩下的風險集中在建置腳本語法與 Flutter Gradle plugin。

### Kotlin 版本

example 的 `settings.gradle` 現宣告 `org.jetbrains.kotlin.android` 2.2.20，
Flutter 3.44.8 的模板用 2.3.20。AGP 9.x 對 Kotlin 版本有下限要求，可能需一併升，待 Phase O 實測。

## Cross-Repo Scope

無（單一 repo）。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-12 在 `main` 上實際確認。

### 既有 — 實際生效的 AGP 宣告
- `flutter_inappwebview/example/android/settings.gradle:21` — `id "com.android.application" version '8.13.2'`。
  **這才是 example 建置時生效的 AGP**，非套件 classpath 那個。
- `flutter_inappwebview_android/example/android/settings.gradle` — 同性質（行號待確認）。

### 既有 — Gradle wrapper
- `flutter_inappwebview/example/android/gradle/wrapper/gradle-wrapper.properties` — `gradle-8.13-all.zip`。
- `flutter_inappwebview_android/example/android/gradle/wrapper/gradle-wrapper.properties` — 同上。

### 既有 — 套件的宣告值與已棄用寫法
- `flutter_inappwebview_android/android/build.gradle:11` — `classpath 'com.android.tools.build:gradle:8.13.1'`。
- `flutter_inappwebview_android/android/build.gradle:37` — `minSdkVersion 19`，已棄用，應為 `minSdk`。
- `flutter_inappwebview_android/android/build.gradle:43` — `lintOptions { }`，已棄用，應為 `lint { }`。
- `flutter_inappwebview_android/android/build.gradle:29` — `compileSdk = flutter.compileSdkVersion`，**已是新寫法，不需動**。

### 既有 — 兩個 example 的已棄用寫法
- `flutter_inappwebview/example/android/app/build.gradle:33,39,40` —
  `compileSdkVersion` / `minSdkVersion` / `targetSdkVersion`，應為 `compileSdk` / `minSdk` / `targetSdk`。
- `flutter_inappwebview_android/example/android/app/build.gradle:33,39,40` — 同上。

### 新增
- 無（本計畫不新增功能檔案）。

## Open Questions / 待確認事項

### Q1. 可建置基準從哪裡來 — 影響：本計畫能否開始
`main` 上的兩個 example **本來就建不起來**：`enableJetifier=true` 搭配未使用的
`com.android.support:multidex:1.0.3`，會讓 Jetifier 改寫 Flutter engine jar 時
`Java heap space`（實測 6m23s 失敗）。該修復 commit `1c12f440f` **只存在於
`feature/2608111609-webview-keyboard-avoidance` 分支**。

沒有可建置的基準就無法歸因——升級後失敗到底來自 AGP 9.3、Gradle 9.5，還是本來就壞的 Jetifier，
會分不清。這與該計畫 Phase O 停下來的理由相同。

- [ ] A. 從軟鍵盤分支 cherry-pick `1c12f440f` 的 example 建置修復部分：
  取得可建置基準，且不把軟鍵盤功能拉進來。代價是兩條分支各有一份相同修改，合併時需處理。
- [x] B. 先把軟鍵盤分支合併進 `main`，再從 `main` 切 AGP 分支：歷史最乾淨，但軟鍵盤計畫的
  D 階段（掉幀量測、三條關閉路徑、轉向、內部捲動容器）尚未執行，現在合併等於跳過驗證。
- [ ] C. 直接從軟鍵盤分支切出 AGP 分支：立即可用，但兩個計畫的變更會混在同一條線上，
  違反「只做工具鏈升級、不夾帶行為變更」的自我約束。

狀態：✅ 已確認（2026-08-12 執行完畢）

軟鍵盤分支已以 `--no-ff` 併入 `main`（merge commit `fd238abac`），本分支自新的 `main` 切出。
**代價已實現且必須記住**：`main` 上現有一個預設開啟、Phase D 未驗證的功能。該計畫維持
`In Progress` 未歸檔，其 `plan.md` 開頭已載明未完成清單。本計畫不承接那些驗證。

### Q2. AGP 9.3.0 若實測失敗，退到哪一版 — 影響：失敗時的處置
目標超出 Flutter 驗證範圍，實測撞牆的可能性不低。

- [x] A. 退到 AGP 9.0.1 + Gradle 9.1.0：`flutter create` 產生的組合，已知可建置本套件。
- [ ] B. 退到 AGP 9.1 + Gradle 9.3.1：Flutter `maxKnownAndSupported` 的上限。
- [ ] C. 停下回報，不自行退版，由使用者決定。

狀態：✅ 已確認

退版是**授權的自動行為**，但仍須逐項回報實測結果與退版理由——不得只回報「已升級」而略過
「目標版本失敗、實際落在 9.0.1」這件事。退版後也不再自行嘗試 B 或其他中間組合。

## Key Decisions

- **目標訂為 AGP 9.3.0 / Gradle 9.5.0**（來源：使用者於 2026-08-12 指定）。已於提出時揭露它超出
  Flutter 驗證範圍三個小版本，使用者確認後採用。
- **範圍含已棄用寫法清理**（來源：使用者於 2026-08-12 指定）。`lintOptions`、`minSdkVersion`、
  `compileSdkVersion`、`targetSdkVersion` 一併改為新寫法。
- **先合併軟鍵盤分支再開始**（來源：Q1）。理由：本計畫需要可建置的 example 才能歸因，
  而該修復只在該分支上。代價是 `main` 上多了一個未完成驗證的功能，已於該計畫記錄。
- **失敗時自動退到 AGP 9.0.1 + Gradle 9.1.0**（來源：Q2）。理由：那是 `flutter create` 產生、
  且已知能建置本套件的組合。退版須回報，不得隱含在「已升級」的結論裡。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- AGP 版本相容表：`https://developer.android.com/build/releases/about-agp`
- 本機 Flutter SDK 的版本判定：`packages/flutter_tools/lib/src/android/gradle_utils.dart`
- 相鄰計畫：`.kn-project/plans/2608111609-webview-keyboard-avoidance/`（基準修復的來源）
