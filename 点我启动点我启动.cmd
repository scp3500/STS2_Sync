@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: =================配置区=================
set "ADB=%~dp0adb\adb.exe"
set "PKG=com.megacrit.sts2"
set "APPID=2868840"

:: 自动定位 AppData 存档区
set "STEAM_ROOT=%AppData%\SlayTheSpire2\steam"
for /d %%i in ("%STEAM_ROOT%\76*") do set "PC_SAVE=%%i"

:: 自动抓取 Steam 安装路径并定位 Remote 镜像区
for /f "tokens=2*" %%a in ('reg query "HKEY_CURRENT_USER\Software\Valve\Steam" /v "SteamPath" 2^>nul') do set "STEAM_INSTALL=%%b"
set "STEAM_INSTALL=!STEAM_INSTALL:/=\!"
set "REMOTE_SAVE="
if exist "!STEAM_INSTALL!\userdata" (
    for /d %%d in ("!STEAM_INSTALL!\userdata\*") do (
        if exist "%%d\!APPID!\remote\profile1\saves" set "REMOTE_SAVE=%%d\!APPID!\remote\profile1\saves"
    )
)

set "MB_ROOT=%~dp0Mobile_Saves_Backup"
set "PC_ROOT=%~dp0PC_Saves_Backup"
set "EXP_ROOT=%~dp0Mobile_Export"

if not exist "%ADB%" (echo [错误] 找不到 adb\adb.exe && pause && exit)

:MENU
cls
echo ==========================================
echo               STS2 SYNC
echo ==========================================
echo  [同步]
echo    1. 同步到手机 (PC -^> 手机)
echo    2. 同步到电脑 (手机 -^> PC 双路覆盖)
echo.
echo  [恢复]
echo    3. 恢复电脑存档
echo    4. 恢复手机存档
echo.
echo  [工具]
echo    5. 导出手机存档
echo    6. 退出
echo ------------------------------------------
set /p opt=请选择: 

for /f %%i in ('powershell -noprofile -command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "ts=%%i"
if "%opt%"=="1" goto TO_MOBILE
if "%opt%"=="2" goto TO_PC
if "%opt%"=="3" goto RESTORE_PC
if "%opt%"=="4" goto RESTORE_MB
if "%opt%"=="5" goto EXPORT_MB
if "%opt%"=="6" exit
goto MENU

:CONFIRM
echo.
set /p confirm=确认执行此操作吗? (y/n): 
if /i "!confirm!"=="y" goto :EOF
echo [已取消] & pause & goto MENU

:: ------------------ [1. 同步到手机] ------------------
:TO_MOBILE
if "!PC_SAVE!"=="" (echo 找不到PC存档！ & pause & goto MENU)
call :CONFIRM
echo [1/3] 备份手机旧档并准备数据...
set "BK=%MB_ROOT%\%ts%"
mkdir "%BK%\history" 2>nul
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "run-as %PKG% sh -c 'cat files/default/1/profile.save'" > "%BK%\profile.save" 2>nul
"%ADB%" shell "run-as %PKG% sh -c 'cat files/default/1/profile1/saves/progress.save'" > "%BK%\progress.save" 2>nul
for /f %%f in ('"%ADB%" shell "run-as %PKG% ls files/default/1/profile1/saves/history/"') do ("%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/history/%%f" > "%BK%\history\%%f" 2>nul)

"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge/history"
"%ADB%" push "!PC_SAVE!\profile.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "!PC_SAVE!\profile1\saves\progress.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "!PC_SAVE!\profile1\saves\prefs.save" /data/local/tmp/sts_bridge/ >nul
if exist "!PC_SAVE!\profile1\saves\current_run.save" "%ADB%" push "!PC_SAVE!\profile1\saves\current_run.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "!PC_SAVE!\profile1\saves\history/." /data/local/tmp/sts_bridge/history/ >nul
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"

echo [2/3] 写入手机并适配 (Steam-^>None)...
"%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile1/saves/history && mkdir -p files/default/1/profile1/saves/history'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/progress.save > files/default/1/profile1/saves/progress.save'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/prefs.save > files/default/1/profile1/saves/prefs.save'"
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/current_run.save ]; then cat /data/local/tmp/sts_bridge/current_run.save > files/default/1/profile1/saves/current_run.save; fi'"
"%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/history/*.run; do sed \"s/\\\"platform_type\\\": \\\"steam\\\"/\\\"platform_type\\\": \\\"none\\\"/g; s/\\\"build_id\\\": \\\"v0.98.1\\\"/\\\"build_id\\\": \\\"v0.98.0\\\"/g\" \"$f\" > \"files/default/1/profile1/saves/history/$(basename \"$f\")\"; done'"

echo [3/3] 清理...
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [OK] 已同步至手机。
pause & goto MENU

:: ------------------ [2. 同步到电脑] ------------------
:TO_PC
if "!PC_SAVE!"=="" (echo 找不到PC存档！ & pause & goto MENU)
call :CONFIRM
echo [1/4] 备份 PC 旧档...
robocopy "!PC_SAVE!" "%PC_ROOT%\%ts%" /E /R:0 /W:0 >nul

echo [2/4] 从手机抓取存档...
set "TEMP=%~dp0temp_pull"
rmdir /s /q "%TEMP%" 2>nul & mkdir "%TEMP%\history" 2>nul
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge/history"
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save > /data/local/tmp/sts_bridge/profile.save"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/progress.save > /data/local/tmp/sts_bridge/progress.save"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/prefs.save > /data/local/tmp/sts_bridge/prefs.save"
"%ADB%" shell "if run-as %PKG% ls files/default/1/profile1/saves/current_run.save >/dev/null 2>&1; then run-as %PKG% cat files/default/1/profile1/saves/current_run.save > /data/local/tmp/sts_bridge/current_run.save; fi"
for /f %%f in ('"%ADB%" shell "run-as %PKG% ls files/default/1/profile1/saves/history/"') do ("%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/history/%%f > /data/local/tmp/sts_bridge/history/%%f")
"%ADB%" pull /data/local/tmp/sts_bridge/. "%TEMP%" >nul

echo [3/4] 执行反向适配 (None-^>Steam)...
for /r "%TEMP%" %%f in (*.run *.save) do (
    powershell -Command "$utf8NoBom = New-Object System.Text.UTF8Encoding $False; $c = Get-Content '%%f' -Raw; $c = $c -replace '\"platform_type\":\s*\"none\"', '\"platform_type\": \"steam\"'; $c = $c -replace '\"build_id\":\s*\"v0.98.0\"', '\"build_id\": \"v0.98.1\"'; [System.IO.File]::WriteAllText('%%f', $c, $utf8NoBom)"
    powershell -Command "(Get-Item '%%f').LastWriteTime = Get-Date"
)

echo [4/4] 执行【双路暴力覆盖】...
:: 强行解锁所有目标文件的只读属性
attrib -r "!PC_SAVE!\*.*" /s >nul 2>&1
if not "!REMOTE_SAVE!"=="" attrib -r "!REMOTE_SAVE!\*.*" /s >nul 2>&1

:: 覆盖 AppData
copy /y "%TEMP%\profile.save" "!PC_SAVE!\profile.save" >nul
copy /y "%TEMP%\progress.save" "!PC_SAVE!\profile1\saves\progress.save" >nul
copy /y "%TEMP%\prefs.save" "!PC_SAVE!\profile1\saves\prefs.save" >nul
if exist "%TEMP%\current_run.save" (copy /y "%TEMP%\current_run.save" "!PC_SAVE!\profile1\saves\current_run.save" >nul) else (if exist "!PC_SAVE!\profile1\saves\current_run.save" del "!PC_SAVE!\profile1\saves\current_run.save")
robocopy "%TEMP%\history" "!PC_SAVE!\profile1\saves\history" /E /R:0 /W:0 >nul

:: 覆盖 Remote 镜像区
if not "!REMOTE_SAVE!"=="" (
    echo [INFO] 正在同步至 Steam 镜像区...
    copy /y "%TEMP%\progress.save" "!REMOTE_SAVE!\progress.save" >nul
    copy /y "%TEMP%\prefs.save" "!REMOTE_SAVE!\prefs.save" >nul
    if exist "%TEMP%\current_run.save" (copy /y "%TEMP%\current_run.save" "!REMOTE_SAVE!\current_run.save" >nul) else (if exist "!REMOTE_SAVE!\current_run.save" del "!REMOTE_SAVE!\current_run.save")
    robocopy "%TEMP%\history" "!REMOTE_SAVE!\history" /E /R:0 /W:0 >nul
    if exist "!REMOTE_SAVE!\..\..\remotecache.vdf" del /f /q "!REMOTE_SAVE!\..\..\remotecache.vdf"
)

rmdir /s /q "%TEMP%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [SUCCESS] 同步回电脑完成。
pause & goto MENU

:: ------------------ [恢复 / 导出 逻辑不变] ------------------
:RESTORE_PC
cls
echo ======= 选择 PC 备份 =======
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
echo ======= 选择 手机 备份 =======
set /a cnt=0
for /d %%d in ("%MB_ROOT%\*") do (set /a cnt+=1 & set "f!cnt!=%%~nxd" & echo  [!cnt!] %%~nxd)
set /p sel=序号: 
set "S_BK=!f%sel%!"
if "!S_BK!"=="" goto MENU
call :CONFIRM
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge/history"
"%ADB%" push "%MB_ROOT%\!S_BK!\profile.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "%MB_ROOT%\!S_BK!\progress.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "%MB_ROOT%\!S_BK!\prefs.save" /data/local/tmp/sts_bridge/ >nul
if exist "%MB_ROOT%\!S_BK!\current_run.save" "%ADB%" push "%MB_ROOT%\!S_BK!\current_run.save" /data/local/tmp/sts_bridge/ >nul
"%ADB%" push "%MB_ROOT%\!S_BK!\history/." /data/local/tmp/sts_bridge/history/ >nul
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
"%ADB%" shell "run-as %PKG% sh -c 'rm -rf files/default/1/profile1/saves/history && mkdir -p files/default/1/profile1/saves/history'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/profile.save > files/default/1/profile.save'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/progress.save > files/default/1/profile1/saves/progress.save'"
"%ADB%" shell "run-as %PKG% sh -c 'cat /data/local/tmp/sts_bridge/prefs.save > files/default/1/profile1/saves/prefs.save'"
"%ADB%" shell "run-as %PKG% sh -c 'if [ -f /data/local/tmp/sts_bridge/current_run.save ]; then cat /data/local/tmp/sts_bridge/current_run.save > files/default/1/profile1/saves/current_run.save; fi'"
"%ADB%" shell "run-as %PKG% sh -c 'for f in /data/local/tmp/sts_bridge/history/*.run; do cat \"$f\" > \"files/default/1/profile1/saves/history/$(basename \"$f\")\"; done'"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [OK] 已恢复。
pause & goto MENU

:EXPORT_MB
echo 正在导出...
set "EXP=%EXP_ROOT%\%ts%"
mkdir "%EXP%\history" 2>nul
"%ADB%" shell "am force-stop %PKG%"
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge && mkdir -p /data/local/tmp/sts_bridge/history"
"%ADB%" shell "chmod -R 777 /data/local/tmp/sts_bridge"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile.save > /data/local/tmp/sts_bridge/profile.save"
"%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/progress.save > /data/local/tmp/sts_bridge/progress.save"
for /f %%f in ('"%ADB%" shell "run-as %PKG% ls files/default/1/profile1/saves/history/"') do ("%ADB%" shell "run-as %PKG% cat files/default/1/profile1/saves/history/%%f > /data/local/tmp/sts_bridge/history/%%f")
"%ADB%" pull /data/local/tmp/sts_bridge/. "%EXP%" >nul
"%ADB%" shell "rm -rf /data/local/tmp/sts_bridge"
echo [OK] 导出至: %EXP%
pause & goto MENU