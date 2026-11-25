@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "AVROOT=%%~fI\"
chcp 65001 >nul
title AVANTIPACK - Otimizacao para Jogos

:: ============================================================
::  AVANTIPACK  -  launcher (menu CMD)
::  Toda a logica fica em core\avanti.ps1 (PowerShell 5.1+)
:: ============================================================

:: Abre pelo atalho core\AVANTIPACK.lnk (logo, fonte Consolas, janela centralizada).
:: Quando ja veio pelo atalho, o primeiro parametro e "lnk".
if /i "%~1"=="lnk" goto checaradmin
if not exist "%~dp0janela.ps1" goto checaradmin
set "AVDESK="
if not exist "%~dp0dados\data\atalho.ok" set "AVDESK=-Desktop"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0janela.ps1" %AVDESK% >nul 2>&1
if errorlevel 1 goto checaradmin
if not exist "%~dp0AVANTIPACK.lnk" goto checaradmin
if not exist "%~dp0dados\data" mkdir "%~dp0dados\data" >nul 2>&1
if not exist "%~dp0dados\data\atalho.ok" echo ok>"%~dp0dados\data\atalho.ok"
start "" "%~dp0AVANTIPACK.lnk"
exit /b

:checaradmin
:: fltmc so funciona como administrador (o "net session" falha se o servico Servidor estiver desligado)
fltmc >nul 2>&1
if not errorlevel 1 goto inicio
net session >nul 2>&1
if errorlevel 1 goto elevar
goto inicio

:elevar
echo.
echo   Solicitando permissao de administrador...
set "AVSELF=%~f0"
powershell -NoProfile -Command "Start-Process -FilePath $env:AVSELF -Verb RunAs"
exit /b

:inicio
cd /d "%AVROOT%"
:: fonte Consolas, tamanho e posicao da janela (funciona mesmo sem o atalho)
if exist "%~dp0tela.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tela.ps1"
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "AZ=%ESC%[94m"
set "BR=%ESC%[97m"
set "CI=%ESC%[37m"
set "AM=%ESC%[93m"
set "VD=%ESC%[92m"
set "VM=%ESC%[91m"
set "RS=%ESC%[0m"
set "FAM=%ESC%[30;103m"
set "FVD=%ESC%[30;102m"
set "FAZ=%ESC%[97;44m"
set "AVPS=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0avanti.ps1" -Module"

if not exist "%~dp0avanti.ps1" (
  echo %PAD%  ERRO: arquivo core\avanti.ps1 nao encontrado. Extraia o pack inteiro antes de rodar.
  pause
  exit /b
)

set /p HW_VERSAO=<"%~dp0VERSION.txt"
call :calcpad
cls
call :banner
echo %PAD%  %CI%Detectando hardware e procurando avisos...%RS%
%AVPS% detect-silent
%AVPS% novidades-auto

:menu
set "MOD="
set "op="
call :carregarhw
call :calcpad
:: o menu com setas desenha a tela inteira (cabecalho + opcoes) do tamanho da janela
call :menusetas principal
if not defined SETAS_FALHOU goto menu_escolha
cls
call :banner
echo %PAD%  %CI%Seu PC:%RS% %HW_CPU%  %CI%+%RS%  %HW_GPU%
echo %PAD%  %CI%        %HW_RAM_GB% GB de RAM  -  disco %HW_DISK%  -  %HW_WIN%%RS%
if not "%HW_AJUSTES%"=="" if not "%HW_AJUSTES%"=="0" echo %PAD%  %VD%        %HW_AJUSTES% ajustes do AVANTIPACK ativos neste PC%RS%
echo.
if defined HW_ATUALIZACAO echo %PAD%  %FVD% NOVA VERSAO %HW_ATUALIZACAO% DO AVANTIPACK DISPONIVEL - digite U para atualizar %RS%
if defined HW_REAPLICAR echo %PAD%  %FAM% O WINDOWS FOI ATUALIZADO - use a opcao 1 e depois 3 (Reaplicar) %RS%
if defined HW_AVISO echo %PAD%  %FAM% %HW_AVISO% %RS%
echo %PAD%  %CI%==================================================================%RS%
echo.
echo %PAD%  %VD%[1]  OTIMIZAR MEU PC%RS%   %AM%^<-- comece por aqui%RS%
echo %PAD%       %CI%Automatico (o pack escolhe tudo) ou Personalizado (voce marca por%RS%
echo %PAD%       %CI%categoria o que quer). Limpa, ajusta energia, video, internet e jogos.%RS%
echo.
echo %PAD%  %AZ%[2]  VERIFICAR MEU PC%RS%
echo %PAD%       %CI%Pecas, problemas (memoria lenta, monitor em 60 Hz, driver velho...),%RS%
echo %PAD%       %CI%teste de INPUT LAG com pontuacao e teste da internet.%RS%
echo.
echo %PAD%  %AZ%[3]  CONSERTAR UM PROBLEMA%RS%
echo %PAD%       %CI%Sem internet, sem som, microfone, camera, Loja, Windows Update...%RS%
echo.
echo %PAD%  %AZ%[4]  PROGRAMAS UTEIS%RS%
echo %PAD%       %CI%Instala SOZINHO os programas e drivers certos para o seu PC, cada um%RS%
echo %PAD%       %CI%na sua pasta e com o passo a passo de configuracao.%RS%
echo.
echo %PAD%  %AZ%[5]  GUIAS PASSO A PASSO%RS%
echo %PAD%       %CI%Painel NVIDIA/AMD com imagens, BIOS, limite de FPS.%RS%
echo.
echo %PAD%  %VM%[6]  DESFAZER / RECOLOCAR FUNCOES E APPS%RS%
echo %PAD%       %CI%Desfaz tudo ou so o que voce escolher (impressora, gravar clipes...).%RS%
echo.
echo %PAD%  %AZ%[L]  LIMPEZA RAPIDA%RS%   %AZ%[J]  PREPARAR PARA JOGAR%RS%   %AM%[P]  AVANTIPACK PRO%RS%
echo.
echo %PAD%  %CI%[7]  Modo avancado (escolher cada ajuste)     [8] Reiniciar o PC     [0] Sair%RS%
echo.
echo %PAD%  %CI%==================================================================%RS%
echo.
set /p "op=%RS%%PAD%  %BR%Digite o numero e aperte ENTER:%RS% "

:menu_escolha
if "%op%"=="1" set "MOD=auto"
if "%op%"=="2" set "MOD=checkup"
if "%op%"=="3" set "MOD=fix"
if "%op%"=="4" set "MOD=apps"
if "%op%"=="5" set "MOD=guias"
if "%op%"=="6" set "MOD=undo"
if "%op%"=="7" goto avancado
if "%op%"=="8" goto reiniciar
if "%op%"=="0" goto sair
if /i "%op%"=="U" goto atualizar
if /i "%op%"=="L" set "MOD=limpeza"
if /i "%op%"=="J" set "MOD=prejogo"
if /i "%op%"=="P" set "MOD=pro"
if not defined MOD goto menu
call :rodar
goto menu

:avancado
set "MOD="
set "op="
call :calcpad
call :menusetas avancado
if not defined SETAS_FALHOU goto avancado_escolha
cls
call :banner
echo %PAD%  %BR%MODO AVANCADO%RS%  %CI%- escolha cada ajuste separado. Cada um explica o que faz antes.%RS%
echo.
echo %PAD%  %AZ%[1]%RS%  Ver hardware e alertas              %AZ%[2]%RS%  Checar placa de video e monitor
echo %PAD%  %AZ%[25]%RS% Nota do PC                          %AZ%[3]%RS%  Criar ponto de restauracao
echo %PAD%  %AZ%[26]%RS% Limpeza rapida                      %AZ%[27]%RS% Preparar para jogar
echo %PAD%  %AZ%[14]%RS% Guia de BIOS                        %AZ%[20]%RS% Atualizar o pack (GitHub)
echo %PAD%  %AZ%[21]%RS% Novidades                           %AZ%[29]%RS% Limpar cache de shaders
echo %PAD%  %AM%[28]%RS% Conheca o AVANTIPACK Pro
echo.
echo %PAD%  %CI%[0]  Voltar ao menu principal%RS%
echo.
set /p "op=%RS%%PAD%  %BR%Digite o numero e aperte ENTER:%RS% "
:avancado_escolha
if "%op%"=="1" set "MOD=detect"
if "%op%"=="2" set "MOD=verificar"
if "%op%"=="3" set "MOD=restore"
if "%op%"=="14" set "MOD=bios"
if "%op%"=="20" goto atualizar
if "%op%"=="21" set "MOD=novidades"
if "%op%"=="25" set "MOD=nota"
if "%op%"=="26" set "MOD=limpeza"
if "%op%"=="27" set "MOD=prejogo"
if "%op%"=="28" set "MOD=pro"
if "%op%"=="29" set "MOD=shaders"
if "%op%"=="0" goto menu
if not defined MOD goto avancado
call :rodar
goto avancado

:menusetas
:: Menu com setas (core\menu.ps1). Se falhar, SETAS_FALHOU fica definido
:: e o menu de digitar o numero aparece no lugar.
set "SETAS_FALHOU="
set "op="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0menu.ps1" -Tela %1
set "RC=%errorlevel%"
if "%RC%"=="122" (set "op=L" & exit /b)
if "%RC%"=="123" (set "op=J" & exit /b)
if "%RC%"=="124" (set "op=P" & exit /b)
if "%RC%"=="130" (set "op=U" & exit /b)
if %RC% GEQ 100 if %RC% LEQ 129 (set /a "op=RC-100" & exit /b)
set "SETAS_FALHOU=1"
exit /b

:calcpad
:: margem a esquerda para a tela ficar no meio quando a janela e larga
set "PAD="
set "AVL="
set "AVCOLS="
for /f "tokens=2 delims=:" %%a in ('mode con ^| findstr /r "[0-9]"') do (
  if defined AVL (if not defined AVCOLS set "AVCOLS=%%a") else set "AVL=%%a"
)
if not defined AVCOLS exit /b
set /a "AVPADN=(AVCOLS-84)/2" 2>nul
if not defined AVPADN exit /b
if %AVPADN% LSS 1 exit /b
for /l %%i in (1,1,%AVPADN%) do call set "PAD=%%PAD%% "
exit /b

:rodar
call :calcpad
cls
call :banner
%AVPS% %MOD%
echo.
echo %PAD%  %CI%Pressione qualquer tecla para voltar ao menu...%RS%
pause >nul
exit /b

:atualizar
echo.
echo %PAD%  %AZ%Abrindo o atualizador... este menu vai fechar e abrir de novo sozinho.%RS%
start "AVANTIPACK - Atualizacao" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0avanti.ps1" -Module atualizar
exit

:bios
set "MOD=bios"
goto rodar

:reiniciar
echo.
choice /c SN /n /m "  Reiniciar o PC agora? [S/N] "
if errorlevel 2 goto menu
shutdown /r /t 5 /c "AVANTIPACK: reiniciando para aplicar as otimizacoes"
goto sair

:sair
echo.
echo %PAD%  %AZ%Valeu por usar o AVANTIPACK.%RS%
timeout /t 2 >nul
exit /b

:carregarhw
set "HW_AJUSTES=" & set "HW_REAPLICAR=" & set "HW_AVISO=" & set "HW_ATUALIZACAO="
if not exist "%~dp0dados\data\hardware.txt" exit /b
for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0dados\data\hardware.txt") do set "HW_%%a=%%b"
exit /b

:banner
echo.
echo %PAD%      %ESC%[38;2;29;67;255m█%ESC%[38;2;28;69;255m█%ESC%[38;2;27;72;255m█   %ESC%[38;2;24;83;255m█   %ESC%[38;2;20;93;255m█   %ESC%[38;2;16;104;255m█%ESC%[38;2;15;106;255m█%ESC%[38;2;14;109;255m█   %ESC%[38;2;11;120;255m█   %ESC%[38;2;7;130;255m█  %ESC%[38;2;4;138;255m█%ESC%[38;2;3;141;255m█%ESC%[38;2;2;143;255m█%ESC%[38;2;1;146;255m█%ESC%[38;2;0;149;255m█  %ESC%[38;2;0;156;255m█%ESC%[38;2;0;158;255m█%ESC%[38;2;0;160;255m█  %ESC%[38;2;0;167;255m█%ESC%[38;2;0;170;255m█%ESC%[38;2;0;172;255m█%ESC%[38;2;0;174;255m█    %ESC%[38;2;0;186;255m█%ESC%[38;2;0;188;255m█%ESC%[38;2;0;190;255m█    %ESC%[38;2;0;202;255m█%ESC%[38;2;0;204;255m█%ESC%[38;2;0;207;255m█%ESC%[38;2;0;209;255m█  %ESC%[38;2;0;216;255m█   %ESC%[38;2;0;225;255m█%RS%
echo %PAD%     %ESC%[38;2;28;60;240m█   %ESC%[38;2;24;70;240m█  %ESC%[38;2;23;78;240m█   %ESC%[38;2;19;87;240m█  %ESC%[38;2;16;95;240m█   %ESC%[38;2;12;105;240m█  %ESC%[38;2;10;113;240m█%ESC%[38;2;9;115;240m█  %ESC%[38;2;7;122;240m█    %ESC%[38;2;2;134;240m█     %ESC%[38;2;0;149;240m█   %ESC%[38;2;0;157;240m█   %ESC%[38;2;0;166;240m█  %ESC%[38;2;0;172;240m█   %ESC%[38;2;0;181;240m█  %ESC%[38;2;0;188;240m█      %ESC%[38;2;0;203;240m█  %ESC%[38;2;0;210;240m█%RS%
echo %PAD%     %ESC%[38;2;26;56;224m█%ESC%[38;2;26;59;224m█%ESC%[38;2;25;61;224m█%ESC%[38;2;24;63;224m█%ESC%[38;2;23;66;224m█  %ESC%[38;2;21;73;224m█   %ESC%[38;2;18;82;224m█  %ESC%[38;2;15;89;224m█%ESC%[38;2;14;92;224m█%ESC%[38;2;13;93;224m█%ESC%[38;2;12;96;224m█%ESC%[38;2;11;99;224m█  %ESC%[38;2;10;106;224m█ %ESC%[38;2;8;110;224m█ %ESC%[38;2;6;114;224m█    %ESC%[38;2;2;126;224m█     %ESC%[38;2;0;139;224m█   %ESC%[38;2;0;147;224m█%ESC%[38;2;0;150;224m█%ESC%[38;2;0;151;224m█%ESC%[38;2;0;153;224m█   %ESC%[38;2;0;161;224m█%ESC%[38;2;0;164;224m█%ESC%[38;2;0;165;224m█%ESC%[38;2;0;167;224m█%ESC%[38;2;0;170;224m█  %ESC%[38;2;0;176;224m█      %ESC%[38;2;0;190;224m█%ESC%[38;2;0;192;224m█%ESC%[38;2;0;194;224m█%RS%
echo %PAD%     %ESC%[38;2;25;52;209m█   %ESC%[38;2;21;62;209m█   %ESC%[38;2;19;70;209m█ %ESC%[38;2;17;74;209m█   %ESC%[38;2;14;83;209m█   %ESC%[38;2;11;92;209m█  %ESC%[38;2;9;98;209m█  %ESC%[38;2;7;105;209m█%ESC%[38;2;6;107;209m█    %ESC%[38;2;2;117;209m█     %ESC%[38;2;0;130;209m█   %ESC%[38;2;0;137;209m█      %ESC%[38;2;0;150;209m█   %ESC%[38;2;0;158;209m█  %ESC%[38;2;0;164;209m█      %ESC%[38;2;0;177;209m█  %ESC%[38;2;0;183;209m█%RS%
echo %PAD%     %ESC%[38;2;23;49;194m█   %ESC%[38;2;20;57;194m█    %ESC%[38;2;17;67;194m█    %ESC%[38;2;13;77;194m█   %ESC%[38;2;10;85;194m█  %ESC%[38;2;8;91;194m█   %ESC%[38;2;5;99;194m█    %ESC%[38;2;2;109;194m█    %ESC%[38;2;0;119;194m█%ESC%[38;2;0;120;194m█%ESC%[38;2;0;122;194m█  %ESC%[38;2;0;127;194m█      %ESC%[38;2;0;139;194m█   %ESC%[38;2;0;147;194m█   %ESC%[38;2;0;154;194m█%ESC%[38;2;0;155;194m█%ESC%[38;2;0;157;194m█%ESC%[38;2;0;159;194m█  %ESC%[38;2;0;164;194m█   %ESC%[38;2;0;171;194m█%RS%
echo.
echo %PAD%%CI%     Otimizacao para jogos  ^|  v%HW_VERSAO%  ^|  rode sempre como administrador%RS%
echo.
exit /b
