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
set "LOG=%~dp0sts2_sync.log"
echo [%date% %time%] 程序启动 > "%LOG%"
set "DEVICE_STR=未检测"

:MENU
cls
echo ==========================================
echo               STS2 SYNC
echo ==========================================
echo  [状态] AppData: !PC_SAVE!
echo  [状态] Remote : !REMOTE_SAVE!
echo ------------------------------------------
echo  1. 同步到手机 (PC -^> Mobile)
echo  2. 同步到电脑 (Mobile -^> PC)
echo  3. 恢复电脑存档
echo  4. 恢复手机存档
echo  5. 导出手机存档
echo  6. 连接教程
echo  7. 退出
echo ------------------------------------------
echo  [设备] !DEVICE_STR!
echo ------------------------------------------
set /p opt=请选择: 

for /f %%i in ('powershell -noprofile -command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "ts=%%i"
if "!opt!"=="1" goto TO_MOBILE
if "!opt!"=="2" goto TO_PC
if "!opt!"=="3" goto RESTORE_PC
if "!opt!"=="4" goto RESTORE_MB
if "!opt!"=="5" goto EXPORT_MB
if "!opt!"=="6" goto TUTORIAL
if "!opt!"=="7" exit
goto MENU

:CONFIRM
echo.
set /p confirm=确认执行操作吗? (y/n): 
if /i "!confirm!"=="y" exit /b
echo 操作取消。 & pause & goto MENU

:: ------------------ [连接检测子程序] ------------------
:CHECK_ADB
echo.
echo [连接检测] 正在检查 ADB 设备...
set "ADB_OK="
set "DEVICE_STR=未连接"
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices 2^>nul') do (
    if "%%b"=="device" (
        set "ADB_OK=1"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.manufacturer 2^>nul') do set "MFR=%%m"
        for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.marketname 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.vendor.marketname 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.vendor.oplus.market.name 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.vivo.market.name 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.vivo.product.marketname 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.config.marketing_name 2^>nul') do set "MDL=%%m"
        if "!MDL!"=="" for /f "delims=" %%m in ('"%ADB%" shell getprop ro.product.model 2^>nul') do set "MDL=%%m"
        set "MFR_CN=!MFR!"
        if /i "!MFR!"=="xiaomi"    set "MFR_CN="
        if /i "!MFR!"=="redmi"     set "MFR_CN="
        if /i "!MFR!"=="huawei"    set "MFR_CN="
        if /i "!MFR!"=="honor"     set "MFR_CN="
        if /i "!MFR!"=="oppo"      set "MFR_CN="
        if /i "!MFR!"=="vivo"      set "MFR_CN="
        if /i "!MFR!"=="oneplus"   set "MFR_CN="
        if /i "!MFR!"=="realme"    set "MFR_CN="
        if /i "!MFR!"=="samsung"   set "MFR_CN=三星"
        if /i "!MFR!"=="google"    set "MFR_CN=谷歌"
        if /i "!MFR!"=="sony"      set "MFR_CN=索尼"
        if /i "!MFR!"=="asus"      set "MFR_CN=华硕"
        if /i "!MFR!"=="meizu"     set "MFR_CN=魅族"
        if /i "!MFR!"=="nubia"     set "MFR_CN=努比亚"
        if /i "!MFR!"=="zte"       set "MFR_CN=中兴"
        if /i "!MFR!"=="lenovo"    set "MFR_CN=联想"
        if /i "!MFR!"=="motorola"  set "MFR_CN=摩托罗拉"
        if "!MFR_CN!"=="" (
            set "DEVICE_STR=!MDL!"
            echo [OK] 检测到设备: !MDL!
        ) else (
            set "DEVICE_STR=!MFR_CN! !MDL!"
            echo [OK] 检测到设备: !MFR_CN! !MDL!
        )
        exit /b
    )
    if "%%b"=="unauthorized" (
        set "DEVICE_STR=[未授权]"
        echo [错误] 设备未授权 (%%a)
        echo [提示] 请在手机上点击「允许USB调试」后重试
        exit /b
    )
    if "%%b"=="offline" (
        set "DEVICE_STR=[离线]"
        echo [错误] 设备离线 (%%a)
        echo [提示] 请拔插USB线后重试
        exit /b
    )
)
if not defined ADB_OK (
    echo [错误] 未检测到任何设备
    echo [提示] 请确认 USB线已连接 / USB调试已开启 / 驱动已安装
)
exit /b

:: ------------------ [1. 同步到手机] ------------------
:TO_MOBILE
if "!PC_SAVE!"=="" (echo [错误] 未找到PC存档目录 & pause & goto MENU)
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
set "BK=%MB_ROOT%\%ts%"
"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
echo [1/4] 正在备份手机现有存档...
for %%p in (1 2 3) do (
    mkdir "%BK%\profile%%p\history" 2>nul
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save" > "%BK%\profile%%p\progress.save" 2>nul
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/prefs.save" > "%BK%\profile%%p\prefs.save" 2>nul
    "%ADB%" shell "if run-as %PKG% ls files/default/1/profile%%p/saves/current_run.save >/dev/null 2>&1; then run-as %PKG% cat files/default/1/profile%%p/saves/current_run.save; fi" > "%BK%\profile%%p\current_run.save" 2>nul
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f" > "%BK%\profile%%p\history\%%f" 2>nul
    )
)
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save" > "%BK%\profile.save" 2>nul
set /a _bk_cnt=0
for %%x in ("%BK%\profile1\history\*.run") do set /a _bk_cnt+=1
for %%x in ("%BK%\profile2\history\*.run") do set /a _bk_cnt+=1
for %%x in ("%BK%\profile3\history\*.run") do set /a _bk_cnt+=1
if !_bk_cnt! gtr 0 (echo  已备份 !_bk_cnt! 条历史记录)
echo [2/4] 正在推送PC存档到中转站...
set "PUSH_TMP=%~dp0push_tmp"
rmdir /s /q "%PUSH_TMP%" 2>nul
for %%p in (1 2 3) do mkdir "%PUSH_TMP%\profile%%p\history" 2>nul
for %%p in (1 2 3) do (
    if exist "!PC_SAVE!\profile%%p\saves\progress.save"    copy /y "!PC_SAVE!\profile%%p\saves\progress.save"    "%PUSH_TMP%\profile%%p\progress.save" >nul
    if exist "!PC_SAVE!\profile%%p\saves\prefs.save"       copy /y "!PC_SAVE!\profile%%p\saves\prefs.save"       "%PUSH_TMP%\profile%%p\prefs.save" >nul
    if exist "!PC_SAVE!\profile%%p\saves\current_run.save" copy /y "!PC_SAVE!\profile%%p\saves\current_run.save" "%PUSH_TMP%\profile%%p\current_run.save" >nul
    if exist "!PC_SAVE!\profile%%p\saves\history" robocopy "!PC_SAVE!\profile%%p\saves\history" "%PUSH_TMP%\profile%%p\history" /E /R:0 /W:0 >nul
)
if exist "!PC_SAVE!\profile.save" copy /y "!PC_SAVE!\profile.save" "%PUSH_TMP%\profile.save" >nul
powershell -Command "$utf8=New-Object System.Text.UTF8Encoding $False; Get-ChildItem '%PUSH_TMP%' -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $c=[System.IO.File]::ReadAllText($_.FullName,[System.Text.Encoding]::UTF8); $c=$c.Replace("`r`n","`n").Replace("`r","`n"); [System.IO.File]::WriteAllText($_.FullName,$c,$utf8) }" >nul 2>&1
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge" >nul 2>&1
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history" >nul 2>&1
    if exist "%PUSH_TMP%\profile%%p\progress.save"    "%ADB%" push "%PUSH_TMP%\profile%%p\progress.save"    /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%PUSH_TMP%\profile%%p\prefs.save"       "%ADB%" push "%PUSH_TMP%\profile%%p\prefs.save"       /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%PUSH_TMP%\profile%%p\current_run.save" "%ADB%" push "%PUSH_TMP%\profile%%p\current_run.save" /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%PUSH_TMP%\profile%%p\history"          "%ADB%" push "%PUSH_TMP%\profile%%p\history/." /data/local/tmp/sts_bridge/profile%%p/history/ >nul 2>&1
)
if exist "%PUSH_TMP%\profile.save" "%ADB%" push "%PUSH_TMP%\profile.save" /data/local/tmp/sts_bridge/ >nul 2>&1
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge" >nul 2>&1
rmdir /s /q "%PUSH_TMP%" 2>nul
echo [3/4] 正在写入手机存档...
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile1/saves/history && mkdir -p files/default/1/profile1/saves/history'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile1/progress.save ]; then cat /data/local/tmp/sts_bridge/profile1/progress.save > files/default/1/profile1/saves/progress.save; fi'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile1/prefs.save ]; then cat /data/local/tmp/sts_bridge/profile1/prefs.save > files/default/1/profile1/saves/prefs.save; fi'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile1/current_run.save ]; then cat /data/local/tmp/sts_bridge/profile1/current_run.save > files/default/1/profile1/saves/current_run.save; fi'" >nul 2>&1
set "HIST_TMP=%~dp0hist_tmp"
rmdir /s /q "%HIST_TMP%" 2>nul
mkdir "%HIST_TMP%" 2>nul
"%ADB%" pull /data/local/tmp/sts_bridge/profile1/history/. "%HIST_TMP%" >nul 2>&1
set /a _hcnt=0
for %%x in ("%HIST_TMP%\*.run") do set /a _hcnt+=1
if !_hcnt! gtr 0 (
    echo  正在转换历史记录 (!_hcnt! 条^)...
    powershell -Command "$utf8=New-Object System.Text.UTF8Encoding $False; Get-ChildItem '%HIST_TMP%' -Filter *.run | ForEach-Object { $c=[System.IO.File]::ReadAllText($_.FullName,[System.Text.Encoding]::UTF8); $c=$c -replace '\"platform_type\":\s*\"steam\"','\"platform_type\": \"none\"'; $c=$c -replace '\"build_id\":\s*\"v0.98.1\"','\"build_id\": \"v0.98.0\"'; $c=$c.Replace("`r`n","`n").Replace("`r","`n"); [System.IO.File]::WriteAllText($_.FullName,$c,$utf8) }" >nul 2>&1
    "%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge/profile1/history" >nul 2>&1
    "%ADB%" push "%HIST_TMP%\." /data/local/tmp/sts_bridge/profile1/history/ >nul 2>&1
    for /f %%h in ('dir /b "%HIST_TMP%\*.run" 2^>nul') do (
        "%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/profile1/history/%%h > files/default/1/profile1/saves/history/%%h'" >nul 2>&1
    )
)
rmdir /s /q "%HIST_TMP%" 2>nul
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge" >nul 2>&1
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
"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
for %%p in (1 2 3) do mkdir "%TEMP_P%\profile%%p\history" 2>nul

echo [2/5] 正在从手机抓取存档...
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save" > "%TEMP_P%\profile.save" 2>nul
for %%z in ("%TEMP_P%\profile.save") do if %%~zz==0 (
    echo [错误] 读取手机存档失败
    echo [提示] 游戏未安装或未启动过，小米用户需开启「禁用权限监控」
    pause & goto MENU
)
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save" > "%TEMP_P%\profile%%p\progress.save" 2>nul
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/prefs.save" > "%TEMP_P%\profile%%p\prefs.save" 2>nul
    "%ADB%" shell "if run-as %PKG% ls files/default/1/profile%%p/saves/current_run.save >/dev/null 2>&1; then run-as %PKG% cat files/default/1/profile%%p/saves/current_run.save; fi" > "%TEMP_P%\profile%%p\current_run.save" 2>nul
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f" > "%TEMP_P%\profile%%p\history\%%f" 2>nul
    )
)
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save" > "%TEMP_P%\profile.save" 2>nul

echo [3/5] 正在统计历史记录...
set /a _total=0
for %%p in (1 2 3) do (
    set /a _c=0
    for %%x in ("%TEMP_P%\profile%%p\history\*.run") do set /a _c+=1
    if !_c! gtr 0 echo  [历史记录] profile%%p: !_c! 条
    set /a _total+=_c
)

echo [4/5] 正在执行无损适配并写入存档...
powershell -Command "$utf8=New-Object System.Text.UTF8Encoding $False; Get-ChildItem '%TEMP_P%' -Recurse -Include *.save | ForEach-Object { $c=[System.IO.File]::ReadAllText($_.FullName,[System.Text.Encoding]::UTF8); $c=$c -replace '\"platform_type\":\s*\"none\"','\"platform_type\": \"steam\"'; $c=$c -replace '\"build_id\":\s*\"v0.98.0\"','\"build_id\": \"v0.98.1\"'; [System.IO.File]::WriteAllText($_.FullName,$c,$utf8); (Get-Item $_.FullName).LastWriteTime=Get-Date }" >nul 2>&1
attrib -r "!PC_SAVE!\*.*" /s >nul 2>&1
if not "!REMOTE_SAVE!"=="" attrib -r "!REMOTE_SAVE!\*.*" /s >nul 2>&1
copy /y "%TEMP_P%\profile.save" "!PC_SAVE!\profile.save" >nul
for %%p in (1 2 3) do (
    if exist "!PC_SAVE!\profile%%p\saves\" (
        if exist "%TEMP_P%\profile%%p\progress.save"    copy /y "%TEMP_P%\profile%%p\progress.save"    "!PC_SAVE!\profile%%p\saves\progress.save" >nul
        if exist "%TEMP_P%\profile%%p\prefs.save"       copy /y "%TEMP_P%\profile%%p\prefs.save"       "!PC_SAVE!\profile%%p\saves\prefs.save" >nul
        if exist "%TEMP_P%\profile%%p\current_run.save" (
            copy /y "%TEMP_P%\profile%%p\current_run.save" "!PC_SAVE!\profile%%p\saves\current_run.save" >nul
        ) else (
            if exist "!PC_SAVE!\profile%%p\saves\current_run.save" del "!PC_SAVE!\profile%%p\saves\current_run.save"
        )
        if exist "!PC_SAVE!\profile%%p\saves\history" del /q "!PC_SAVE!\profile%%p\saves\history\*.run" >nul 2>&1
        robocopy "%TEMP_P%\profile%%p\history" "!PC_SAVE!\profile%%p\saves\history" /E /R:0 /W:0 >nul
    )
)
if not "!REMOTE_SAVE!"=="" (
    for %%p in (1 2 3) do (
        if exist "!REMOTE_SAVE!\profile%%p\saves\" (
            if exist "%TEMP_P%\profile%%p\progress.save"    copy /y "%TEMP_P%\profile%%p\progress.save"    "!REMOTE_SAVE!\profile%%p\saves\progress.save" >nul
            if exist "%TEMP_P%\profile%%p\prefs.save"       copy /y "%TEMP_P%\profile%%p\prefs.save"       "!REMOTE_SAVE!\profile%%p\saves\prefs.save" >nul
            if exist "%TEMP_P%\profile%%p\current_run.save" (
                copy /y "%TEMP_P%\profile%%p\current_run.save" "!REMOTE_SAVE!\profile%%p\saves\current_run.save" >nul
            ) else (
                if exist "!REMOTE_SAVE!\profile%%p\saves\current_run.save" del "!REMOTE_SAVE!\profile%%p\saves\current_run.save"
            )
            if exist "!REMOTE_SAVE!\profile%%p\saves\history" del /q "!REMOTE_SAVE!\profile%%p\saves\history\*.run" >nul 2>&1
            robocopy "%TEMP_P%\profile%%p\history" "!REMOTE_SAVE!\profile%%p\saves\history" /E /R:0 /W:0 >nul
        )
    )
    if exist "!REMOTE_SAVE!\..\..\remotecache.vdf" del /f /q "!REMOTE_SAVE!\..\..\remotecache.vdf"
)

echo [5/5] 正在清理旧备份...
rmdir /s /q "%TEMP_P%" 2>nul
call :CLEANUP "%PC_ROOT%"
echo [OK] 同步完成。共 !_total! 条历史记录。
pause & goto MENU

:RESTORE_PC
cls
echo ======= 恢复 PC 备份 =======
set /a cnt=0
for /d %%d in ("%PC_ROOT%\*") do (set /a cnt+=1 & set "f!cnt!=%%~nxd" & echo  [!cnt!] %%~nxd)
if %cnt%==0 (echo 暂无备份。 & pause & goto MENU)
echo.
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CONFIRM
attrib -r "!PC_SAVE!\*.*" /s >nul 2>&1
robocopy "%PC_ROOT%\!S_BK!" "!PC_SAVE!" /E /R:0 /W:0 >nul
if not "!REMOTE_SAVE!"=="" (
    attrib -r "!REMOTE_SAVE!\*.*" /s >nul 2>&1
    for %%p in (1 2 3) do (
        if exist "!PC_SAVE!\profile%%p\saves\" (
            robocopy "!PC_SAVE!\profile%%p\saves" "!REMOTE_SAVE!\profile%%p\saves" /E /R:0 /W:0 >nul
        )
    )
    if exist "!REMOTE_SAVE!\..\..\remotecache.vdf" del /f /q "!REMOTE_SAVE!\..\..\remotecache.vdf"
)
echo [OK] 已恢复: !S_BK!
pause & goto MENU

:RESTORE_MB
cls
echo ======= 恢复 Mobile 备份 =======
set /a cnt=0
for /d %%d in ("%MB_ROOT%\*") do (set /a cnt+=1 & set "f!cnt!=%%~nxd" & echo  [!cnt!] %%~nxd)
if %cnt%==0 (echo 暂无备份。 & pause & goto MENU)
echo.
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
echo [1/3] 正在推送备份到中转站...
"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge" >nul 2>&1
for %%p in (1 2 3) do (
    "%ADB%" shell "mkdir -p /data/local/tmp/sts_bridge/profile%%p/history" >nul 2>&1
    if exist "%MB_ROOT%\!S_BK!\profile%%p\progress.save"    "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\progress.save"    /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%MB_ROOT%\!S_BK!\profile%%p\prefs.save"       "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\prefs.save"       /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%MB_ROOT%\!S_BK!\profile%%p\current_run.save" "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\current_run.save" /data/local/tmp/sts_bridge/profile%%p/ >nul 2>&1
    if exist "%MB_ROOT%\!S_BK!\profile%%p\history"          "%ADB%" push "%MB_ROOT%\!S_BK!\profile%%p\history/." /data/local/tmp/sts_bridge/profile%%p/history/ >nul 2>&1
)
if exist "%MB_ROOT%\!S_BK!\profile.save" "%ADB%" push "%MB_ROOT%\!S_BK!\profile.save" /data/local/tmp/sts_bridge/ >nul 2>&1
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge" >nul 2>&1
echo [2/3] 正在写入手机存档...
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile.save ]; then cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save; fi'" >nul 2>&1
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile%%p/saves/history && mkdir -p files/default/1/profile%%p/saves/history'" >nul 2>&1
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/progress.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/progress.save > files/default/1/profile%%p/saves/progress.save; fi'" >nul 2>&1
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/prefs.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/prefs.save > files/default/1/profile%%p/saves/prefs.save; fi'" >nul 2>&1
    "%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/profile%%p/current_run.save ]; then cat /data/local/tmp/sts_bridge/profile%%p/current_run.save > files/default/1/profile%%p/saves/current_run.save; fi'" >nul 2>&1
)
"%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/profile1/history/*.run; do [ -f "$f" ] || continue; cat "$f" > "files/default/1/profile1/saves/history/$(basename $f)"; done'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/profile2/history/*.run; do [ -f "$f" ] || continue; cat "$f" > "files/default/1/profile2/saves/history/$(basename $f)"; done'" >nul 2>&1
"%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/profile3/history/*.run; do [ -f "$f" ] || continue; cat "$f" > "files/default/1/profile3/saves/history/$(basename $f)"; done'" >nul 2>&1
echo [3/3] 正在清理中转站...
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge" >nul 2>&1
echo [OK] 已恢复: !S_BK!
pause & goto MENU

:EXPORT_MB
call :CHECK_ADB
if not defined ADB_OK (pause & goto MENU)
call :CONFIRM
echo 正在导出...
set "EXP=%EXP_ROOT%\%ts%"
"%ADB%" shell "am force-stop %PKG%" >nul 2>&1
for %%p in (1 2 3) do mkdir "%EXP%\profile%%p\history" 2>nul
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save" > "%EXP%\profile.save" 2>nul
for %%p in (1 2 3) do (
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/progress.save" > "%EXP%\profile%%p\progress.save" 2>nul
    "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/prefs.save" > "%EXP%\profile%%p\prefs.save" 2>nul
    "%ADB%" shell "if run-as %PKG% ls files/default/1/profile%%p/saves/current_run.save >/dev/null 2>&1; then run-as %PKG% cat files/default/1/profile%%p/saves/current_run.save; fi" > "%EXP%\profile%%p\current_run.save" 2>nul
    for /f %%f in ('%ADB% shell "run-as %PKG% ls files/default/1/profile%%p/saves/history/ 2>/dev/null"') do (
        "%ADB%" shell "run-as %PKG% cat files/default/1/profile%%p/saves/history/%%f" > "%EXP%\profile%%p\history\%%f" 2>nul
    )
)
echo [OK] 导出完成，路径: %EXP%
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
echo   小米/红米  另需开启「禁用权限监控」
echo              否则工具无法读写游戏存档
echo.
echo   一加       若显示 offline
echo              关闭「自动撤销USB调试授权」
echo              并确认关闭了无线调试
echo              拔插USB线后重新点击允许授权
echo.
echo  [第二步] 用数据线连接电脑
echo  ----------------------------------------
echo   请使用原装线或支持数据传输的线
echo   连接后手机选择USB用途时选择「仅充电」
echo.
echo   若没有弹出USB用途选择
echo   在开发者选项中开启
echo   「允许仅充电模式下进行调试」
echo   然后拔插USB线重试
echo.
echo  [第三步] 允许USB调试授权
echo  ----------------------------------------
echo   手机弹出「允许USB调试」弹窗时点击允许
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
echo   offline        数据线接触不良，拔插重试
echo   操作静默失败   安全软件拦截ADB权限
echo                  请暂时关闭360/火绒/Defender
echo                  或将本工具目录加入白名单
echo.
echo ==========================================
pause & goto MENU

:: ------------------ [CLEANUP 保留最新N个备份] ------------------
:CLEANUP
set /a _cnt=0
for /d %%d in ("%~1\*") do set /a _cnt+=1
if !_cnt! leq %MAX_BK% exit /b
set /a _del=_cnt - MAX_BK
set /a _done=0
for /d %%d in ("%~1\*") do (
    if !_done! lss !_del! (
        rmdir /s /q "%%d" 2>nul
        set /a _done+=1
    )
)
exit /b