@echo off
title AVANTIPACK - gerar nova versao
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gerar_release.ps1"
