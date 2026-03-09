@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: =================配置区=================
title STS2 SYNC V4.2
set "ADB=%~dp0adb\adb.exe"
set "PKG=com.megacrit.sts2"
set "APPID=2868840"

set "STEAM_ROOT=%AppData%\SlayTheSpire2\steam"
for /d %%i in ("%STEAM_ROOT%\76*") do set "PC_SAVE=%%i"

for /f "tokens=2*" %%a in ('reg query "HKEY_CURRENT_USER\Software\Valve\Steam" /v "SteamPath" 2^>nul') do set "STEAM_INSTALL=%%b"
set "STEAM_INSTALL=!STEAM_INSTALL:/=\!"
set "REMOTE_SAVE="
if exist "!STEAM_INSTALL!\userdata" (
    for /d %%d in ("!STEAM_INSTALL!\userdata\*") do (
        if exist "%%d\!APPID!\remote\profile1\saves" set "REMOTE_SAVE=%%d\!APPID!\remote"
    )
)

set "MB_ROOT=%~dp0Mobile_Saves_Backup"
set "PC_ROOT=%~dp0PC_Saves_Backup"
set "EXP_ROOT=%~dp0Mobile_Export"
set "MAX_BK=10"

if not exist "%ADB%" (echo [错误] 找不到 adb\adb.exe && pause && exit)


:MENU
cls
echo ==========================================
echo               STS2 SYNC
echo ==========================================
echo  [状态] AppData:!PC_SAVE!
echo  [状态] Remote :!REMOTE_SAVE!
echo ------------------------------------------
echo ------------------------------------------
echo  1. 同步到手机 (PC -^> Mobile)
echo  2. 同步到电脑 (Mobile -^> PC)
echo  3. 恢复电脑存档
echo  4. 恢复手机存档
echo  5. 导出手机存档
echo  6. 连接教程
echo  7. 退出
echo ------------------------------------------
call :CHECK_ADB
set /p opt=请选择: 

for /f %%i in ('powershell -noprofile -command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "ts=%%i"
if "%opt%"=="1" goto TO_MOBILE
if "%opt%"=="2" goto TO_PC
if "%opt%"=="3" goto RESTORE_PC
if "%opt%"=="4" goto RESTORE_MB
if "%opt%"=="5" goto EXPORT_MB
if "%opt%"=="6" goto TUTORIAL
if "%opt%"=="7" exit
goto MENU

:CONFIRM
echo.
set /p confirm=确认执行操作吗? (y/n): 
if /i "!confirm!"=="y" goto :EOF
echo 操作取消。 & pause & goto MENU

:: ------------------ [连接检测子程序] ------------------
:CHECK_ADB
echo.
echo [连接检测] 正在检查 ADB 设备...
"%ADB%" devices
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do (
    if "%%b"=="device" (
        set "ADB_OK=1"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.manufacturer') do set "MFR=%%m"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.model') do set "MDL=%%m"
        set "MFR_CN=!MFR!"
        if /i "!MFR!"=="xiaomi"    set "MFR_CN=小米"
        if /i "!MFR!"=="redmi"     set "MFR_CN=红米"
        if /i "!MFR!"=="huawei"    set "MFR_CN=华为"
        if /i "!MFR!"=="honor"     set "MFR_CN=荣耀"
        if /i "!MFR!"=="oppo"      set "MFR_CN=OPPO"
        if /i "!MFR!"=="vivo"      set "MFR_CN=vivo"
        if /i "!MFR!"=="oneplus"   set "MFR_CN=一加"
        if /i "!MFR!"=="realme"    set "MFR_CN=真我"
        if /i "!MFR!"=="samsung"   set "MFR_CN=三星"
        if /i "!MFR!"=="google"    set "MFR_CN=谷歌"
        if /i "!MFR!"=="sony"      set "MFR_CN=索尼"
        if /i "!MFR!"=="asus"      set "MFR_CN=华硕"
        if /i "!MFR!"=="meizu"     set "MFR_CN=魅族"
        if /i "!MFR!"=="nubia"     set "MFR_CN=努比亚"
        if /i "!MFR!"=="zte"       set "MFR_CN=中兴"
        if /i "!MFR!"=="lenovo"    set "MFR_CN=联想"
        if /i "!MFR!"=="motorola"  set "MFR_CN=摩托罗拉"
        echo [OK] 检测到设备: !MFR_CN! !MDL!
        goto :EOF
    )
    if "%%b"=="unauthorized" (
        echo [错误] 设备未授权 (%%a)
        echo [失败] 请在手机上点击允许USB调试 然后重试。
        set "ADB_OK="
        goto :EOF
    )
    if "%%b"=="offline" (
        echo [错误] 设备离线 (%%a)
        echo [失败] 请拔插USB线后重试。
        set "ADB_OK="
        goto :EOF
    )
)
echo [错误] 未检测到任何设备。
echo        请确认：USB线已连接、手机已开启USB调试、驱动已安装。
set "ADB_OK="
goto :EOF

:: ------------------ [1. 同步到手机] ------------------
:TO_MOBILE
if "!PC_SAVE!"=="" (echo [错误] 未找到PC存档目录 & pause & goto MENU)
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
set "BK=%MB_ROOT%\%ts%"
"%ADB%" shell "am force-stop %PKG%"
echo [1/4] 正在备份手机现有存档...
for %%p in (1 2 3) do (
    mkdir "%BK%\profile%%p\history" 2>nul
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save" > "%BK%\profile%%p\progress.save" 2>nul
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f" > "%BK%\profile%%p\history\%%f" 2>nul
    )
)
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save" > "%BK%\profile.save" 2>nul
echo [2/4] 正在推送PC存档到中转站...
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge"
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history"
    if exist "!PC_SAVE!\profile%%p\saves\progress.save" "%ADB%" push "!PC_SAVE!\profile%%p\saves\progress.save" /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "!PC_SAVE!\profile%%p\saves\prefs.save"    "%ADB%" push "!PC_SAVE!\profile%%p\saves\prefs.save"    /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "!PC_SAVE!\profile%%p\saves\current_run.save" "%ADB%" push "!PC_SAVE!\profile%%p\saves\current_run.save" /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "!PC_SAVE!\profile%%p\saves\history" "%ADB%" push "!PC_SAVE!\profile%%p\saves\history/." /data/local/tmp/sts_bridge/profile%%p/history/ >nul
)
"%ADB%" push "!PC_SAVE!\profile.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
echo [3/4] 正在写入手机存档...
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save'"
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile%%p/saves/history && mkdir -p files/default/1/profile%%p/saves/history'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/progress.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/progress.save > files/default/1/profile%%p/saves/progress.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/prefs.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/prefs.save > files/default/1/profile%%p/saves/prefs.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/current_run.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/current_run.save > files/default/1/profile%%p/saves/current_run.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/profile%%p/history/*.run; do [ -f \"$f\" ] || continue; sed \"s/\\\"platform_type\\\": \\\"steam\\\"/\\\"platform_type\\\": \\\"none\\\"/g; s/\\\"build_id\\\": \\\"v0.98.1\\\"/\\\"build_id\\\": \\\"v0.98.0\\\"/g\" \"$f\" > \"files/default/1/profile%%p/saves/history/$(basename $f)\"; done'"
)
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [4/4] 正在清理旧备份...
call :CLEANUP "%MB_ROOT%"
echo [OK] 同步完成。
pause & goto MENU

:: ------------------ [2. 同步到电脑] ------------------
:TO_PC
if "!PC_SAVE!"=="" (echo [错误] 未找到PC存档目录 & pause & goto MENU)
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
echo [1/5] 正在备份PC当前存档...
robocopy "!PC_SAVE!" "%PC_ROOT%\%ts%" /E /R:0 /W:0 >nul

set "TEMP_P=%~dp0temp_pull"
rmdir /s /q "%TEMP_P%" 2>nul
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge"
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history"
    mkdir "%TEMP_P%\profile%%p\history" 2>nul
)
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"

echo [2/5] 正在从手机抓取存档...
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save > /data/local/tmp/sts_bridge/profile.save"
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save > /data/local/tmp/sts_bridge/profile%%p/progress.save 2>/dev/null"
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/prefs.save > /data/local/tmp/sts_bridge/profile%%p/prefs.save 2>/dev/null"
    "%ADB%" shell "if run-as %PKG% ls files/default/1/profile%%p/saves/current_run.save >/dev/null 2>&1; then run-as %PKG% cat files/default/1/profile%%p/saves/current_run.save > /data/local/tmp/sts_bridge/profile%%p/current_run.save; fi"
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f > /data/local/tmp/sts_bridge/profile%%p/history/%%f"
    )
)

echo [3/5] 正在拉取文件到本地...
"%ADB%" pull /data/local/tmp/sts_bridge/. "%TEMP_P%" >nul
for %%p in (1 2 3) do (
    "%ADB%" pull /data/local/tmp/sts_bridge/profile%%p/history/. "%TEMP_P%\profile%%p\history" >nul
)
for %%p in (1 2 3) do (
    set /a "cnt_%%p=0"
    for %%x in ("%TEMP_P%\profile%%p\history\*.run") do set /a "cnt_%%p+=1"
    echo  [历史记录] profile%%p: !cnt_%%p! 条
)

echo [4/5] 正在执行无损适配并写入存档...
powershell -Command "$utf8 = New-Object System.Text.UTF8Encoding $False; Get-ChildItem '%TEMP_P%' -Recurse -Include *.run,*.save | ForEach-Object { $c = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8); $c = $c -replace '\"platform_type\":\s*\"none\"', '\"platform_type\": \"steam\"'; $c = $c -replace '\"build_id\":\s*\"v0.98.0\"', '\"build_id\": \"v0.98.1\"'; [System.IO.File]::WriteAllText($_.FullName, $c, $utf8); (Get-Item $_.FullName).LastWriteTime = Get-Date }"
attrib -r "!PC_SAVE!\*.*" /s >nul 2>&1
if not "!REMOTE_SAVE!"=="" attrib -r "!REMOTE_SAVE!\*.*" /s >nul 2>&1
copy /y "%TEMP_P%\profile.save" "!PC_SAVE!\profile.save" >nul
:: progress.save 在根目录也有一份
if exist "%TEMP_P%\profile1\progress.save" copy /y "%TEMP_P%\profile1\progress.save" "!PC_SAVE!\progress.save" >nul
for %%p in (1 2 3) do (
    if exist "!PC_SAVE!\profile%%p\saves\" (
        if exist "%TEMP_P%\profile%%p\progress.save" copy /y "%TEMP_P%\profile%%p\progress.save" "!PC_SAVE!\profile%%p\saves\progress.save" >nul
        if exist "%TEMP_P%\profile%%p\prefs.save"    copy /y "%TEMP_P%\profile%%p\prefs.save"    "!PC_SAVE!\profile%%p\saves\prefs.save" >nul
        if exist "%TEMP_P%\profile%%p\current_run.save" (
            copy /y "%TEMP_P%\profile%%p\current_run.save" "!PC_SAVE!\profile%%p\saves\current_run.save" >nul
        ) else (
            if exist "!PC_SAVE!\profile%%p\saves\current_run.save" del "!PC_SAVE!\profile%%p\saves\current_run.save"
        )
        robocopy "%TEMP_P%\profile%%p\history" "!PC_SAVE!\profile%%p\saves\history" /E /R:0 /W:0 >nul
    )
)
if not "!REMOTE_SAVE!"=="" (
    for %%p in (1 2 3) do (
        if exist "!REMOTE_SAVE!\profile%%p\saves\" (
            if exist "%TEMP_P%\profile%%p\progress.save" copy /y "%TEMP_P%\profile%%p\progress.save" "!REMOTE_SAVE!\profile%%p\saves\progress.save" >nul
            if exist "%TEMP_P%\profile%%p\prefs.save"    copy /y "%TEMP_P%\profile%%p\prefs.save"    "!REMOTE_SAVE!\profile%%p\saves\prefs.save" >nul
            if exist "%TEMP_P%\profile%%p\current_run.save" (
                copy /y "%TEMP_P%\profile%%p\current_run.save" "!REMOTE_SAVE!\profile%%p\saves\current_run.save" >nul
            ) else (
                if exist "!REMOTE_SAVE!\profile%%p\saves\current_run.save" del "!REMOTE_SAVE!\profile%%p\saves\current_run.save"
            )
            robocopy "%TEMP_P%\profile%%p\history" "!REMOTE_SAVE!\profile%%p\saves\history" /E /R:0 /W:0 >nul
        )
    )
    if exist "!REMOTE_SAVE!\..\..\remotecache.vdf" del /f /q "!REMOTE_SAVE!\..\..\remotecache.vdf"
)

echo [5/5] 正在清理旧备份...
rmdir /s /q "%TEMP_P%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
call :CLEANUP "%PC_ROOT%"
echo [SUCCESS] 同步回电脑完成，且文字描述已保留。
pause & goto MENU

:RESTORE_PC
cls
echo ======= 恢复 PC 备份 =======
set /a cnt=0
for /d %%d in ("%PC_ROOT%\*") do (set /a cnt+=1 & set "f!cnt!=%%~nxd" & echo  [!cnt!] %%~nxd)
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CONFIRM
attrib -r "!PC_SAVE!\*.*" /s >nul 2>&1
robocopy "%PC_ROOT%\!S_BK!" "!PC_SAVE!" /E /R:0 /W:0 >nul
echo [OK] 已恢复。
pause & goto MENU

:RESTORE_MB
cls
echo ======= 恢复 Mobile 备份 =======
set /a cnt=0
for /d %%d in ("%MB_ROOT%\*") do (set /a cnt+=1 & set "f!cnt!=%%~nxd" & echo  [!cnt!] %%~nxd)
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge"
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history"
    if exist "%MB_ROOT%\!S_BK!\profile%%p\progress.save" "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\progress.save" /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "%MB_ROOT%\!S_BK!\profile%%p\prefs.save"    "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\prefs.save"    /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "%MB_ROOT%\!S_BK!\profile%%p\current_run.save" "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\current_run.save" /data/local/tmp/sts_bridge/profile%%p/ >nul
    if exist "%MB_ROOT%\!S_BK!\profile%%p\history" "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\history/." /data/local/tmp/sts_bridge/profile%%p/history/ >nul
)
if exist "%MB_ROOT%\!S_BK!\profile.save" "%ADB%" push "%MB_ROOT%\!S_BK!\profile.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile.save ]; then cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save; fi'"
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile%%p/saves/history && mkdir -p files/default/1/profile%%p/saves/history'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/progress.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/progress.save > files/default/1/profile%%p/saves/progress.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/prefs.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/prefs.save > files/default/1/profile%%p/saves/prefs.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/current_run.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/current_run.save > files/default/1/profile%%p/saves/current_run.save; fi'"
    "%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/profile%%p/history/*.run; do [ -f \"$f\" ] || continue; cat \"$f\" > \"files/default/1/profile%%p/saves/history/$(basename $f)\"; done'"
)
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [OK] 已恢复。
pause & goto MENU

:EXPORT_MB
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
echo 正在导出...
set "EXP=%EXP_ROOT%\%ts%"
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge"
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history"
    mkdir "%EXP%\profile%%p\history" 2>nul
)
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save > /data/local/tmp/sts_bridge/profile.save"
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save > /data/local/tmp/sts_bridge/profile%%p/progress.save 2>/dev/null"
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f > /data/local/tmp/sts_bridge/profile%%p/history/%%f"
    )
)
"%ADB%" pull /data/local/tmp/sts_bridge/. "%EXP%" >nul
for %%p in (1 2 3) do (
    "%ADB%" pull /data/local/tmp/sts_bridge/profile%%p/history/. "%EXP%\profile%%p\history" >nul
)
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [OK] 导出成功，路径: %EXP%
pause & goto MENU

:: ------------------ [连接教程] ------------------
:TUTORIAL
cls
echo ==========================================
echo             USB 连接教程
echo ==========================================
echo.
echo  [第一步] 开启开发者模式和USB调试
echo  ----------------------------------------
echo   设置 - 关于手机 - 连续点击版本号7次
echo   看到 已开启开发者模式 后返回
echo   设置 - 开发者选项 - 打开 USB调试
echo.
echo  [第二步] 用数据线连接电脑
echo  ----------------------------------------
echo   请使用原装线或支持数据传输的线
echo   连接后手机选择USB用途时 选择 仅充电
echo.
echo   * 如果没有弹出USB用途选择
echo     在开发者选项中开启
echo     允许仅充电模式下进行调试
echo     然后拔插USB线重试
echo.
echo  [第三步] 允许USB调试授权
echo  ----------------------------------------
echo   手机弹出 允许USB调试 弹窗时点击允许
echo   如未弹出请拔插USB线重试
echo.
echo  [第四步] 安装驱动 (首次连接^)
echo  ----------------------------------------
echo   Windows通常会自动安装驱动
echo   若连接后仍未识别请到手机品牌官网下载
echo.
echo  [常见报错]
echo  ----------------------------------------
echo   未检测到设备   USB调试未开 或 驱动未安装
echo   unauthorized   未点击允许USB调试授权弹窗
echo   offline        数据线接触不良 拔插重试
echo.
echo ==========================================
pause & goto MENU

:: ------------------ [CLEANUP 保留最新N个备份] ------------------
:CLEANUP
set /a _cnt=0
for /d %%d in ("%~1\*") do set /a _cnt+=1
if !_cnt! leq %MAX_BK% goto :EOF
set /a _del=_cnt - MAX_BK
set /a _done=0
for /d %%d in ("%~1\*") do (
    if !_done! lss !_del! (
        rmdir /s /q "%%d"
        set /a _done+=1
    )
)
goto :EOF