@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

REM ============================================================
REM  Daliil Ay Khidma v3 - Windows setup
REM
REM  Usage:
REM      setup.bat
REM      setup.bat "D:\path\to\daliil-ay-khidma-v2.01-master"
REM
REM  Reads from the v2 folder. Never writes into it.
REM ============================================================

cd /d "%~dp0"

set "REMOTE=https://github.com/sendoo-m/daliil-ay-khidma-v3.01.git"

echo.
echo ============================================
echo   Daliil Ay Khidma  -  v3 setup
echo ============================================
echo   Working in: %CD%
echo.

REM ---------- 0. sanity check ----------
if not exist "mobile\packages\dalil_core\pubspec.yaml" (
    echo   [X] Wrong folder.
    echo.
    echo   Run this from the folder that contains setup.bat,
    echo   README.md and the 'mobile' folder.
    echo.
    pause
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo   [X] Git not found. Install from https://git-scm.com
    echo.
    pause
    exit /b 1
)

REM ---------- 1. locate v2 ----------
echo [1/6] Locating v2 folder
echo.

set "V2=%~1"

REM strip trailing backslash and a trailing manage.py if given
if defined V2 (
    if /i "!V2:~-9!"=="manage.py" set "V2=!V2:~0,-10!"
    if "!V2:~-1!"=="\" set "V2=!V2:~0,-1!"
)

if not defined V2 (
    for %%D in (
        "%CD%\..\daliil-ay-khidma-v2.01-master"
        "%CD%\..\daliil-ay-khidma-v2.01"
        "%USERPROFILE%\Downloads\daliil-ay-khidma-v2.01-master"
        "%USERPROFILE%\Downloads\daliil-ay-khidma-v2.01"
        "%USERPROFILE%\Desktop\daliil-ay-khidma-v2.01-master"
    ) do (
        if not defined V2 if exist "%%~D\manage.py" set "V2=%%~fD"
    )
)

if not defined V2 goto :no_v2
if not exist "%V2%\manage.py" goto :no_v2

echo   [OK] v2 found: %V2%
if exist "%V2%\mobile\dalil_app\pubspec.yaml" (
    echo   [OK] user app found
    set "HAS_USER=1"
) else (
    echo   [!]  mobile\dalil_app not found - copy it manually later
    set "HAS_USER="
)
echo.

REM ---------- 2. stash new v3 backend files ----------
echo [2/6] Saving new v3 files
set "STAGE=%TEMP%\dalil_v3_stage"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%" >nul 2>&1

if exist "backend\apps\administration" (
    xcopy "backend\apps\administration" "%STAGE%\administration\" /E /I /Q /Y >nul
)
if exist "backend\apps\api\serializers\admin.py" (
    mkdir "%STAGE%\api_ser" >nul 2>&1
    copy /Y "backend\apps\api\serializers\admin.py" "%STAGE%\api_ser\" >nul
)
if exist "backend\apps\api\views\admin.py" (
    mkdir "%STAGE%\api_views" >nul 2>&1
    copy /Y "backend\apps\api\views\admin.py" "%STAGE%\api_views\" >nul
)
echo   [OK] staged
echo.

REM ---------- 3. copy backend from v2 ----------
echo [3/6] Copying backend
if not exist "backend" mkdir "backend"

for %%F in (manage.py requirements.txt render.yaml) do (
    if exist "%V2%\%%F" copy /Y "%V2%\%%F" "backend\" >nul
)
for %%D in (apps config templates static locale fixtures scripts) do (
    if exist "%V2%\%%D" xcopy "%V2%\%%D" "backend\%%D\" /E /I /Q /Y >nul
)
echo   [OK] backend copied

REM restore v3 files on top
if exist "%STAGE%\administration" (
    xcopy "%STAGE%\administration" "backend\apps\administration\" /E /I /Q /Y >nul
)
if exist "%STAGE%\api_ser\admin.py" (
    if not exist "backend\apps\api\serializers" mkdir "backend\apps\api\serializers"
    copy /Y "%STAGE%\api_ser\admin.py" "backend\apps\api\serializers\admin.py" >nul
)
if exist "%STAGE%\api_views\admin.py" (
    if not exist "backend\apps\api\views" mkdir "backend\apps\api\views"
    copy /Y "%STAGE%\api_views\admin.py" "backend\apps\api\views\admin.py" >nul
)
echo   [OK] v3 admin files applied

REM cleanup junk
for /d /r "backend" %%P in (__pycache__) do (
    if exist "%%P" rmdir /s /q "%%P" >nul 2>&1
)
if exist "backend\db.sqlite3" del /q "backend\db.sqlite3" >nul 2>&1
if exist "backend\logs" rmdir /s /q "backend\logs" >nul 2>&1
rmdir /s /q "%STAGE%" >nul 2>&1
echo   [OK] cleaned
echo.

REM ---------- 4. copy user app ----------
echo [4/6] Copying user app
if defined HAS_USER (
    if not exist "mobile\apps\user" mkdir "mobile\apps\user"
    xcopy "%V2%\mobile\dalil_app\*" "mobile\apps\user\" /E /I /Q /Y >nul
    if exist "mobile\apps\user\build" rmdir /s /q "mobile\apps\user\build" >nul 2>&1
    if exist "mobile\apps\user\.dart_tool" rmdir /s /q "mobile\apps\user\.dart_tool" >nul 2>&1
    if exist "mobile\apps\user\pubspec.lock" del /q "mobile\apps\user\pubspec.lock" >nul 2>&1
    echo   [OK] user app copied

    > "%TEMP%\dalil_link.ps1" (
      echo $p = 'mobile/apps/user/pubspec.yaml'
      echo if ^(Test-Path $p^) {
      echo   $t = Get-Content $p -Raw -Encoding UTF8
      echo   if ^($t -notmatch 'dalil_core'^) {
      echo     $dep = "  dalil_core:`n    path: ../../packages/dalil_core`n"
      echo     $rx = '^(?m^)^^^(dependencies:\s*\r?\n\s+flutter:\s*\r?\n\s+sdk:\s+flutter\s*\r?\n^)'
      echo     $t = [regex]::Replace^($t, $rx, ^('$1' + $dep^), 1^)
      echo     Set-Content $p $t -NoNewline -Encoding UTF8
      echo     Write-Host '  [OK] dalil_core linked'
      echo   } else { Write-Host '  [OK] dalil_core already linked' }
      echo }
    )
    powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\dalil_link.ps1"
    del /q "%TEMP%\dalil_link.ps1" >nul 2>&1
) else (
    echo   [!]  skipped - copy mobile\dalil_app to mobile\apps\user yourself
)
echo.

REM ---------- 5. secret scan ----------
echo [5/6] Checking for exposed secrets
set "LEAK="
if exist "backend\config\settings\base.py" (
    findstr /R /C:"^SECRET_KEY *= *['\"]django-insecure" "backend\config\settings\base.py" >nul 2>&1
    if not errorlevel 1 set "LEAK=1"
)
if defined LEAK (
    echo   [!]  SECRET_KEY appears hardcoded in settings\base.py
    echo.
    echo   Move it to an environment variable before pushing.
    echo   This repo is public - anything committed stays in git
    echo   history forever, even after deletion.
    echo.
    set /p GO="   Continue anyway? [y/N] "
    if /i not "!GO!"=="y" (
        echo   Stopped. Fix the key and run again.
        pause
        exit /b 1
    )
) else (
    echo   [OK] nothing obvious found
)
echo.

REM ---------- 6. git ----------
echo [6/6] Preparing Git
if not exist ".git" (
    git init -q
    git branch -M main
    echo   [OK] repository initialised
) else (
    echo   [OK] repository already exists
)

git remote remove origin >nul 2>&1
git remote add origin "%REMOTE%"
echo   [OK] origin set

git add -A
echo   [OK] files staged
echo.

echo ============================================
echo   Setup complete.
echo ============================================
echo.
echo   Two commands left:
echo.
echo       git commit -m "feat: v3 foundation"
echo       git push -u origin main
echo.
echo   Git will ask for your username and a TOKEN
echo   (not your normal password).
echo.
echo   Create one at:
echo     GitHub - Settings - Developer settings
echo     - Personal access tokens - Fine-grained
echo   Scope needed: Contents = Read and write
echo.
echo   After pushing:
echo     Settings - Pages - Source: GitHub Actions
echo.
pause
exit /b 0

:no_v2
echo   [X] Could not find the v2 folder.
echo.
echo   Pass it directly, for example:
echo.
echo       setup.bat "D:\2025\daliil-ay-khidma-v3\daliil-ay-khidma-v2.01-master"
echo.
echo   That folder must contain manage.py
echo.
pause
exit /b 1
