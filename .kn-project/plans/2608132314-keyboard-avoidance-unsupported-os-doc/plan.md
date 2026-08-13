<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2608132314 - keyboardAvoidance 在不支援 OS 版本上的 resizeToAvoidBottomInset 建議

- Created: 2026-08-13
- Issue: `KNightING/flutter_inappwebview#4`
- Branch: `docs/2608132314-keyboard-avoidance-unsupported-os-doc`
- Status: In Progress
- Completed: [Wait for Finish]

## Goals

補上目前文件缺的那一句：**`Scaffold.resizeToAvoidBottomInset: false` 只在 `keyboardAvoidance`
實際生效的 OS 版本上才是正確建議**。在 Android API 30 以下（或 iOS 17.2 以下）無條件照做，
會讓使用端變成「兩邊都沒人避讓」——比不設定這個選項還糟。

文件目前把兩件事分開講、從不連起來：

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1206`
  以粗體要求 **Set `Scaffold.resizeToAvoidBottomInset` to `false` as well.**，全文無版本條件。
- 同檔 `:1226`–`:1228` 才說「Requires Android 11 (API 30) or above… Below that the option is
  ignored. On iOS it requires 17.2 or above.」

讀者照著做，在舊機上就掉進缺口。本計畫要消滅的是這個缺口，不改任何執行期行為。

## Architecture

### 缺口的實際後果（2026-08-13 實機觀察，非推論）

裝置 U2（`01412420054591`，Android 10 / API 29，`adb shell getprop ro.build.version.sdk` = 29）
上執行使用端 App `nuxt-flutter-app`（該 repo 的 `flutter-host` 以 `dependency_overrides` 釘本
fork 的 tag `6.2.0-beta.3.2`），焦點輸入框完全不避讓。三個可能的執行者同時失效：

| 執行者 | 狀態 | 原因 |
| :--- | :--- | :--- |
| Flutter `Scaffold` resize | 關閉 | 使用端依本套件文件建議設 `resizeToAvoidBottomInset: false` |
| 套件原生避讓 | 未啟用 | API 29 < 30，`InputAwareWebView.java:91` 早退 |
| Chromium `ScrollFocusedEditableIntoView` | 無事可做 | 插邊未被攔（功能沒裝），但該頁 `html, body { height: 100dvh }`，document 捲不動 |

第 2 列是設計內行為，第 1 列是文件教的，兩者相加即為缺口。套件端無法從程式修正——
`resizeToAvoidBottomInset` 是 Flutter framework 依 engine `viewInsets` 做的 layout，
與套件攔截的原生插邊是兩條獨立通道（此結論為既有歸檔計畫
`.kn-project/archive/2608111609-webview-keyboard-avoidance.md` 的實測結論，本計畫沿用未重測）。
**能修的只有文件。**

### 方案

在 `keyboardAvoidance` 的 Dart doc comment 內，把「配對設定」與「最低版本」兩段**連起來**：
於配對設定那段補一則警示，明確指出支援範圍外的行為與應採的做法（保留預設 `true`，
或依 OS 版本條件式設定）。位置選在配對設定那段而非最低版本那段，因為犯錯的動作發生在前者。

`in_app_webview_settings.g.dart` 是產生檔且**逐字鏡射**該註解（`:1336`–`:1344` 可見同一段文字），
必須一併同步，否則兩份文件當場分歧。前例 `f047c111e` 即同時修改這兩個檔案。

不改任何程式邏輯、不新增設定項、不動原生端。

## Cross-Repo Scope

無（單一 repo）。

> 使用端 `nuxt-flutter-app` 的對應調整由使用者自行處理（2026-08-13 明示），不納入本計畫，
> 也不在本 repo 產出對應計畫。

## Impact Files

路徑相對本 repo 根目錄。錨點皆於 2026-08-13 在同步後的 `main`（`3e4453785`）實際確認。

### 既有

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1206`
  — `///**Set \`Scaffold.resizeToAvoidBottomInset\` to \`false\` as well.**` 起始的段落，
  警示要補在此處（緊接其後、掉幀數據表格之前或之後，見 Q2）。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.g.dart:1336`
  — 產生檔內同一段註解的鏡射，需一併同步（`bool? keyboardAvoidance;` 於 `:1344`）。

### 佐證備註

- 版本閘的實際位置：
  `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InputAwareWebView.java:91`
  — `if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) { Log.d(...); return; }`，
  早退前只記 `Log.d`，不安裝監聽器、不建立 `KeyboardAvoidanceController`。
- 該 `Log.d` 在測試裝置 U2 上**看不到**（ROM 濾掉 debug 層級；以 `adb shell log -p d` 打測試訊息
  同樣不顯示）。使用端因此連「功能沒啟用」的線索都拿不到——這是把警示寫進文件而非只靠 log 的理由。
- 本 repo 的 `.kn-project/wiki/features/keyboard-avoidance.md:11` 與 `:60` 有同樣的分離敘述
  （前者要求 `resizeToAvoidBottomInset: false`，後者才列最低版本）。Wiki 的修正依 Rule 7 由
  `kn:project:wikification` 於 Phase 5 處理，**不在 Phase 3 就地改**。

## Open Questions / 待確認事項

### Q1. 是否同時新增「避讓實際是否生效」的回報 API — 影響：範圍與 delta
使用端目前無法在執行期得知原生避讓有沒有真的啟用：`keyboardAvoidance` 傳 `true` 進去，
API 29 上靜默不啟用，`getSettings()` 讀回來仍是 `true`。若要讓「條件式設定
`resizeToAvoidBottomInset`」不必由使用端自己查 OS 版本，套件需暴露實際生效狀態。

- [x] A. **只寫文件**（建議）：本計畫維持純文件，使用端以 `Platform` / `deviceInfo` 自行判版本。
  範圍最小、上游 delta 不增加，且使用者已表明 App 端自行處理。
- [ ] B. 文件 + 新增回報 API（例如 `isKeyboardAvoidanceActive()`）：使用端不必重複套件的版本知識，
  但屬行為/API 變更，需新增平台通道與三平台實作，delta 明顯變大，應另開計畫而非夾帶。

狀態：✅ 已確認（2026-08-13，使用者授權由執行者決定，採建議選項）

### Q2. 警示的措辭強度 — 影響：文件語氣
- [x] A. **`> [!WARNING]` 等級的明確警示**（建議）：直接寫出「在不支援的版本上兩邊都不會避讓，
  比不開這個選項更糟」。缺口的後果是功能完全消失且無錯誤訊息，值得最強的措辭。
- [ ] B. 平述一句附加說明：語氣與現有 doc comment 一致，但容易被略過——現況正是「有寫、但分開寫」
  導致被略過。

狀態：✅ 已確認（2026-08-13，同上）

> 實作註記：dartdoc 不支援 GitHub 的 `> [!WARNING]` alert 語法，故以既有註解慣用的
> **粗體開頭句**承載同等強度（同檔其他警示段落亦為此形式），語意採 A、標記形式從既有慣例。

### Q3. `.g.dart` 的同步方式 — 影響：執行步驟
- [x] A. **跑產生器重新產生**（建議，若可跑）：`dev_packages/generators` 為本 repo 的產生器，
  重新產生可保證與手寫來源一致。需先確認該產生器可在本機執行且不會順帶改動其他無關輸出。
- [ ] B. 手動同步該段註解：確定只動目標段落，零附帶變更，但需自行確保逐字一致。

狀態：✅ 已確認（2026-08-13，同上）——先試 A，若產生器輸出含無關變更則回退為 B 並於此註記

## Key Decisions

- **範圍限定為本 repo 的文件**（來源：使用者於 2026-08-13 指定「我會去獨立修改那個 APP，
  但是 resizeToAvoidBottomInset 這個 true 的建議請你寫起來」）。理由：使用端修改由使用者自理，
  本 repo 的責任是讓文件不再誤導下一個讀者。
- **警示補在「配對設定」段而非「最低版本」段**（來源：Phase 0 佐證）。理由：犯錯的動作發生在
  讀到配對設定那句的當下；把條件寫在 20 行後的另一段，正是現況失效的原因。
- **Wiki 不在 Phase 3 就地改**（來源：Rule 7）。理由：Wiki 內容由 `kn:project:wikification`
  單一所有，於 Phase 5 歸檔時同步。
- **不新增「避讓是否生效」的回報 API**（來源：Q1）。理由：使用端已自行處理，純文件的範圍最小
  且不增加與上游的 delta；該 API 屬行為變更，若日後需要應另開計畫，不夾帶進文件修正。
- **警示採最強措辭，但沿用既有註解的粗體慣例**（來源：Q2）。理由：後果是功能靜默消失、
  連 `Log.d` 都被 ROM 濾掉，值得最強語氣；而 dartdoc 不吃 GitHub alert 語法，故形式從既有慣例。
- **`.g.dart` 優先以產生器同步**（來源：Q3）。理由：該檔逐字鏡射來源註解，產生器可保證一致；
  僅在輸出含無關變更時才回退為手動同步。

## Git Completion Policy

Commit 前逐項請示（Rule 17）。任務完成前將以 `git rebase main` 後
`git push --force-with-lease --force-if-includes` 更新遠端工作分支——此動作會**重寫遠端歷史**。

**開 PR 前必須確認目標 repo 為 `KNightING/flutter_inappwebview`**：本 repo 是
`pichillilorenzo/flutter_inappwebview` 的 GitHub fork，`gh pr create` 預設指向 parent。

## References

- 歸檔計畫：`.kn-project/archive/2608111609-webview-keyboard-avoidance.md`
  （本功能的完整設計、兩平台機制差異、`resizeToAvoidBottomInset` 的掉幀量測）
- 本 repo Wiki：`.kn-project/wiki/features/keyboard-avoidance.md`
- 前例 commit：`f047c111e` — `docs(android): recommend pairing keyboardAvoidance with
  resizeToAvoidBottomInset false`，即本計畫要補條件的那一段的來源，同時修改 `.dart` 與 `.g.dart`
