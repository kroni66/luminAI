@echo off
echo ===========================================
echo   LuminAI Code Signing Setup Script
echo ===========================================
echo.

echo This script will help you set up code signing for your Flutter app
echo to reduce Windows Defender false positives.
echo.

echo Choose your option:
echo [1] Use self-signed certificate (Free, immediate)
echo [2] Setup Codegic free certificate (30 days free)
echo [3] Exit
echo.

set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto :selfsigned
if "%choice%"=="2" goto :codegic
if "%choice%"=="3" goto :exit

echo Invalid choice. Please run the script again.
pause
exit /b 1

:selfsigned
echo.
echo ===========================================
echo   Setting up self-signed certificate
echo ===========================================
echo.

powershell -Command "& { $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=LuminAI Developer' -KeyUsage DigitalSignature -KeyLength 2048 -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddYears(1); Write-Host 'Certificate created with thumbprint:' $cert.Thumbprint; Write-Host 'Add this thumbprint to your pubspec.yaml sign_tool_params' }"

echo.
echo Copy the thumbprint above and add it to your pubspec.yaml:
echo sign_tool_params: '/fd SHA256 /t http://timestamp.digicert.com /sha1 YOUR_THUMBPRINT_HERE'
echo.
pause
goto :exit

:codegic
echo.
echo ===========================================
echo   Codegic Free Certificate Setup
echo ===========================================
echo.
echo Step 1: Visit https://www.codegic.com/code-signing-certificate/
echo Step 2: Register and download your free 30-day certificate
echo Step 3: Install the certificate on your system
echo Step 4: Find the certificate thumbprint in Certificate Manager
echo Step 5: Add the thumbprint to your pubspec.yaml
echo.
echo Example pubspec.yaml configuration:
echo sign_tool: signtool
echo sign_tool_params: '/fd SHA256 /t http://timestamp.digicert.com /sha1 YOUR_THUMBPRINT'
echo.
pause
goto :exit

:exit
echo.
echo Setup complete. Run 'flutter pub run inno_bundle' to test your signed installer.
echo.
pause
