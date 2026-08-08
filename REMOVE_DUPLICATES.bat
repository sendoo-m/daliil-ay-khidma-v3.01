@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo.
echo   Removing duplicate handoff system
echo   (superseded by the corrected magic_link.py)
echo.

if not exist "backend" (
    echo   [X] Wrong folder. Run this from the repo root.
    pause
    exit /b 1
)

if exist "backend\apps\accounts\handoff.py" (
    del /q "backend\apps\accounts\handoff.py"
    echo   [OK] removed accounts\handoff.py
) else (
    echo   [--] already gone: accounts\handoff.py
)

if exist "backend\apps\accounts\migrations\0002_loginhandofftoken.py" (
    del /q "backend\apps\accounts\migrations\0002_loginhandofftoken.py"
    echo   [OK] removed migrations\0002_loginhandofftoken.py
) else (
    echo   [--] already gone: 0002_loginhandofftoken.py
)

if exist "backend\apps\api\views\handoff.py" (
    del /q "backend\apps\api\views\handoff.py"
    echo   [OK] removed api\views\handoff.py
) else (
    echo   [--] already gone: api\views\handoff.py
)

if exist "backend\apps\dashboard\views\handoff.py" (
    del /q "backend\apps\dashboard\views\handoff.py"
    echo   [OK] removed dashboard\views\handoff.py
) else (
    echo   [--] already gone: dashboard\views\handoff.py
)

if exist "backend\templates\dashboard\handoff_expired.html" (
    del /q "backend\templates\dashboard\handoff_expired.html"
    echo   [OK] removed templates\handoff_expired.html
) else (
    echo   [--] already gone: handoff_expired.html
)

echo.
echo   Done. Now check status:
echo.
echo       git --no-pager status --short
echo.
echo   Expect: 4 deletions + the files already extracted
echo   from magic-link-fix.zip as modified (M).
echo.
pause
