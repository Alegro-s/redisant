@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "EXE=%~dp0companion\RozaCompanion\bin\Release\net8.0\RozaCompanion.exe"
if exist "%EXE%" (
  start "" "%EXE%"
  exit /b 0
)
set "EXED=%~dp0companion\RozaCompanion\bin\Debug\net8.0\RozaCompanion.exe"
if exist "%EXED%" (
  start "" "%EXED%"
  exit /b 0
)
where dotnet >nul 2>&1
if errorlevel 1 (
  echo Установите .NET SDK и соберите проект: dotnet build companion\RozaCompanion\RozaCompanion.csproj -c Release
  pause
  exit /b 1
)
echo Сборка Roza AI (RozaCompanion)...
dotnet build "%~dp0companion\RozaCompanion\RozaCompanion.csproj" -c Release
if exist "%EXE%" start "" "%EXE%" & exit /b 0
if exist "%EXED%" start "" "%EXED%" & exit /b 0
echo Запуск через dotnet run...
dotnet run --project "%~dp0companion\RozaCompanion\RozaCompanion.csproj" -c Release
if errorlevel 1 pause
