@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Soul of Waifu v2.5.1 — WSL Launcher

echo ==============================================
echo   Soul of Waifu v2.5.1 — WSL Launcher
echo ==============================================
echo.
echo   Usage:
echo     start_wsl.bat              — Launch the application
echo     start_wsl.bat install      — First-time install (PyTorch + dependencies)
echo     start_wsl.bat cmd          — Open interactive shell in conda env
echo.

:: Check if WSL is available
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo   ERROR: WSL is not installed or not available.
    echo.
    echo   Install WSL with:
    echo     wsl --install
    echo.
    echo   Then restart your computer and run this script again.
    pause
    exit /b 1
)

:: Check if wsl.sh exists in the script's directory
if not exist "%~dp0wsl.sh" (
    echo   ERROR: wsl.sh not found in the project directory.
    echo   Make sure this script is in the Soul-of-Waifu-v2.5.1 folder.
    pause
    exit /b 1
)

echo   Launching via WSL...
echo.

:: Check for argument
if "%~1"=="install" (
    echo   [Install mode] Setting up Miniconda, conda env, PyTorch, and dependencies...
    echo.
    wsl -e bash "%~dp0wsl.sh" install
) else if "%~1"=="cmd" (
    echo   [Shell mode] Opening interactive bash with conda environment activated...
    echo.
    wsl -e bash "%~dp0wsl.sh" cmd
) else if "%~1"=="--help" (
    echo   Help displayed above. No action taken.
    pause
    exit /b 0
) else if "%~1"=="" (
    echo   [Launch mode] Starting Soul of Waifu...
    echo.
    wsl -e bash "%~dp0wsl.sh"
) else (
    echo   Unknown argument: %~1
    echo   Run 'start_wsl.bat --help' for usage.
    pause
    exit /b 1
)

echo.
echo   WSL session ended.
pause
