@echo off
echo ===================================================
echo     Jodo Library - Maestro Automated Test Suite
echo ===================================================
echo Checking connected devices...
adb devices
echo.

set MAESTRO_BAT="%USERPROFILE%\.maestro\maestro\bin\maestro.bat"

if not exist %MAESTRO_BAT% (
    echo [ERROR] Maestro executable not found at %MAESTRO_BAT%
    pause
    exit /b 1
)

echo Running Maestro End-to-End Tests...
echo.

if "%~1"=="" (
    call %MAESTRO_BAT% test .maestro/
) else (
    call %MAESTRO_BAT% test .maestro/%~1
)

echo.
echo ===================================================
echo Tests completed!
echo ===================================================
pause
