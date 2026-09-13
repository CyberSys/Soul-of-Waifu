@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Soul of Waifu v2.5.1 — WSL Shell

echo ==============================================
echo   Soul of Waifu v2.5.1 — WSL Shell
echo ==============================================
echo.
echo   Opens an interactive bash shell with the
echo   conda environment activated.
echo.

:: Check if WSL is available
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo   ERROR: WSL is not installed or not available.
    echo.
    echo   Install WSL with:
    echo     wsl --install
    echo.
    pause
    exit /b 1
)

:: Check if wsl.sh exists
if not exist "%~dp0wsl.sh" (
    echo   ERROR: wsl.sh not found in the project directory.
    pause
    exit /b 1
)

echo   Opening shell in Soul-of-Waifu environment...
echo.

wsl -e bash "%~dp0wsl.sh" cmd

echo.
echo   Shell session ended.
pause
