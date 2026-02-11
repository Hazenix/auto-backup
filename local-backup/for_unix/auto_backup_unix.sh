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

REPO_INDEXES=("1")

# ---------- Repository 1 configuration ----------
# Local repository path (CHANGE THIS on macOS/Linux)
REPO_DIR_1="$HOME/path/to/demo-uniapp"
# Target branch
GIT_BRANCH_1="main"
# GitHub repository info (owner and repo)
GITHUB_OWNER_1="Hazehacker"
GITHUB_REPO_1="demo-uniapp"

# ---------- Repository 2 example (uncomment and modify when needed) ----------
# REPO_DIR_2="$HOME/path/to/another-repo"
# GIT_BRANCH_2="main"
# GITHUB_OWNER_2="YourGitHubName"
# GITHUB_REPO_2="another-repo"


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

backup_one_repo() {
  local idx="$1"

  local repo_dir_var="REPO_DIR_${idx}"
  local branch_var="GIT_BRANCH_${idx}"
  local owner_var="GITHUB_OWNER_${idx}"
  local repo_var="GITHUB_REPO_${idx}"

  local repo_dir="${!repo_dir_var:-}"
  local branch="${!branch_var:-main}"
  local owner="${!owner_var:-}"
  local repo="${!repo_var:-}"

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

  cd "${repo_dir}"

  # Stage all changes
  git add .

  # Only commit and push when there are changes
  if git diff-index --quiet HEAD --; then
    echo "[INFO] No changes to commit: ${repo_dir}"
    return 0
  fi

  # Build commit message
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "${COMMIT_PREFIX}: ${now}"

  # Push to GitHub via HTTPS using credentials from environment variables
  if ! git push "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${owner}/${repo}.git" "${branch}"; then
    echo "[ERR] Push failed: ${repo_dir}"
  else
    echo "[OK] Push completed: ${repo_dir}"
  fi
}

for idx in "${REPO_INDEXES[@]}"; do
  backup_one_repo "${idx}"
done


