@echo off
setlocal

set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
set "ALIAS_ROOT=%APP_DIR:~0,2%"
set "ALIAS_DIR=%ALIAS_ROOT%\gas_customer_app_ascii"

if not exist "%ALIAS_DIR%\pubspec.yaml" (
  if exist "%ALIAS_DIR%" (
    echo The alias path "%ALIAS_DIR%" already exists and is not linked to this app.
    echo Remove it manually, then run this script again.
    exit /b 1
  )

  mklink /J "%ALIAS_DIR%" "%APP_DIR%" >NUL
  if errorlevel 1 (
    echo Failed to create ASCII alias at "%ALIAS_DIR%".
    exit /b 1
  )
)

pushd "%ALIAS_DIR%" >NUL
if errorlevel 1 (
  echo Failed to enter alias directory "%ALIAS_DIR%".
  exit /b 1
)

if "%~1"=="" (
  flutter run
) else (
  flutter %*
)

set "EXIT_CODE=%ERRORLEVEL%"
popd >NUL
exit /b %EXIT_CODE%
