# Tasks: 升級至 AGP 9.3.0 / Gradle 9.5.0

> 進 Phase 3 前需先結清 plan.md 的 Open Questions（Q1 基準來源、Q2 失敗退版策略）。
> Q1 未決前**無法開始**——沒有可建置的基準就無法歸因。

## Phase O — 已知良好基準
- [ ] O1. 依 Q1 決議取得可建置的 example（`main` 上的 example 因 Jetifier OOM 本來就建不起來）
- [ ] O2. 升級前先建置兩個 example 並記錄耗時，作為比對基準
- [ ] O3. 記錄目前的 Kotlin 版本與 `flutter doctor` 輸出，供失敗時歸因

## Phase A — Gradle wrapper
- [ ] A1. 兩個 example 的 `gradle-wrapper.properties` 由 `gradle-8.13-all.zip` 改為 `gradle-9.5.0-all.zip`
- [ ] A2. 只升 Gradle、不動 AGP，先單獨建置一次——分離變因，確認 Gradle 9.5 本身不是問題來源

## Phase B — AGP
- [ ] B1. 兩個 example 的 `settings.gradle` 的 `com.android.application` 版本改為 9.3.0
- [ ] B2. 套件 `flutter_inappwebview_android/android/build.gradle:11` 的 classpath 改為 9.3.0
- [ ] B3. 依實測結果決定 Kotlin 版本是否需一併升（現為 2.2.20，Flutter 模板為 2.3.20）
- [ ] B4. 建置驗證；失敗則依 Q2 決議處置，**不自行嘗試其他版本組合**

## Phase C — 已棄用寫法清理
- [ ] C1. `flutter_inappwebview_android/android/build.gradle:43` `lintOptions` → `lint`
- [ ] C2. `flutter_inappwebview_android/android/build.gradle:37` `minSdkVersion` → `minSdk`
- [ ] C3. 兩個 example 的 `app/build.gradle:33,39,40`
      `compileSdkVersion`／`minSdkVersion`／`targetSdkVersion` → `compileSdk`／`minSdk`／`targetSdk`
- [ ] C4. 逐項改完各建置一次，不要一次全改——這些是獨立的語法替換，混在一起失敗難歸因

## Phase D — 驗證
- [ ] D1. 兩個 example 皆可建置，並與 O2 的耗時基準比對
- [ ] D2. 實機執行 `flutter_inappwebview/example`，確認可啟動且無 FATAL
- [ ] D3. 確認 `flutter build apk --release` 亦可通過（release 走 minify，AGP 升級最容易在此出事）
- [ ] D4. 檢查建置輸出是否有新的 deprecation 警告，有則記錄不逕自處理

## Phase E — delta 檢查（本 repo 特有）
- [ ] E1. `git diff upstream/master` 確認變更範圍未逸出計畫
- [ ] E2. 開 PR 前確認目標 repo 為 `KNightING/flutter_inappwebview`，不是 parent
