@echo off
chcp 65001 > nul
setlocal EnableDelayedExpansion

echo ========================================
echo    Zapret Auto-Installer
echo ========================================
echo.

set "INSTALL_DIR=%~dp0"
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt"
set "GITHUB_DOWNLOAD_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/latest/download/zapret-discord-youtube-"

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ADMIN] Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [ADMIN] Running with administrator privileges
echo.

:: Check if already installed
if exist "!INSTALL_DIR!zapret-discord-youtube-main\service.bat" (
    echo [INFO] Zapret already installed.
    echo [INFO] Launching auto-updater instead...
    timeout /t 2 /nobreak >nul
    if exist "!INSTALL_DIR!auto_updater.bat" (
        call "!INSTALL_DIR!auto_updater.bat"
    )
    exit /b
)

:: Get latest version
echo [DOWNLOAD] Getting latest version info...
set "LATEST_VERSION="
for /f "delims=" %%A in ('powershell -Command "(Invoke-WebRequest -Uri '%GITHUB_VERSION_URL%' -TimeoutSec 10 -UseBasicParsing).Content.Trim()" 2^>nul') do (
    set "LATEST_VERSION=%%A"
)

if not defined LATEST_VERSION (
    echo [ERROR] Failed to fetch version from GitHub
    pause
    exit /b 1
)

echo [INFO] Latest version: !LATEST_VERSION!

:: Download
echo [DOWNLOAD] Downloading zapret !LATEST_VERSION!...
set "DOWNLOAD_FILE=!INSTALL_DIR!zapret-discord-youtube-!LATEST_VERSION!.rar"

powershell -Command "Invoke-WebRequest -Uri '%GITHUB_DOWNLOAD_URL%!LATEST_VERSION!.rar' -OutFile '!DOWNLOAD_FILE!' -TimeoutSec 60" >nul 2>&1

if not exist "!DOWNLOAD_FILE!" (
    echo [ERROR] Failed to download
    pause
    exit /b 1
)

:: Create temp directory for extraction
set "TEMP_EXTRACT=!INSTALL_DIR!temp_extract_!RANDOM!"
mkdir "!TEMP_EXTRACT!" >nul 2>&1

:: Extract to temp directory
echo [EXTRACT] Extracting files to temporary directory...
set "EXTRACT_SUCCESS=0"

if exist "%ProgramFiles%\WinRAR\WinRAR.exe" (
    "%ProgramFiles%\WinRAR\WinRAR.exe" x -y "!DOWNLOAD_FILE!" "!TEMP_EXTRACT!\" >nul
    set "EXTRACT_SUCCESS=1"
) else if exist "%ProgramFiles%\7-Zip\7z.exe" (
    "%ProgramFiles%\7-Zip\7z.exe" x "!DOWNLOAD_FILE!" -o"!TEMP_EXTRACT!\" -y >nul
    set "EXTRACT_SUCCESS=1"
) else (
    echo [ERROR] Install WinRAR or 7-zip
    del "!DOWNLOAD_FILE!" >nul 2>&1
    rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1
    pause
    exit /b 1
)

:: Cleanup download
del "!DOWNLOAD_FILE!" >nul 2>&1

:: Check if service.bat exists in temp directory
if not exist "!TEMP_EXTRACT!\service.bat" (
    echo [ERROR] service.bat not found in extracted files
    echo [DEBUG] Contents of temp directory:
    dir "!TEMP_EXTRACT!" /b
    rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1
    pause
    exit /b 1
)

echo [SUCCESS] Files extracted successfully!
echo [ORGANIZE] Creating zapret-discord-youtube-main folder...

:: Create target directory
if exist "!INSTALL_DIR!zapret-discord-youtube-main\" (
    rmdir /s /q "!INSTALL_DIR!zapret-discord-youtube-main\" >nul 2>&1
)
mkdir "!INSTALL_DIR!zapret-discord-youtube-main\" >nul 2>&1

:: Copy all files from temp to target directory
echo [ORGANIZE] Copying files to zapret-discord-youtube-main...
xcopy "!TEMP_EXTRACT!\*" "!INSTALL_DIR!zapret-discord-youtube-main\" /E /I /H /Y >nul

:: Cleanup temp directory
rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1

if not exist "!INSTALL_DIR!zapret-discord-youtube-main\service.bat" (
    echo [ERROR] Files not copied correctly
    pause
    exit /b 1
)

echo [SUCCESS] Files organized in zapret-discord-youtube-main folder!

:: Install service
echo [SERVICE] Installing zapret service...
cd /d "!INSTALL_DIR!zapret-discord-youtube-main"

set "BIN_PATH=!INSTALL_DIR!zapret-discord-youtube-main\bin\"
set "LISTS_PATH=!INSTALL_DIR!zapret-discord-youtube-main\lists\"

:: Remove existing service
net stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
timeout /t 2 /nobreak >nul

:: Create service
sc create zapret binPath= "\"!BIN_PATH!winws.exe\" --wf-tcp=80,443,2053,2083,2087,2096,8443,12 --wf-udp=443,19294-19344,50000-50100,12 --filter-udp=443 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-fake-quic=\"!BIN_PATH!quic_initial_www_google_com.bin\" --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=80 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake,fakedsplit --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-tcp=443 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-udp=443 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-fake-quic=\"!BIN_PATH!quic_initial_www_google_com.bin\" --new --filter-tcp=80 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake,fakedsplit --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new --filter-tcp=443,12 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-udp=12 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=10 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp=\"!BIN_PATH!quic_initial_www_google_com.bin\" --dpi-desync-cutoff=n2" DisplayName= "zapret" start= auto

sc description zapret "Zapret DPI bypass software"
sc start zapret
timeout /t 3 /nobreak >nul

:: Check service
sc query zapret | find "RUNNING" >nul
if !errorlevel!==0 (
    echo [SUCCESS] Service installed and running!
) else (
    echo [WARNING] Service created but may not be running
)

:: Create scheduled task for auto-updates
echo [SCHEDULER] Creating auto-update task...
powershell -Command "Register-ScheduledTask -TaskName 'Zapret AutoUpdater' -Action (New-ScheduledTaskAction -Execute '!INSTALL_DIR!auto_updater.bat') -Trigger (New-ScheduledTaskTrigger -AtStartup) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) -RunLevel Highest -Description 'Auto-updater for Zapret service'" >nul 2>&1

echo.
echo ========================================
echo    INSTALLATION COMPLETE!
echo ========================================
echo.
echo Installed:
echo ? Zapret files in: zapret-discord-youtube-main\
echo ? Windows Service: zapret (auto-start)
echo ? Scheduled Task: Zapret AutoUpdater
echo.
echo Folder structure:
echo !INSTALL_DIR!
echo ??? install_zapret.bat
echo ??? auto_updater.bat
echo ??? uninstall_zapret.bat
echo ??? zapret-discord-youtube-main/
echo     ??? service.bat
echo     ??? general (FAKE TLS AUTO ALT3).bat
echo     ??? bin/
echo     ??? lists/
echo     ??? ...
echo.
echo Press any key to exit...
pause >nul