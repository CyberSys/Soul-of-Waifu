@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Путь к python внутри папки python_embeded (относительно этого .bat файла)
set PYTHON_PATH=%~dp0app\data\python.exe

:loop
echo.
set /p CMD=Введите модуль Python (например: pip install requests): 
if "!CMD!"=="" goto loop

:: Выполнение команды
"%PYTHON_PATH%" -m !CMD!

goto loop