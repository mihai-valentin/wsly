@echo off
if not "%WSLY_MOCK_ARGS%"=="" echo %* >> "%WSLY_MOCK_ARGS%"
echo %* | findstr /c:"--complete-server" >nul
if not errorlevel 1 goto server
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

:server
rem WSLY_MOCK_SERVER_FAIL makes the worker exit before it is ready.
if not "%WSLY_MOCK_SERVER_FAIL%"=="" exit /b 1
echo __WSLY_COMPLETION_READY__
:next_request
set "request="
set /p request=
if not defined request exit /b 0
rem Stray output, as from a .bashrc background job, precedes the reply.
echo stray output
rem bmV4dXMK is base64 for "nexus" plus a newline.
for /f "tokens=1" %%i in ("%request%") do echo __WSLY_COMPLETION_RESULT__ %%i bmV4dXMK
goto next_request
