@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo.
echo   Cleaning up patch leftovers
echo.

if not exist "backend" (
    echo   [X] Wrong folder. Put this in your repo root.
    pause
    exit /b 1
)

if exist "_patch" (
    git rm -r --cached _patch >nul 2>&1
    rmdir /s /q "_patch"
    echo   [OK] _patch removed
) else (
    echo   [--] _patch already gone
)

if exist "APPLY.bat" (
    git rm --cached APPLY.bat >nul 2>&1
    del /q "APPLY.bat"
    echo   [OK] APPLY.bat removed
) else (
    echo   [--] APPLY.bat already gone
)

if exist "_gitattributes_new" (
    move /Y "_gitattributes_new" ".gitattributes" >nul
    echo   [OK] .gitattributes added
)

echo.
echo   Now run:
echo.
echo       git add -A
echo       git commit -m "chore: remove patch scaffolding, pin line endings"
echo       git push
echo.
pause
