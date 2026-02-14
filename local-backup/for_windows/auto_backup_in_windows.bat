@echo off
setlocal enabledelayedexpansion

:: IMPORTANT (Encoding):
:: - This .bat contains Chinese paths. Save this file as "UTF-8 with BOM".
:: - Switch code page to UTF-8 BEFORE any lines that contain Chinese characters (paths, echo, etc.).
chcp 65001 > nul

echo.
echo ========================================
echo Auto Backup Script Started
echo ========================================
echo.

:: ===========================
:: Global configuration (can be customized)
:: ===========================

:: Commit message prefix (shared by all repositories)
set "COMMIT_PREFIX=Daily auto-commit"

::: Whether to push to GitHub after commit: 1 = enable, 0 = disable
set "ENABLE_GITHUB_PUSH=0"

:: Whether to automatically enable proxy: 1 = enable, 0 = disable (shared by all repositories)
set "USE_PROXY=0"

:: Proxy controller script path
:: By default, use the PowerShell script in the current directory to enable proxy mode via Clash API
set "PROXY_SCRIPT=%~dp0start_clash_proxy.ps1"

:: ================================
:: Repository index list to back up (extend as needed, e.g.: 1 2 3)
set "REPO_INDEXES=1 2 3"
echo [DEBUG] REPO_INDEXES set to: !REPO_INDEXES!
:: ---------- Repository 1 configuration ----------
:: Local repository path
set "REPO_DIR_1=D:\HuaweiMoveData\Users\毕哲晖\Documents\Obsidian Vault"
:: Target branch
set "GIT_BRANCH_1=main"
:: GitHub repository info (owner and repo)
set "GITHUB_OWNER_1=Hazehacker"
set "GITHUB_REPO_1=self-knowledge-system"

:: ---------- Repository 2 example (uncomment and modify when needed) ----------
set "REPO_DIR_2=D:\HuaweiMoveData\Users\毕哲晖\Documents\Obsidian Vault\技术学习"
set "GIT_BRANCH_2=main"
set "GITHUB_OWNER_2=Hazehacker"
set "GITHUB_REPO_2=tech-learning"

set "REPO_DIR_3=D:\HuaweiMoveData\Users\毕哲晖\Documents\Obsidian Vault\项目经验"
set "GIT_BRANCH_3=main"
set "GITHUB_OWNER_3=Hazehacker"
set "GITHUB_REPO_3=engineering-notes"

:: ================================


:: Common initialization

:: Set console code page to UTF-8 to avoid garbled output
chcp 65001 > nul

:: Load Git username and password (stored in git_env.bat in the same directory)
:: %~dp0 represents the directory path of this script
echo [INFO] Checking for git_env.bat...
if exist "%~dp0git_env.bat" (
    echo [INFO] Found git_env.bat, loading credentials...
    call "%~dp0git_env.bat"
    echo [INFO] Git credentials loaded successfully.
) else (
    echo [ERR] git_env.bat not found. Cannot load Git credentials.
    echo [ERR] Script will exit now.
    pause
    goto :EOF
)

:: Re-verify REPO_INDEXES after call (in case it was affected)
if "!REPO_INDEXES!"=="" (
    echo [WARN] REPO_INDEXES appears empty after call, re-setting...
    set "REPO_INDEXES=1 2 3"
)
echo [DEBUG] After call - REPO_INDEXES: !REPO_INDEXES!


:: Start/control proxy (optional, delegated to external script)

if "!USE_PROXY!"=="1" (
    if exist "%PROXY_SCRIPT%" (
        echo [INFO] Calling proxy controller script: %PROXY_SCRIPT%
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PROXY_SCRIPT%"
    ) else (
        echo [WARN] USE_PROXY=1 but proxy controller script not found: %PROXY_SCRIPT%
    )
)


:: Backup all configured repositories in sequence

echo.
echo [DEBUG] Before loop - REPO_INDEXES using %%: %REPO_INDEXES%
echo [DEBUG] Before loop - REPO_INDEXES using !!: !REPO_INDEXES!
echo [INFO] Starting backup process for repositories: !REPO_INDEXES!
echo.

:: Verify REPO_INDEXES is set
if "!REPO_INDEXES!"=="" (
    echo [ERR] REPO_INDEXES is empty! Cannot proceed with backup.
    echo [ERR] Please check the script configuration.
    goto :AfterBackup
)

:: Process repositories directly
:: Since for loop variable expansion has issues, we'll process each configured repository
echo [DEBUG] REPO_INDEXES should be: !REPO_INDEXES!

:: Process repository 1 if REPO_DIR_1 is configured
if defined REPO_DIR_1 (
    echo [DEBUG] Processing repository 1
    call :BackupOneRepo 1
)

:: Process repository 2 if REPO_DIR_2 is configured
if defined REPO_DIR_2 (
    echo [DEBUG] Processing repository 2
    call :BackupOneRepo 2
)

:: Process repository 3 if REPO_DIR_3 is configured
if defined REPO_DIR_3 (
    echo [DEBUG] Processing repository 3
    call :BackupOneRepo 3
)

echo.
echo ========================================
echo All backup operations completed
echo ========================================
echo.

goto :AfterBackup


:: Subroutine: backup a single repository

:BackupOneRepo
set "IDX=%~1"
echo [DEBUG] BackupOneRepo called with index: !IDX!

:: Read configuration entries for the current index
set "REPO_DIR=!REPO_DIR_%IDX%!"
set "GIT_BRANCH=!GIT_BRANCH_%IDX%!"
set "GITHUB_OWNER=!GITHUB_OWNER_%IDX%!"
set "GITHUB_REPO=!GITHUB_REPO_%IDX%!"

echo [DEBUG] REPO_DIR_!IDX! = !REPO_DIR!
echo [DEBUG] GIT_BRANCH_!IDX! = !GIT_BRANCH!

:: Skip if no local repository path is configured
if "!REPO_DIR!"=="" (
    echo [WARN] REPO_DIR_!IDX! is not configured for index !IDX!, skipping this repository.
    goto :EOF
)

:: Default branch to "main" if not set
if "!GIT_BRANCH!"=="" (
    set "GIT_BRANCH=main"
)

echo.
echo ================================
echo Backing up repository #!IDX!: !REPO_DIR!
echo ================================

:: Ensure the local repository directory exists before attempting to cd
echo [DEBUG] Checking if repository path exists: !REPO_DIR!
if not exist "!REPO_DIR!" (
    echo [ERR] Local repository path does not exist: !REPO_DIR!
    goto :EOF
)
echo [DEBUG] Repository path exists.

cd /d "!REPO_DIR!"
if errorlevel 1 (
    echo [ERR] Failed to change directory to: !REPO_DIR!
    goto :EOF
)
echo [DEBUG] Successfully changed to repository directory.

:: Check if this is a git repository
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo [ERR] Not a valid Git repository: !REPO_DIR!
    goto :EOF
)
echo [DEBUG] Valid Git repository confirmed.

:: Stage all changes
echo [DEBUG] Staging all changes...
git add .
if errorlevel 1 (
    echo [WARN] git add failed, but continuing...
)

:: Check current git status
echo [DEBUG] Checking git status...
git status --short

::: Only commit (and optionally push) when there are changes
echo [DEBUG] Checking for changes to commit...
git diff-index --quiet HEAD --
if ERRORLEVEL 1 (
    echo [INFO] Changes detected, creating commit...
    :: Build commit message (use delayed expansion so that time is captured correctly)
    set "NOW=%date% %time%"
    echo [DEBUG] Commit message: !COMMIT_PREFIX!: !NOW!
    git commit -m "!COMMIT_PREFIX!: !NOW!"
    
    if errorlevel 1 (
        echo [ERR] Commit failed: !REPO_DIR!
    ) else (
        echo [OK] Commit created successfully: !REPO_DIR!
    )
    
    :: Optionally push to GitHub via HTTPS using credentials from environment variables
    if "!ENABLE_GITHUB_PUSH!"=="1" (
        echo [DEBUG] Pushing to GitHub...
        git push "https://%GIT_USERNAME%:%GIT_PASSWORD%@github.com/!GITHUB_OWNER!/!GITHUB_REPO!.git" !GIT_BRANCH!
        
        if ERRORLEVEL 1 (
            echo [ERR] Push failed: !REPO_DIR!
        ) else (
            echo [OK] Push completed: !REPO_DIR!
        )
    ) else (
        echo [INFO] GitHub push is disabled, skipping push for: !REPO_DIR!
    )
) else (
    echo [INFO] No changes to commit: !REPO_DIR!
)

goto :EOF


:AfterBackup
echo.
echo Script execution finished.
endlocal

@REM Keep console window open after script finishes (for viewing output).
@REM Comment out the next line if you want the window to close automatically.
pause


