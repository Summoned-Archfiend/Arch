@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Compare-FileHash.ps1" %*
