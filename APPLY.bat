@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo.
echo   Applying v3 integration patch
echo.

if not exist "backend\config\settings\base.py" (
    echo   [X] Wrong folder. Put this file inside your repo root
    echo       ^(the folder containing backend\ and mobile\^)
    pause
    exit /b 1
)

copy /Y "_patch\backend\config\settings\base.py" "backend\config\settings\base.py" >nul
echo   [OK] INSTALLED_APPS  - apps.administration registered

copy /Y "_patch\backend\apps\api\urls_v2.py" "backend\apps\api\urls_v2.py" >nul
echo   [OK] urls_v2.py      - admin routes added

copy /Y "_patch\.github\workflows\pages.yml" ".github\workflows\pages.yml" >nul
echo   [OK] pages.yml       - web scaffold step added

echo.
echo   Done. Now run:
echo.
echo       git add -A
echo       git commit -m "fix: register admin app, add routes, scaffold web"
echo       git push
echo.
pause
