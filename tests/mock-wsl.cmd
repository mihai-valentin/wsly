@echo off
if not "%WSLY_MOCK_ARGS%"=="" echo %* >> "%WSLY_MOCK_ARGS%"
echo %* | findstr /c:"wslpath" >nul
if not errorlevel 1 (
  echo /tmp/wsly.bash
  exit /b 0
)
echo %* | findstr /c:"bash" >nul
if not errorlevel 1 (
  echo nexus
  exit /b 0
)
exit /b 1
