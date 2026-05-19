@echo off

cls
set "pythonVersion=3.7.0"
: check if configFile exist  and get pythonCmd 
:: build.ini => pythonCmd=C:\Path\To\Your\Python.exe
if exist "%configFile%" (
    echo %configFile% exist
    for /f "tokens=1* delims==" %%a in ('type "%configFile%" 2^>nul ^| findstr /i "pythonCmd"') do (
        echo  configFile pythonCmd is %%b 
        set "pythonCmd=%%b"
        goto findPython
    )
)

for /f "tokens=*" %%a in ('call findpython.bat  %pythonVersion%') do (
    set "pythonCmd=%%a"
)
if "%pythonCmd%"=="NULL" (
    echo No valid Python command found !
    goto end
)
:findPython
echo finded python command is %pythonCmd%

echo %pythonCmd% create_pre_commit.py %*
%pythonCmd% create_pre_commit.py %*

:end