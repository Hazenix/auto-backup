## Auto Backup (macOS / Linux) – Quick Guide

### 1. Overview

- **English**:  
  This folder contains a Bash script that automatically commits and pushes one or more Git repositories to GitHub on macOS / Linux.

- **中文**：  
  该目录下提供在 macOS / Linux 上使用的 Bash 自动备份脚本，可以定期执行 `git add/commit/push`。

---

### 2. Files

- **`auto_backup_unix.sh`**  
  - Main script.  
  - Reads configuration at the top (global options + repository list), then loops over all configured repositories and runs `git add/commit/push`.

- **`git_env.sh.example`**  
  - Example environment file, showing how to set `GIT_USERNAME` and `GIT_PASSWORD` (GitHub PAT).  
  - Copy it to `git_env.sh` and fill in your real values.  
  - `git_env.sh` is ignored by Git (see project `.gitignore`).

---

### 3. Basic Usage

1. **Create credentials file**
   - Copy example file:
     ```bash
     cp git_env.sh.example git_env.sh
     ```
   - Edit `git_env.sh` and set:
     - `GIT_USERNAME` – your GitHub username  
     - `GIT_PASSWORD` – your GitHub Personal Access Token (PAT)

2. **Configure repositories in `auto_backup_unix.sh`**
   - At the top of the script, adjust:
     - `REPO_INDEXES` – list of repository indices to back up (e.g. `("1")` or `("1" "2")`)  
     - For each index `N` (e.g. `1`):  
       - `REPO_DIR_N` – local repo path (e.g. `$HOME/code/demo-uniapp`)  
       - `GIT_BRANCH_N` – branch name (e.g. `main`)  
       - `GITHUB_OWNER_N` / `GITHUB_REPO_N` – GitHub owner and repo name

3. **Run manually**
   ```bash
   cd /path/to/auto-backup/local-backup/for_unix
   chmod +x auto_backup_unix.sh
   ./auto_backup_unix.sh
   ```

---

### 4. Schedule (optional)

- **English**:  
  Use `crontab -e` to run the script periodically, for example every day at 00:00:
  ```bash
  0 0 * * * /path/to/auto-backup/local-backup/for_unix/auto_backup_unix.sh >> /tmp/auto_backup_unix.log 2>&1
  ```

- **中文**：  
  可以通过 `crontab -e` 配置定时任务，例如每天 0 点：
  ```bash
  0 0 * * * /path/to/auto-backup/local-backup/for_unix/auto_backup_unix.sh >> /tmp/auto_backup_unix.log 2>&1
  ```

