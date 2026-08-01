# airlock v4

`airlock` 是一個 Bash-first 的輕量安裝框架，核心目標是把「安裝流程」與「安裝記錄」標準化，讓你可以用簡單 recipe 管理兩類軟體：

- `managed/*`：由 airlock 產生 staged 檔案，最後 commit 到實際系統。
- `tracked/*`：由外部套件管理器或安裝命令完成安裝，airlock 只做流程編排與記錄追蹤。

本專案強調：

- 配方（recipe）可讀性
- 明確的生命週期邊界
- 小而清楚的 helper API
- 不做大型抽象或重量級依賴

---

## 1. 程式目的

airlock 解決的是「重複安裝腳本難以維護」的問題。它提供：

- 一致的安裝階段（acquire/prepare/...）
- 一致的記錄格式（`meta.env`, `files.txt`, `created_dirs.txt`）
- 一致的查詢命令（`list`, `info`, `files`）
- 一致的移除路徑（managed record-driven、tracked backend-driven）
- 可選 hooks，讓 recipe 在關鍵邊界做少量整合工作

---

## 2. 代碼結構設計

### 2.1 目錄結構

- `bin/airlock`：CLI 入口
- `lib/*.sh`：框架核心模組
- `recipes/*/recipe.sh`：內建配方
- `tests/`：no-sudo smoke tests

### 2.2 模組職責

- `lib/config.sh`：環境變量讀取與預設值
- `lib/env.sh`：每次安裝執行環境（`WORKDIR`, `STAGE_DIR`, `PREFIX`）
- `lib/pipeline.sh`：依 `pkg_mode/pkg_type` 決定 stage pipeline 並執行
- `lib/defaults.sh`：預設 stage / tracked 行為
- `lib/validate.sh`：recipe metadata 驗證
- `lib/commit.sh`：managed commit 到真實檔案系統
- `lib/record.sh`：安裝記錄落盤
- `lib/remove.sh`：remove 流程（managed/tracked）
- `lib/core.sh`：高層流程調度（install/remove/list/info/files）
- `lib/utils.sh`：內部低階工具（internal）
- `lib/simple_helper.sh`：recipe-facing helper API（給 recipe 作者）

### 2.3 Helper 邊界（重要）

- `utils.sh`：低階內部工具，不建議 recipe 直接依賴
- `simple_helper.sh`：recipe 應優先使用的 API

常見 recipe API：

- 下載/解壓/依賴：
  - `al_fetch_cached_url`
  - `al_fetch_url_uncached`
  - `al_extract_archive_for_recipe`
  - `al_require_recipe_cmd`
- Git 來源：
  - `al_git_checkout_repo`
  - `al_git_checkout_repo_with_submodules`
- Stage 安裝：
  - `al_stage_install_file`
  - `al_stage_install_dir`
  - `al_stage_install_wrapper`
  - `al_stage_install_cmd_wrapper`
  - `al_stage_install_icon`
  - `al_stage_write_desktop_entry`
- Tracked 整合：
  - `al_tracked_install_deb_with_apt`
  - `al_install_text_file_with_optional_sudo`
  - `al_remove_file_with_optional_sudo`

---

## 3. 資料流處理（Install / Record / Remove）

### 3.1 Install 高層資料流

1. 解析 recipe 路徑（名稱或檔案路徑）
2. 載入 recipe（`source` 到當前 shell）
3. 驗證 metadata（`pkg_name`, `pkg_version`, `pkg_mode`, `pkg_type`）
4. 建立執行環境（`WORKDIR`, `STAGE_DIR`, `PREFIX`）
5. 執行 pipeline stages
6. 依 mode 分流：
   - managed：`commit -> record -> hook_post_commit`
   - tracked：`track_install -> record -> hook_post_install`

### 3.2 記錄資料（DB）

安裝記錄位於：`$AIRLOCK_DB_ROOT/packages/<pkg_name>/`

- `meta.env`：核心 metadata（mode/type/prefix/time/recipe_dir 等）
- `files.txt`：managed 安裝產生的檔案與 symlink 絕對路徑
- `created_dirs.txt`：managed commit 時由 airlock 建立的目錄

### 3.3 Remove 資料流

- 先讀取 `meta.env`
- 依 `pkg_mode` 分流：
  - managed：
    - 逐條刪除 `files.txt` 記錄檔案
    - 從 file parent directories 向上嘗試 prune
    - prune 條件必須同時滿足：
      - 目錄為空
      - 非 protected dir
      - 該目錄存在於 `created_dirs.txt`（歸屬約束）
  - tracked：
    - 若有 `track_query_cmd` 且回報未安裝：只刪記錄
    - 否則執行 `track_remove_cmd`（或 backend fallback）

> 注意：remove semantics 是保守策略，不會做全域空目錄清理。

---

## 4. 安裝編譯生命週期

### 4.1 Pipeline 選擇

`lib/pipeline.sh` 目前定義：

- `managed/source`：`acquire prepare patch configure build stage`
- `managed/artifact`：`acquire prepare patch configure stage`
- `tracked/source`：`acquire prepare patch configure build`
- `tracked/artifact`：`acquire prepare patch configure`

### 4.2 每個 stage 的意圖

- `stage_acquire`：下載/抓源碼/取得 artifact
- `stage_prepare`：設定 `SRCDIR`, `BUILDDIR`，解壓、整理目錄
- `stage_patch`：可選 patch
- `stage_configure`：configure/meson/cmake 前置
- `stage_build`：編譯或產生可安裝輸出
- `stage_stage`：僅 managed 用，把檔案放入 `STAGE_DIR$PREFIX/...`

---

## 5. Hooks（全部可用鉤子）

airlock v4 支援以下可選 hooks：

- `hook_post_commit`
  - 僅 managed install
  - 時機：`commit` 與 `record` 成功後
- `hook_post_install`
  - 僅 tracked install
  - 時機：backend 安裝與 `record` 成功後
- `hook_pre_remove`
  - managed/tracked 都可
  - 時機：remove 實際開始前
- `hook_post_remove`
  - managed/tracked 都可
  - 時機：remove 成功完成後

規則：

- hook 不定義：視為正常
- hook 定義且返回非 0：流程失敗
- hook 在當前 shell 執行，可用 recipe 共享變量

---

## 6. 環境變量意義

可覆寫環境變量：

- `AIRLOCK_PREFIX`（預設 `/usr/local`）
  - managed stage/commit 的安裝前綴
  - tracked recipe 也常拿來決定整合檔位置
- `AIRLOCK_DB_ROOT`（預設 `/var/airlock_db`）
  - 安裝記錄根目錄
- `AIRLOCK_RECIPES_DIR`（預設 `<repo>/recipes`）
  - recipe 搜尋目錄
- `AIRLOCK_TMPDIR`（預設 `/tmp/airlock`）
  - 暫存與 cache 根目錄
- `AIRLOCK_LOG_LEVEL`（預設 `info`）
  - 日誌等級
- `AIRLOCK_LOG_FILE`（預設空）
  - 若設置則寫檔
- `AIRLOCK_FORCE`（預設 `0`）
  - install `--force` 會跳過 commit conflict check
- `AIRLOCK_UI_COLOR`（預設 `1`）
  - CLI 顏色開關
- `AIRLOCK_PROTECTED_DIRS_EXTRA`（remove 時可用）
  - 額外 protected dirs（`:` 分隔）

---

## 7. managed / tracked 的假設

### 7.1 managed 假設

- 真實安裝內容由 `stage_stage` 產生到 `STAGE_DIR`
- commit 之後才算真正落地到系統
- 可透過 `files.txt + created_dirs.txt` 可逆移除
- 適合：你能明確控制安裝檔案集合的場景

### 7.2 tracked 假設

- 真實安裝由 backend（例如 apt/dpkg）完成
- airlock 記錄 backend 相關命令與 metadata
- remove 主要透過 `track_remove_cmd` 或 backend fallback
- 適合：你不想重包裝，只想統一流程與追蹤資訊

---

## 8. source / artifact 的假設

### 8.1 source

- 來源通常是 git/tarball source tree
- 需要 configure/build（可選）
- managed/source 需要 `stage_stage`

### 8.2 artifact

- 來源是已產生的可安裝產物（AppImage、binary、.deb 等）
- pipeline 預設不強制 build
- managed/artifact 仍需 `stage_stage` 來放置 staged 檔
- tracked/artifact 通常在 `track_install` 直接交給 backend

---

## 9. 如何寫自己的 recipe（完整指南）

### 9.1 最小必要欄位

每個 recipe 至少要有：

- `pkg_name`
- `pkg_version`
- `pkg_mode`（`managed` 或 `tracked`）
- `pkg_type`（`source` 或 `artifact`）

### 9.2 命名與位置

建議放在：

- `recipes/<name>/recipe.sh`

可用以下方式安裝：

- `airlock install <name>`
- `airlock install /abs/path/to/recipe.sh`

### 9.3 Recipe 變量慣例

由框架提供：

- `WORKDIR`：可重用 cache 工作目錄
- `STAGE_DIR`：managed 的 staging root
- `PREFIX`：等於 `AIRLOCK_PREFIX`
- `RECIPE_DIR`：當前 recipe 目錄

recipe 常設置：

- `SRCDIR`
- `BUILDDIR`

### 9.4 模板一：managed/source

```bash
#!/usr/bin/env bash

pkg_name="mytool"
pkg_version="1.2.3"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo "https://example.com/mytool.git" "$WORKDIR/$pkg_name" "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  cmake -S "$SRCDIR" -B "$BUILDDIR" -DCMAKE_BUILD_TYPE=Release
}

stage_build() {
  cmake --build "$BUILDDIR" -j4
}

stage_stage() {
  al_stage_install_file "$BUILDDIR/mytool" "bin/mytool" 755
}
```

### 9.5 模板二：managed/artifact

```bash
#!/usr/bin/env bash

pkg_name="myapp"
pkg_version="0.9.0"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url "https://example.com/myapp.AppImage" "$WORKDIR/$pkg_name/myapp.AppImage"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_file "$SRCDIR/myapp.AppImage" "opt/myapp/myapp.AppImage" 755
  al_stage_install_cmd_wrapper "myapp" "opt/myapp/myapp.AppImage"
}
```

### 9.6 模板三：tracked/artifact

```bash
#!/usr/bin/env bash

pkg_name="mypkg"
pkg_version="1.0.0"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="deb-apt"

DEB_URL="https://example.com/mypkg_1.0.0_amd64.deb"

stage_acquire() {
  al_fetch_url_uncached "$DEB_URL" "$WORKDIR/$pkg_name/$pkg_version.deb"
}

stage_prepare() {
  track_source_url="$DEB_URL"
  track_source_file="$WORKDIR/$pkg_name/$pkg_version.deb"
  export track_source_url track_source_file
}

track_install() {
  al_tracked_install_deb_with_apt "$track_source_file"
}

hook_post_install() {
  al_install_text_file_with_optional_sudo "/usr/local/bin/mypkg" 755 <<'INNER_EOF'
#!/usr/bin/env bash
exec /usr/bin/mypkg "$@"
INNER_EOF
}

hook_post_remove() {
  al_remove_file_with_optional_sudo "/usr/local/bin/mypkg"
}
```

### 9.7 Hook 使用建議

- `hook_post_commit`：managed 落地後做系統整合
- `hook_post_install`：tracked backend 成功後補整合檔
- `hook_pre_remove`：remove 前備份/檢查
- `hook_post_remove`：清理 hook 產生的外掛檔

### 9.8 寫 recipe 的實務原則

- 優先使用 `simple_helper.sh` 的 recipe API
- 盡量避免直接操作低階 internal utils
- `stage_stage` 只處理 `STAGE_DIR$PREFIX` 內容（managed）
- tracked 請明確維護 `track_*` metadata（query/install/remove）
- 任何 `hook_*` 失敗都會讓命令失敗，請顯式 `return 1`

---

## 10. CLI 使用

```bash
airlock install <recipe-name|recipe-path>
airlock install <recipe-name|recipe-path> --force
airlock remove <pkg-name>
airlock list [--time-asc|--time-desc]
airlock info <pkg-name>
airlock files <pkg-name>
airlock clean-cache <recipe-name|recipe-path>
```

---

## 11. 測試（no-sudo）

目前提供 smoke tests，特性：

- 全部在暫存目錄執行
- 顯式覆寫 `AIRLOCK_PREFIX`, `AIRLOCK_DB_ROOT`, `AIRLOCK_TMPDIR`
- 不碰真實系統

執行：

```bash
bash tests/smoke/test-managed-lifecycle.sh
```

---

## 12. 設計邊界與非目標

airlock 目前不是交易式套件管理器，不保證：

- 跨步驟 rollback
- 全域依賴解決
- 強一致多版本共存模型

它的定位是：

- 可維護的 Bash recipe 框架
- 可讀、可查、可移除的安裝記錄
- 以最小必要抽象統一 managed/tracked 工作流

