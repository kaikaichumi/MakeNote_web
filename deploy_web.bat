@echo off
echo ======================================
echo MakeNote Web 部署腳本
echo ======================================
echo.

echo 正在檢查 Flutter Web 支援...
flutter config --enable-web
echo.

echo 正在清理構建目錄...
flutter clean
echo.

echo 正在構建 Web 版本...
flutter build web --release
echo.

echo 是否要立即部署到 Firebase Hosting? (Y/N)
set /p deploy=

if /i "%deploy%"=="Y" (
  echo 正在部署到 Firebase Hosting...
  firebase deploy --only hosting
  echo.
  echo 部署完成！請訪問 Firebase 控制台查看您的應用網址。
) else (
  echo 跳過部署步驟。
  echo Web 版本已構建完成，位於 build/web 目錄。
)

echo.
echo 處理完成！
pause