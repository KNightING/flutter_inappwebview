# Tasks for 2608140054
- [x] Phase 0：重現建置失敗並完成根因診斷（Code Evidence Scan，錨點見 plan.md）
- [x] Phase 3：建立遠端分支 `fix/2608140054-macos-spm-deployment-target` 並切換（Remote First）
- [x] Phase 3：建立 GitHub Issue 並回填 `- Issue:` 欄位
- [x] Phase 3：調用 `kn:project:code-style` 後修改 `Package.swift`（10.14 → 10.15）
- [x] Phase 3：依 Q1 決議修改 `.podspec`（10.14 → 10.15）
- [x] Phase 4：`flutter build macos --debug` 建置成功
- [x] Phase 4：啟動 example app（`flutter run -d macos`）並實際操作 WebView 驗證（載入 flutter.dev、導航 example.com、事件面板記錄 onLoadStop/onTitleChanged）
- [ ] Phase 4：經核准的 commit 後執行 rebase + `--force-with-lease --force-if-includes` 更新遠端
