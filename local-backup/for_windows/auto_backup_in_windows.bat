@echo off
setlocal enabledelayedexpansion

:: ===========================
:: Global configuration (can be customized)
:: ===========================

:: Commit message prefix (shared by all repositories)
set "COMMIT_PREFIX=Daily auto-commit"

:: Whether to automatically enable proxy: 1 = enable, 0 = disable (shared by all repositories)
set "USE_PROXY=0"

:: Proxy controller script path
:: By default, use the PowerShell script in the current directory to enable proxy mode via Clash API
set "PROXY_SCRIPT=%~dp0start_clash_proxy.ps1"

:: ================================
:: Repository index list to back up (extend as needed, e.g.: 1 2 3)
set "REPO_INDEXES=1"
:: ---------- Repository 1 configuration ----------
:: Local repository path
set "REPO_DIR_1=D:\ProjectOfBZH\demo-uniapp"
:: Target branch
set "GIT_BRANCH_1=main"
:: GitHub repository info (owner and repo)
set "GITHUB_OWNER_1=Hazehacker"
set "GITHUB_REPO_1=demo-uniapp"

:: ---------- Repository 2 example (uncomment and modify when needed) ----------
:: set "REPO_DIR_2=D:\path\to\another-repo"
:: set "GIT_BRANCH_2=main"
:: set "GITHUB_OWNER_2=YourGitHubName"
:: set "GITHUB_REPO_2=another-repo"

:: ================================


:: Common initialization

:: Set console code page to UTF-8 to avoid garbled output
chcp 65001 > nul

:: Load Git username and password (stored in git_env.bat in the same directory)
:: %~dp0 represents the directory path of this script
if exist "%~dp0git_env.bat" (
    call "%~dp0git_env.bat"
) else (
    echo [ERR] git_env.bat not found. Cannot load Git credentials.
    goto :EOF
)


:: Start/control proxy (optional, delegated to external script)

if "%USE_PROXY%"=="1" (
    if exist "%PROXY_SCRIPT%" (
        echo [INFO] Calling proxy controller script: %PROXY_SCRIPT%
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PROXY_SCRIPT%"
    ) else (
        echo [WARN] USE_PROXY=1 but proxy controller script not found: %PROXY_SCRIPT%
    )
)


:: Backup all configured repositories in sequence

for %%I in (%REPO_INDEXES%) do (
    call :BackupOneRepo %%I
)

goto :AfterBackup


:: Subroutine: backup a single repository

:BackupOneRepo
set "IDX=%~1"

:: Read configuration entries for the current index
set "REPO_DIR=!REPO_DIR_%IDX%!"
set "GIT_BRANCH=!GIT_BRANCH_%IDX%!"
set "GITHUB_OWNER=!GITHUB_OWNER_%IDX%!"
set "GITHUB_REPO=!GITHUB_REPO_%IDX%!"

:: Skip if no local repository path is configured
if "!REPO_DIR!"=="" (
    echo [WARN] REPO_DIR_!IDX! is not configured for index %IDX%, skipping this repository.
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

cd /d "!REPO_DIR!"

:: Stage all changes
git add .

:: Only commit and push when there are changes
git diff-index --quiet HEAD --
if ERRORLEVEL 1 (
    :: Build commit message (use delayed expansion so that time is captured correctly)
    set "NOW=%date% %time%"
    git commit -m "!COMMIT_PREFIX!: !NOW!"
    
    :: Push to GitHub via HTTPS using credentials from environment variables
    git push "https://%GIT_USERNAME%:%GIT_PASSWORD%@github.com/!GITHUB_OWNER!/!GITHUB_REPO!.git" !GIT_BRANCH!
    
    if ERRORLEVEL 1 (
        echo [ERR] Push failed: !REPO_DIR!
    ) else (
        echo [OK] Push completed: !REPO_DIR!
    )
) else (
    echo [INFO] No changes to commit: !REPO_DIR!
)

goto :EOF


:AfterBackup
endlocal

@REM Keep console window open after script finishes (for viewing output).
@REM Comment out the next line if you want the window to close automatically.
pause


