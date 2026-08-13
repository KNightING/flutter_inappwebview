# Tasks: keyboardAvoidance 在不支援 OS 版本上的 resizeToAvoidBottomInset 建議

計畫：`plan.md`（同目錄）

## Phase A — 撰寫警示
- [x] A1. 依 Q2 決議的措辭，在 `in_app_webview_settings.dart:1223` 的配對設定段補上警示，
      內容涵蓋三點：不支援版本上此建議**不成立**、照做的後果是**完全沒有避讓**（無錯誤、
      唯一線索是多數 ROM 會濾掉的 `Log.d`）、以及應採的做法（保留預設 `true` 或依 OS 版本設定）
- [x] A2. 版本界線明確寫出：Android 10 以下、iOS 17.1 以下（與其後既有的「Requires Android 11
      (API 30) / iOS 17.2 or above」段落互為正反面表述）
- [x] A3. 以產生器同步 `in_app_webview_settings.g.dart`（Q3 選項 A）：
      `dart run build_runner build` 於 `flutter_inappwebview_platform_interface` 執行，
      輸出**只**改到目標段落，無無關變更，故不需回退為手動同步

## Phase B — 驗證
- [x] B1. `git diff --stat` 確認變更僅限兩個檔案：各 +14/-2，純註解，無程式碼異動
- [x] B2. `.dart` 與 `.g.dart` 兩段註解逐字一致（由產生器產出，非手抄）
- [x] B3. `dart analyze` 兩個檔案 → `No issues found!`
- [x] B4. `git diff --stat upstream/master` 兩檔為 186 insertions / 1 deletion，
      維持「新增為主」的保留鐵則，本次未擴大改寫面

## Phase C — 收尾
- [ ] C1. Commit（Rule 17 逐項請示）
- [ ] C2. Phase 5 歸檔時，交由 `kn:project:wikification` 同步
      `.kn-project/wiki/features/keyboard-avoidance.md`（`:11` 與 `:60` 的同一處分離敘述）
