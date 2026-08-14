# 2608132314 - keyboard-avoidance-unsupported-os-doc

- Created: 2026-08-13 23:14 / Archived: 2026-08-13 23:59
- Issue: KNightING/flutter_inappwebview#4

## Summary

`keyboardAvoidance` 的文件補上條件：`Scaffold.resizeToAvoidBottomInset: false` 只在該選項
實際生效的 OS 版本上才是正確建議。原文件以粗體無條件要求配對設定，最低版本要求則寫在
20 行之後的另一段，兩者從不連起來；使用端照做，在 Android 10 以下或 iOS 17.1 以下就會
**兩邊都沒人避讓**——framework 被要求收手，套件根本沒站起來，焦點欄位直接被鍵盤蓋住。

2026-08-13 於 U2（Android 10 / API 29）實機證實此後果，且該情境靜默無訊號：不擲例外，
唯一線索是原生端的 `Log.d`，而測試裝置的 ROM 濾掉該層級。**套件端無法從程式修正**——
`resizeToAvoidBottomInset` 是 Flutter framework 依 engine `viewInsets` 的 layout，與套件攔截的
原生插邊是兩條獨立通道，能修的只有文件。本次為純註解變更，零執行期行為改動。

## Cross-Repo Scope

無（單一 repo）。使用端 App（`nuxt-flutter-app`）的對應調整由使用者自行處理，不納入本計畫。

## Key Decisions

- **範圍限定為本 repo 的文件**：使用端修改由使用者自理，本 repo 的責任是讓文件不再誤導下一個讀者。
- **警示補在「配對設定」段而非「最低版本」段**：犯錯的動作發生在讀到配對設定那句的當下；
  把條件寫在 20 行後的另一段，正是現況失效的原因。
- **不新增「避讓是否生效」的回報 API**（Q1）：使用端已自行處理，純文件範圍最小且不增加上游 delta；
  該 API 屬行為變更，若日後需要應另開計畫，不夾帶進文件修正。
- **警示採最強措辭，但沿用既有註解的粗體慣例**（Q2）：後果是功能靜默消失，值得最強語氣；
  而 dartdoc 不支援 GitHub 的 `[!WARNING]` alert 語法，故標記形式從既有慣例。
- **`.g.dart` 以產生器同步**（Q3）：該檔逐字鏡射來源註解，`build_runner` 可保證一致；
  實跑後輸出只改到目標段落、無無關變更，故未回退為手動同步。
- **Wiki 不在 Phase 3 就地改**（Rule 7）：Wiki 內容由 wikification 單一所有，於本階段同步。

## Deviations

- Q2 的選項寫的是 `> [!WARNING]` 等級警示，實作改以**粗體開頭句**承載同等語意——dartdoc 不吃
  GitHub alert 語法。語意採原決議，僅標記形式從既有註解慣例。
- Commit 後以 `--amend` 補上本 repo 慣用的 `Co-authored-by` trailer（分支尚未推送，無歷史影響）。

## Impact Files

- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart:1223`
  — 新增的警示段落，位於掉幀數據表格之後、最低版本要求之前。
- `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.g.dart:1318`
  — 產生檔內同一段註解的鏡射，由 `dart run build_runner build` 產出。

## Details

驗證紀錄：`dart analyze` 兩檔 `No issues found!`；`git diff --stat upstream/master` 兩檔為
186 insertions / 1 deletion，維持本 fork「新增為主」的保留鐵則。

版本閘的實作位置（未變更，供日後查閱）：
`flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InputAwareWebView.java:91`
—— `Build.VERSION.SDK_INT < Build.VERSION_CODES.R` 時記 `Log.d` 後早退，不安裝監聽器。

---

> [!IMPORTANT]
> **本檔記載的 Android 限制已於 2026-08-14 解除。** 當時的結論「API 30 以下套件完全不介入，
> 使用端必須讓 `resizeToAvoidBottomInset` 維持 `true`」在計畫
> [2608140927-keyboard-avoidance-pre-r](2608140927-keyboard-avoidance-pre-r.md) 中被實作推翻：
> 該區間改由 Dart 層轉交 framework 的鍵盤高度，套件同樣執行平移，且無須壓制 Chromium。
> 本檔的敘述保留為當時的歷史紀錄，**現行行為以 wiki 的
> [keyboard-avoidance](../wiki/features/keyboard-avoidance.md) 為準**。iOS 17.1 以下的限制不受影響，仍然成立。
