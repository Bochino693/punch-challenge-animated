@echo off
setlocal
chcp 65001 >nul
title Punch Challenge - Gerador do personagem
cd /d "%~dp0"

echo Gerando o boxeador animado do Punch Challenge...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gerar_personagem_windows.ps1" %*
if errorlevel 1 (
  echo.
  echo Nao foi possivel gerar o personagem. Veja a mensagem acima.
  pause
  exit /b 1
)

echo.
echo Personagem criado com sucesso.
pause
exit /b 0
