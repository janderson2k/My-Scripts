@echo off
title #SLock 3.1.2
setlocal enabledelayedexpansion

:: Initialization
del /f /q counter.txt 2>nul
set /a counter=0
set "currentPath=%cd%"
set "username=%username%"
for /f "tokens=5-7" %%a in ('quser ^| find /i "%username%"') do set logintime1=%%a %%b %%c
set "logintime2=%logintime1:~5%"
set "currentHour=%time:~0,2%"
set "currentMinute=%time:~3,2%"
set "currentSecond=%time:~6,2%"
set "formattedTime=%currentHour%:%currentMinute%:%currentSecond%"

:: Display header
cls
echo SLock Version 3.1.2 - 2025
echo Keep your computer awake for a given time
echo TheLatencyLounge.com
echo.
set /p hours="Enter the number of hours to keep the script running (whole hours only): "

:: Calculate duration
set /a duration=%hours%*6
set /a DURATION2=%duration%*10

:: Calculate exit time
for /f "tokens=1-2 delims=:" %%a in ("%time%") do (
    set /a exitHour=1%%a %% 100 + %DURATION2% / 60
    set /a exitMinute=1%%b %% 100 + %DURATION2% %% 60
)
if %exitMinute% geq 60 (
    set /a exitHour+=1
    set /a exitMinute-=60
)
if %exitHour% geq 24 set /a exitHour-=24
if %exitHour% lss 10 set "exitHour=0%exitHour%"
if %exitMinute% lss 10 set "exitMinute=0%exitMinute%"
set "exitTime=%exitHour%:%exitMinute%"

:: Log start
echo [%date% %time%] SLock started for %hours% hour(s) >> SLock_Log.txt

:loop
set /a counter+=1
set /a remaining=%duration% - %counter%
set /a remainingMinutes=%remaining% * 10
set /a progress=(%counter% * 10) / %duration%

:: Build fixed-width progress bar (10 characters)
set "bar="
for /L %%i in (1,1,10) do (
    if %%i==!progress! (
        set "bar=!bar!|"
    ) else (
        set "bar=!bar!= "
    )
)

cls
title #SLock : Cycle !counter! of %duration%
echo SLock 3.1.2 - TheLatencyLounge.com
echo -------------------------------------
echo Total runtime         : %DURATION2% minutes
echo Last logon time       : %logintime2%
echo Script launch time    : %formattedTime%
echo Estimated exit time   : %exitTime%
echo Current cycle         : !counter! of %duration%
echo Time remaining        : !remainingMinutes! minutes
echo Progress              : [!bar!] !progress!0%%
echo -------------------------------------
echo Waiting 10 minutes...

:: Wait 600 seconds (10 minutes)
TIMEOUT /T 600 >nul

:: Simulate activity
echo Set wsc = CreateObject("WScript.Shell") > "%currentPath%\SLOCK2.vbs"
echo wsc.SendKeys "+" >> "%currentPath%\SLOCK2.vbs"
cscript //nologo "%currentPath%\SLOCK2.vbs"
del /f /q "%currentPath%\SLOCK2.vbs"

:: Exit condition
if !counter! geq %duration% goto end
goto loop

:end
echo [%date% %time%] SLock completed after %hours% hour(s) >> SLock_Log.txt

:: Show tray notification using PowerShell
powershell -command "& {
    [reflection.assembly]::loadwithpartialname('System.Windows.Forms') | Out-Null;
    $notify = new-object system.windows.forms.notifyicon;
    $notify.icon = [System.Drawing.SystemIcons]::Information;
    $notify.visible = $true;
    $notify.showballoontip(10000, 'SLock Complete', 'Your system stayed awake for %hours% hour(s).', [system.windows.forms.tooltipicon]::Info);
    Start-Sleep -Seconds 10;
    $notify.dispose()
}"

echo.
echo SLock has completed. Your system stayed awake for %hours% hour(s).
exit /b
