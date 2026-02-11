@echo off
setlocal enabledelayedexpansion

:: ===========================
:: 通用配置（可按需修改）
:: ===========================

:: 提交信息前缀（所有仓库共用）
set "COMMIT_PREFIX=Daily auto-commit"

:: 是否自动启用代理：1=启用，0=禁用（所有仓库共用）
set "USE_PROXY=0"

:: 代理控制脚本路径[默认使用当前目录下的 PowerShell 脚本，通过 Clash API 开启代理模式]
set "PROXY_SCRIPT=%~dp0start_clash_proxy.ps1"

:: ================================
:: 需要备份的仓库索引列表（按需增减，比如：1 2 3）
set "REPO_INDEXES=1"
:: ---------- 仓库 1 配置 ----------
:: 仓库本地路径
set "REPO_DIR_1=D:\ProjectOfBZH\demo-uniapp"
:: 目标分支
set "GIT_BRANCH_1=main"
:: GitHub 仓库信息（owner 和 repo）
set "GITHUB_OWNER_1=Hazehacker"
set "GITHUB_REPO_1=demo-uniapp"

:: ---------- 仓库 2 示例（需要时取消注释并修改） ----------
:: set "REPO_DIR_2=D:\path\to\another-repo"
:: set "GIT_BRANCH_2=main"
:: set "GITHUB_OWNER_2=YourGitHubName"
:: set "GITHUB_REPO_2=another-repo"

:: ================================


:: 通用初始化

:: 设置控制台编码为UTF-8，避免中文乱码
chcp 65001 > nul

:: 加载 Git 账号和密码（保存在同目录下的 git_env.bat 中）
:: %~dp0 代表当前脚本所在目录
if exist "%~dp0git_env.bat" (
    call "%~dp0git_env.bat"
) else (
    echo 未找到 git_env.bat，无法加载 Git 账号和密码。
    goto :EOF
)


:: 启动/控制代理（可选，通过外部脚本解耦）

if "%USE_PROXY%"=="1" (
    if exist "%PROXY_SCRIPT%" (
        echo 正在调用代理控制脚本：%PROXY_SCRIPT%
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PROXY_SCRIPT%"
    ) else (
        echo 已开启自动启用代理，但未找到代理控制脚本：%PROXY_SCRIPT%
    )
)


:: 依次备份所有配置的仓库

for %%I in (%REPO_INDEXES%) do (
    call :BackupOneRepo %%I
)

goto :AfterBackup


:: 备份单个仓库的子过程

:BackupOneRepo
set "IDX=%~1"

:: 读取当前索引对应的配置
set "REPO_DIR=!REPO_DIR_%IDX%!"
set "GIT_BRANCH=!GIT_BRANCH_%IDX%!"
set "GITHUB_OWNER=!GITHUB_OWNER_%IDX%!"
set "GITHUB_REPO=!GITHUB_REPO_%IDX%!"

:: 若未配置仓库本地路径则跳过
if "!REPO_DIR!"=="" (
    echo [WARN] 未找到索引 %IDX% 对应的 REPO_DIR_!IDX!，跳过该仓库。
    goto :EOF
)

:: 分支默认 main（如果没填的话）
if "!GIT_BRANCH!"=="" (
    set "GIT_BRANCH=main"
)

echo.
echo ================================
echo 正在备份仓库 #!IDX!: !REPO_DIR!
echo ================================

cd /d "!REPO_DIR!"

:: 添加所有更改
git add .

:: 只有有文件被修改时才进行提交和推送
git diff-index --quiet HEAD --
if ERRORLEVEL 1 (
    :: 组装提交信息（使用延迟变量展开，保证时间被正确取到）
    set "NOW=%date% %time%"
    git commit -m "!COMMIT_PREFIX!: !NOW!"
    
    :: 使用环境变量中的账号和密码推送到 GitHub（https）
    git push "https://%GIT_USERNAME%:%GIT_PASSWORD%@github.com/!GITHUB_OWNER!/!GITHUB_REPO!.git" !GIT_BRANCH!
    
    if ERRORLEVEL 1 (
        echo 【ERR】 Push failed: !REPO_DIR!
    ) else (
        echo 【OK】 Push completed: !REPO_DIR!
    )
) else (
    echo [INFO] No changes to commit: !REPO_DIR!
)

goto :EOF


:AfterBackup
endlocal

@REM 脚本执行完毕后等待用户关闭（方便查看结果），如果希望自动关闭，可以注释掉下一行
pause


