@echo off
chcp 65001 > nul
setlocal EnableDelayedExpansion

echo ========================================
echo    Zapret FORCE Uninstaller
echo ========================================
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ADMIN] Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [ADMIN] Running with administrator privileges
echo.

echo [WARNING] THIS IS FORCE UNINSTALL!
echo [INFO] This script will NOT delete itself or other bat files.
set /p "CONFIRM=Are you sure? (type 'YES' to confirm): "

if /i not "!CONFIRM!"=="YES" (
    echo [CANCELLED] Uninstall cancelled.
    timeout /t 3 /nobreak >nul
    exit /b
)

echo.
echo [FORCE UNINSTALL] Starting removal...
echo.

set "SCRIPT_DIR=%~dp0"

:: 1. Stop zapret processes
echo [PROCESSES] Stopping zapret processes...
taskkill /IM winws.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul

:: 2. Remove services
echo [SERVICES] Removing zapret services...

for %%S in (
    zapret
    WinDivert
    WinDivert14
    GoodbyeDPI
    discordfix_zapret
    winws1
    winws2
) do (
    sc query "%%S" >nul 2>&1
    if !errorlevel!==0 (
        echo [SERVICE] Removing: %%S
        net stop "%%S" >nul 2>&1
        sc delete "%%S" >nul 2>&1
    )
)

:: 3. Remove scheduled task
echo [SCHEDULER] Removing scheduled task...
schtasks /delete /tn "Zapret AutoUpdater" /f >nul 2>&1

:: 4. Remove registry entries
echo [REGISTRY] Cleaning registry entries...
reg delete "HKLM\System\CurrentControlSet\Services\zapret" /f >nul 2>&1
reg delete "HKLM\System\CurrentControlSet\Services\WinDivert" /f >nul 2>&1
reg delete "HKLM\System\CurrentControlSet\Services\WinDivert14" /f >nul 2>&1

:: 5. Remove files with retry logic
echo [FILES] Removing zapret files...

:: Remove main folder with multiple attempts
if exist "!SCRIPT_DIR!zapret-discord-youtube-main\" (
    echo [FILES] Removing main folder...
    
    set "attempt=1"
    :remove_loop
    echo [ATTEMPT !attempt!] Trying to remove folder...
    
    rmdir /s /q "!SCRIPT_DIR!zapret-discord-youtube-main" >nul 2>&1
    
    if exist "!SCRIPT_DIR!zapret-discord-youtube-main\" (
        set /a attempt+=1
        if !attempt! leq 3 (
            echo [WAIT] Waiting for files to unlock...
            timeout /t 3 /nobreak >nul
            goto remove_loop
        ) else (
            echo [WARNING] Could not remove folder - may be locked
            echo [INFO] You may need to restart your computer
        )
    ) else (
        echo [SUCCESS] Folder removed
    )
)

:: Remove other folders
for %%D in ("!SCRIPT_DIR!backup") do (
    if exist "%%D\" (
        echo [FILES] Removing: %%D
        rmdir /s /q "%%D" >nul 2>&1
    )
)

:: Remove downloaded files
for %%F in ("!SCRIPT_DIR!zapret-discord-youtube-*.rar") do (
    if exist "%%F" (
        echo [FILES] Removing: %%F
        del /f /q "%%F" >nul 2>&1
    )
)

:: 6. Cleanup temporary files
echo [CLEANUP] Cleaning temporary files...
del /f /q "%TEMP%\zapret-*" >nul 2>&1
del /f /q "%TEMP%\winws*" >nul 2>&1
del /f /q "%TEMP%\temp_extract_*" >nul 2>&1

:: 7. Final verification
echo.
echo [VERIFICATION] Final check...

set "problems=0"

sc query zapret >nul 2>&1
if !errorlevel!==0 (
    echo [?] Service 'zapret' removed
) else (
    echo [?] Service 'zapret' still exists
    set /a problems+=1
)

schtasks /query /tn "Zapret AutoUpdater" >nul 2>&1
if !errorlevel!==0 (
    echo [?] Scheduled task removed
) else (
    echo [?] Scheduled task still exists
    set /a problems+=1
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    echo [?] No winws processes running
) else (
    echo [?] winws processes still running
    set /a problems+=1
)

if exist "!SCRIPT_DIR!zapret-discord-youtube-main\" (
    echo [?] Zapret folder still exists
    set /a problems+=1
else (
    echo [?] Zapret folder removed
)

echo.
echo ========================================
if !problems!==0 (
    echo    UNINSTALL COMPLETE!
    echo    ? Everything removed successfully!
) else (
    echo    UNINSTALL PARTIALLY COMPLETE
    echo    ??  Found !problems! issue(s)
    echo.
    echo RECOMMENDED:
    echo 1. Restart your computer
    echo 2. Run uninstall again if needed
)
echo ========================================
echo.
echo Press any key to exit...
pause >nul