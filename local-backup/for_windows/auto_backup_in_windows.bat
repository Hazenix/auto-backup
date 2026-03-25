@echo off
setlocal enabledelayedexpansion

:: IMPORTANT (Encoding):
:: - This .bat contains Chinese paths. Save this file as "UTF-8 with BOM".
:: - Switch code page to UTF-8 BEFORE any lines that contain Chinese characters (paths, echo, etc.).
chcp 65001 > nul

echo ========================================
echo   Git 自动备份脚本
echo ========================================
echo [DEBUG] Step 1: Loading config...
echo.

:: ================================
:: Load configuration from git_env.bat
:: ================================
if exist "%~dp0git_env.bat" (
    echo [DEBUG] Found git_env.bat, loading...
    call "%~dp0git_env.bat"
    echo [DEBUG] Config loaded.
) else (
    echo [ERROR] git_env.bat not found!
    echo Please copy git_env.bat.example to git_env.bat.
    pause
    goto :EOF
)

:: Validate required configuration
echo [DEBUG] Step 2: Validating GIT_USERNAME...
if not defined GIT_USERNAME (
    echo [ERROR] GIT_USERNAME not defined!
    pause
    goto :EOF
)
echo [DEBUG] GIT_USERNAME=%GIT_USERNAME%

echo [DEBUG] Step 3: Validating GIT_PASSWORD...
if not defined GIT_PASSWORD (
    echo [ERROR] GIT_PASSWORD not defined!
    pause
    goto :EOF
)
echo [DEBUG] GIT_PASSWORD is set.

:: Set default values if not defined
if not defined COMMIT_PREFIX set "COMMIT_PREFIX=Auto backup"
if not defined USE_PROXY set "USE_PROXY=0"
if not defined PROXY_SCRIPT set "PROXY_SCRIPT=%~dp0start_clash_proxy.ps1"

:: ================================
:: Load repository indexes from config
:: ================================
echo [DEBUG] Step 4: Checking REPO_INDEXES...
if not defined REPO_INDEXES (
    echo [ERROR] REPO_INDEXES not defined!
    echo Please set REPO_INDEXES in git_env.bat.
    pause
    goto :EOF
)

echo [DEBUG] REPO_INDEXES=%REPO_INDEXES%
echo.
echo [DEBUG] Starting backup process...

:: Start/control proxy (optional, delegated to external script)
if "%USE_PROXY%"=="1" (
    if exist "%PROXY_SCRIPT%" (
        echo [信息] 正在启用代理...
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PROXY_SCRIPT%"
    ) else (
        echo [警告] 启用代理失败: 找不到代理脚本 %PROXY_SCRIPT%
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
    echo [跳过] 仓库 %IDX% 未配置本地路径。
    goto :EOF
)

:: Skip if GitHub info is not configured
if "!GITHUB_OWNER!"=="" (
    echo [跳过] 仓库 %IDX% 未配置 GITHUB_OWNER。
    goto :EOF
)

if "!GITHUB_REPO!"=="" (
    echo [跳过] 仓库 %IDX% 未配置 GITHUB_REPO。
    goto :EOF
)

:: Default branch to "main" if not set
if "!GIT_BRANCH!"=="" (
    set "GIT_BRANCH=main"
)

echo.
echo ================================
echo 正在备份仓库 #!IDX!: !REPO_DIR!
echo ================================

:: Ensure the local repository directory exists before attempting to cd
if not exist "!REPO_DIR!" (
    echo [错误] 本地仓库路径不存在: !REPO_DIR!
    goto :EOF
)

cd /d "!REPO_DIR!"
if errorlevel 1 (
    echo [错误] 无法切换到目录: !REPO_DIR!
    goto :EOF
)

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
        echo [失败] 推送失败: !REPO_DIR!
    ) else (
        echo [成功] 推送完成: !REPO_DIR!
    )
) else (
    echo [信息] 无变更需要提交: !REPO_DIR!
)

goto :EOF


:AfterBackup
echo.
echo ========================================
echo   备份任务完成
echo ========================================
endlocal

:: Keep console window open after script finishes (for viewing output).
:: Comment out the next line if you want the window to close automatically.
pause


