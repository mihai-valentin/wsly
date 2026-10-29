@echo off
if not "%WSLY_MOCK_ARGS%"=="" echo %* >> "%WSLY_MOCK_ARGS%"
echo %* | findstr /c:"--complete-server" >nul
if not errorlevel 1 (
  echo __WSLY_COMPLETION_READY__
:server
  set "request="
  set /p request=
  if errorlevel 1 exit /b 0
  echo __WSLY_COMPLETION_BEGIN__
  echo bmV4dXM=
  echo __WSLY_COMPLETION_END__
  goto server
)
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
