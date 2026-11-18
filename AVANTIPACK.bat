@echo off
:: Compatibilidade com o atualizador das versoes 0.7.3/0.7.4.
:: O AVANTIPACK apaga este arquivo sozinho na primeira vez que abrir.
if exist "%~dp0AVANTIPACK.exe" (start "" "%~dp0AVANTIPACK.exe") else (call "%~dp0core\AVANTIPACK.bat" %*)
