@echo off
chcp 65001 > nul
setlocal EnableDelayedExpansion

:: Configuration
set "SCRIPT_DIR=%~dp0"
set "SERVICE_BAT=zapret-discord-youtube-main\service.bat"
set "BACKUP_DIR=%SCRIPT_DIR%backup"
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt"
set "GITHUB_DOWNLOAD_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/latest/download/zapret-discord-youtube-"

:: Get local version
set "LOCAL_VERSION="
for /f "tokens=2 delims==" %%A in ('findstr "LOCAL_VERSION=" "%SCRIPT_DIR%%SERVICE_BAT%"') do (
    set "LOCAL_VERSION=%%A"
)
set "LOCAL_VERSION=!LOCAL_VERSION:"=!"
set "LOCAL_VERSION=!LOCAL_VERSION: =!"

if "!LOCAL_VERSION!"=="" (
    echo [ERROR] Could not determine local version
    goto :end
)

echo [INFO] Current local version: !LOCAL_VERSION!

:: Get latest version
echo [INFO] Checking for updates...
set "LATEST_VERSION="
for /f "delims=" %%A in ('powershell -Command "(Invoke-WebRequest -Uri '%GITHUB_VERSION_URL%' -TimeoutSec 10 -UseBasicParsing).Content.Trim()" 2^>nul') do (
    set "LATEST_VERSION=%%A"
)

if not defined LATEST_VERSION (
    echo [ERROR] Failed to fetch latest version
    goto :end
)

echo [INFO] Latest GitHub version: !LATEST_VERSION!

:: Compare versions
if "!LOCAL_VERSION!"=="!LATEST_VERSION!" (
    echo [INFO] You have the latest version. No update needed.
    goto :end
)

echo [UPDATE] New version available: !LATEST_VERSION!
echo [UPDATE] Starting automatic update...

:: Create backup
echo [BACKUP] Creating backup...
if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"
xcopy "!SCRIPT_DIR!zapret-discord-youtube-main" "!BACKUP_DIR!\zapret-discord-youtube-main" /E /I /H /Y >nul

:: Remove service
echo [SERVICE] Removing zapret service...
sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    net stop "zapret" >nul 2>&1
    sc delete "zapret" >nul 2>&1
    timeout /t 3 /nobreak >nul
)

:: Kill processes
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F >nul 2>&1
)

:: Download new version
echo [DOWNLOAD] Downloading new version !LATEST_VERSION!...
set "DOWNLOAD_FILE=!SCRIPT_DIR!zapret-discord-youtube-!LATEST_VERSION!.rar"

powershell -Command "Invoke-WebRequest -Uri '%GITHUB_DOWNLOAD_URL%!LATEST_VERSION!.rar' -OutFile '!DOWNLOAD_FILE!' -TimeoutSec 30" >nul 2>&1

if not exist "!DOWNLOAD_FILE!" (
    echo [ERROR] Failed to download new version
    goto :restore_service
)

:: Create temp directory for extraction
set "TEMP_EXTRACT=!SCRIPT_DIR!temp_extract_!RANDOM!"
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
    echo [ERROR] WinRAR or 7-zip required
    del "!DOWNLOAD_FILE!" >nul 2>&1
    rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1
    goto :restore_service
)

:: Cleanup download
del "!DOWNLOAD_FILE!" >nul 2>&1

:: Check if service.bat exists in temp directory
if not exist "!TEMP_EXTRACT!\service.bat" (
    echo [ERROR] service.bat not found in extracted files
    rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1
    goto :restore_service
)

:: Remove old zapret folder
if exist "!SCRIPT_DIR!zapret-discord-youtube-main\" (
    rmdir /s /q "!SCRIPT_DIR!zapret-discord-youtube-main" >nul 2>&1
)

:: Create new zapret folder
mkdir "!SCRIPT_DIR!zapret-discord-youtube-main\" >nul 2>&1

:: Copy all files from temp to target directory
echo [ORGANIZE] Copying files to zapret-discord-youtube-main...
xcopy "!TEMP_EXTRACT!\*" "!SCRIPT_DIR!zapret-discord-youtube-main\" /E /I /H /Y >nul

:: Cleanup temp directory
rmdir /s /q "!TEMP_EXTRACT!" >nul 2>&1

if not exist "!SCRIPT_DIR!zapret-discord-youtube-main\service.bat" (
    echo [ERROR] Files not copied correctly
    goto :restore_service
)

:: Reinstall service
echo [SERVICE] Reinstalling service...
cd /d "!SCRIPT_DIR!zapret-discord-youtube-main"

set "BIN_PATH=!SCRIPT_DIR!zapret-discord-youtube-main\bin\"
set "LISTS_PATH=!SCRIPT_DIR!zapret-discord-youtube-main\lists\"

net stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
timeout /t 3 /nobreak >nul

sc create zapret binPath= "\"!BIN_PATH!winws.exe\" --wf-tcp=80,443,2053,2083,2087,2096,8443,12 --wf-udp=443,19294-19344,50000-50100,12 --filter-udp=443 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-fake-quic=\"!BIN_PATH!quic_initial_www_google_com.bin\" --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=80 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake,fakedsplit --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-tcp=443 --hostlist=\"!LISTS_PATH!list-general.txt\" --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-udp=443 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-fake-quic=\"!BIN_PATH!quic_initial_www_google_com.bin\" --new --filter-tcp=80 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake,fakedsplit --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new --filter-tcp=443,12 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=\"!BIN_PATH!tls_clienthello_www_google_com.bin\" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --new --filter-udp=12 --ipset=\"!LISTS_PATH!ipset-all.txt\" --dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=10 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp=\"!BIN_PATH!quic_initial_www_google_com.bin\" --dpi-desync-cutoff=n2" DisplayName= "zapret" start= auto

sc description zapret "Zapret DPI bypass software"
sc start zapret

echo [SUCCESS] Update completed successfully! Version: !LATEST_VERSION!
goto :end

:restore_service
echo [RESTORE] Restoring from backup...
:: ... [rest of restore code remains the same] ...

:end
echo [INFO] Auto-update process finished
timeout /t 3 /nobreak >nul