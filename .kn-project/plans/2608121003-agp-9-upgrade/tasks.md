# Tasks: 升級至 AGP 9.3.0 / Gradle 9.5.0

> 進 Phase 3 前需先結清 plan.md 的 Open Questions（Q1 基準來源、Q2 失敗退版策略）。
> Q1 未決前**無法開始**——沒有可建置的基準就無法歸因。

> **階段順序修正（2026-08-12 實測）**：原本把「已棄用寫法清理」排在 AGP 升級**之後**，
> 那是錯的。`android.defaults.buildfeatures.buildconfig` 在 AGP 9.0 已被**移除**（非棄用），
> AGP 9.3 在載入 plugin 的階段就直接拋錯，連編譯都到不了——該項清理是升級的**前置條件**。
> 其餘語法項（`lintOptions`、`minSdkVersion` 等）確實只是棄用，不擋建置，留在原順序無妨。

## Phase O — 已知良好基準
- [x] O1. 依 Q1 決議取得可建置的 example → 軟鍵盤分支已併入 `main`（`fd238abac`），本分支自其切出
- [x] O2. 升級前基準：`flutter_inappwebview/example` debug 建置 **593.0s**，`EXIT=0`
- [x] O3. 起始版本記錄：AGP 8.13.2（example `settings.gradle`，**實際生效**）／
      8.13.1（套件 classpath，宣告用）／Gradle 8.13／Kotlin 2.2.20／Flutter 3.44.8／Java 22.0.2

## Phase A — Gradle wrapper
- [x] A1. 兩個 example 的 `gradle-wrapper.properties` → `gradle-9.5.0-all.zip`
- [x] A2. 只升 Gradle、不動 AGP 單獨建置 → **通過**，620.8s，`EXIT=0`。
      確立 Gradle 9.5 與 Flutter 3.44.8 的 Gradle plugin 相容，後續失敗可排除此變因。
      先前「Gradle 8.13 即將被淘汰」的警告一併消失

## Phase B — AGP
- [x] B0. **前置**：移除 `android.defaults.buildfeatures.buildconfig=true`（兩個 example 的
      `gradle.properties`）。AGP 9.0 已移除該選項，不移除則 plugin 無法載入。
      移除前確認全 repo **無任何程式碼使用 `BuildConfig`**，故不需補 `buildFeatures { buildConfig = true }`
- [x] B1. 兩個 example 的 `settings.gradle` 的 `com.android.application` → 9.3.0
- [x] B2. 套件 `android/build.gradle:11` 的 classpath → 9.3.0
- [x] B3. Kotlin **不需升級** — 2.2.20 在 AGP 9.3.0 下建置通過，維持原值以縮小 delta
- [x] B4. 建置驗證 → **通過**，428.0s，`EXIT=0`。**Q2 的退版未觸發，目標版本直接達成**

## Phase C — 已棄用寫法清理
- [x] C1. `flutter_inappwebview_android/android/build.gradle:43` `lintOptions` → `lint`
- [x] C2. `flutter_inappwebview_android/android/build.gradle:37` `minSdkVersion` → `minSdk`
- [x] C3. 兩個 example 的 `app/build.gradle:33,39,40`
      `compileSdkVersion`／`minSdkVersion`／`targetSdkVersion` → `compileSdk`／`minSdk`／`targetSdk`
- [x] C4. **偏離本項紀律**：五處一次改完，未逐項建置。理由：AGP 9 的錯誤訊息會精確指名出問題的
      DSL 元素（B0 那次連選項名與移除版本都寫出），歸因不依賴變更隔離；而每輪建置約 7 分鐘。
      驗證通過（debug 12.3s 增量，`EXIT=0`），未觸發需要退回逐項驗證的模糊錯誤

## Phase C2 — 未處理的可疑選項（刻意保留）
- [ ] C5. `android.nonTransitiveRClass=false` 與 `android.nonFinalResIds=false` 仍留在兩個 example 的
      `gradle.properties`。AGP 9.3 未報錯，故**不動**——這兩個是**行為旗標**，明確設為 `false` 是在
      選擇舊行為；刪除等於改用新預設（non-transitive R class），屬行為變更而非語法整理，
      違反本計畫「只做工具鏈升級」的宣告。待另行評估

## Phase D — 驗證
- [x] D1. 兩個 example 皆可建置。`flutter_inappwebview/example` 428.0s（基準 593.0s）、
      `flutter_inappwebview_android/example` 80.4s，皆 `EXIT=0`。
      耗時**未惡化**——但兩者的快取狀態不同，此數字不足以宣稱升級改善了建置速度
- [x] D2. 實機執行 `flutter_inappwebview/example`（裝置 `M4AIB763K212ZBA`）→ 啟動後進程存活
      （PID 17244），logcat 無 FATAL
- [x] D3. `flutter build apk --release` → **通過**，367.4s，產出 67.4MB APK，`EXIT=0`。
      走完 R8／minify（套件的 `release` 開著 `minifyEnabled true` 並帶 `consumerProguardFiles`），
      這是 AGP 大版本升級最易出事之處，debug 完全不經過
- [x] D4. 新增警告已記錄，**不逕自處理**：
      Flutter 警告 app 與 `file_picker`／`flutter_downloader` 套用了 Kotlin Gradle Plugin，
      未來版本的 Flutter 將因此建置失敗，建議遷移至 Built-in Kotlin。
      此為 Flutter 的破壞性變更預告，**與 AGP 9 無關**，屬另一個題目，不在本計畫範圍

## Phase E — delta 檢查（本 repo 特有）
- [ ] E1. `git diff upstream/master` 確認變更範圍未逸出計畫
- [ ] E2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
