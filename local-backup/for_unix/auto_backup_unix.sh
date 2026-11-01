#!/usr/bin/env bash

set -euo pipefail

########################################
# Global configuration (can be customized)
########################################

# Commit message prefix (shared by all repositories)
COMMIT_PREFIX="Daily auto-commit"

# Whether to automatically enable proxy: 1 = enable, 0 = disable
USE_PROXY=0

# Proxy controller script path (for macOS/Linux)
# By default, points to a shell script in the same directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
PROXY_SCRIPT="${SCRIPT_DIR}/start_clash_proxy_unix.sh"


########################################
# Repository index list to back up
# Extend as needed, e.g.: REPO_INDEXES=("1" "2" "3")
########################################

# NOTE on order: the vault root (repo 1) is a super-repo that tracks the leaf
# repos as submodule gitlinks. Leaf repos MUST be committed first so the root
# records valid commit pointers, so repo 1 is processed LAST.
# NOTE: repo 5 (拨号网络) is intentionally excluded on this machine.
REPO_INDEXES=("2" "3" "4" "1")

# Shared base directory (Obsidian Vault root on this Mac)
VAULT_DIR="$HOME/Documents/myproject/self-knowledge-system"

# Per-repo PUSH_TO_ORIGIN_N: 1 = git push to GitHub, 0 = local commit only.
# Defaults to 1 when unset. All repos here are local-commit-only by request.

# ---------- Repository 1: vault root ----------
REPO_DIR_1="${VAULT_DIR}"
GIT_BRANCH_1="main"
GITHUB_OWNER_1="Hazenix"
GITHUB_REPO_1="self-knowledge-system"
PUSH_TO_ORIGIN_1=0

# ---------- Repository 2: 技术学习 ----------
REPO_DIR_2="${VAULT_DIR}/技术学习"
GIT_BRANCH_2="main"
GITHUB_OWNER_2="Hazenix"
GITHUB_REPO_2="tech-learning"
PUSH_TO_ORIGIN_2=0

# ---------- Repository 3: 项目经验 ----------
REPO_DIR_3="${VAULT_DIR}/项目经验"
GIT_BRANCH_3="main"
GITHUB_OWNER_3="Hazenix"
GITHUB_REPO_3="engineering-notes"
PUSH_TO_ORIGIN_3=0

# ---------- Repository 4: 求职/我的简历 ----------
REPO_DIR_4="${VAULT_DIR}/求职/我的简历"
GIT_BRANCH_4="main"
GITHUB_OWNER_4="Hazenix"
GITHUB_REPO_4="my-resume"
PUSH_TO_ORIGIN_4=0

# ---------- Repository 5: 拨号网络 (excluded on this machine; empty repo) ----------
# Re-enable by adding "5" back to REPO_INDEXES once the repo has content.
# REPO_DIR_5="${VAULT_DIR}/拨号网络"
# GIT_BRANCH_5="main"
# GITHUB_OWNER_5="Hazenix"
# GITHUB_REPO_5="dial-up-network"
# PUSH_TO_ORIGIN_5=0


########################################
# Load Git credentials
########################################

if [[ -f "${SCRIPT_DIR}/git_env.sh" ]]; then
  # shellcheck disable=SC1090
  . "${SCRIPT_DIR}/git_env.sh"
else
  echo "[ERR] git_env.sh not found in ${SCRIPT_DIR}. Cannot load Git credentials."
  exit 1
fi

if [[ -z "${GIT_USERNAME:-}" || -z "${GIT_PASSWORD:-}" ]]; then
  echo "[ERR] GIT_USERNAME or GIT_PASSWORD is not set. Please configure git_env.sh."
  exit 1
fi


########################################
# Start/control proxy (optional)
########################################

if [[ "${USE_PROXY}" -eq 1 ]]; then
  if [[ -x "${PROXY_SCRIPT}" ]]; then
    echo "[INFO] Calling proxy controller script: ${PROXY_SCRIPT}"
    "${PROXY_SCRIPT}"
  elif [[ -f "${PROXY_SCRIPT}" ]]; then
    echo "[INFO] Calling proxy controller script via sh: ${PROXY_SCRIPT}"
    sh "${PROXY_SCRIPT}"
  else
    echo "[WARN] USE_PROXY=1 but proxy controller script not found: ${PROXY_SCRIPT}"
  fi
fi


########################################
# Backup all configured repositories
########################################

# Tracks whether any repository failed to push. Non-zero on exit signals
# the scheduler (launchd/cron) that the backup did not fully succeed.
BACKUP_FAILED=0

backup_one_repo() {
  local idx="$1"

  local repo_dir_var="REPO_DIR_${idx}"
  local branch_var="GIT_BRANCH_${idx}"
  local owner_var="GITHUB_OWNER_${idx}"
  local repo_var="GITHUB_REPO_${idx}"
  local push_var="PUSH_TO_ORIGIN_${idx}"

  local repo_dir="${!repo_dir_var:-}"
  local branch="${!branch_var:-main}"
  local owner="${!owner_var:-}"
  local repo="${!repo_var:-}"
  local push_to_origin="${!push_var:-1}"

  if [[ -z "${repo_dir}" ]]; then
    echo "[WARN] REPO_DIR_${idx} is not configured, skipping this repository."
    return 0
  fi

  echo
  echo "================================"
  echo "Backing up repository #${idx}: ${repo_dir}"
  echo "================================"

  if [[ ! -d "${repo_dir}" ]]; then
    echo "[WARN] Repository directory does not exist: ${repo_dir}"
    return 0
  fi

  if ! cd "${repo_dir}"; then
    echo "[ERR] Failed to cd into: ${repo_dir}"
    return 1
  fi

  # Stage all changes
  if ! git add .; then
    echo "[ERR] git add failed: ${repo_dir}"
    return 1
  fi

  # Only commit when there are changes. For a repo with no commit yet (no HEAD),
  # skip the diff check and go straight to creating the first commit.
  if git rev-parse --verify -q HEAD >/dev/null 2>&1 && git diff-index --quiet HEAD --; then
    echo "[INFO] No changes to commit: ${repo_dir}"
    return 0
  fi

  # Build commit message
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  if ! git commit -m "${COMMIT_PREFIX}: ${now}"; then
    echo "[ERR] git commit failed: ${repo_dir}"
    return 1
  fi

  # Push only when PUSH_TO_ORIGIN_N is enabled (1). Otherwise commit locally only.
  if [[ "${push_to_origin}" != "1" ]]; then
    echo "[SKIP] Push disabled (local commit only): ${repo_dir}"
    return 0
  fi

  # Push to GitHub via HTTPS using credentials from environment variables
  if ! git push "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${owner}/${repo}.git" "${branch}"; then
    echo "[ERR] Push failed: ${repo_dir}"
    BACKUP_FAILED=1
  else
    echo "[OK] Push completed: ${repo_dir}"
  fi
}

# Each repo is error-contained: a failure flags BACKUP_FAILED but never aborts
# the loop, so the remaining repositories are still backed up.
for idx in "${REPO_INDEXES[@]}"; do
  backup_one_repo "${idx}" || BACKUP_FAILED=1
done

if [[ "${BACKUP_FAILED}" -ne 0 ]]; then
  echo "[ERR] One or more repositories failed to push."
  exit 1
fi


