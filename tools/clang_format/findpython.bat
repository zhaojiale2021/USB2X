@echo off
setlocal EnableDelayedExpansion

:: Accept command line argument for target version
set "targetVersion=%~1"

:: Define a list of possible Python executable names
set "executables=python.exe python3.exe py3.exe"

:: Set a default target version if none is provided
if "%targetVersion%"=="" set "targetVersion=3.6.0"

:: Parse the target version into major, minor, and patch numbers
for /f "tokens=1-3 delims=." %%i in ("%targetVersion%") do (
    set /a "targetMajor=%%i"
    set /a "targetMinor=%%j"
    set /a "targetPatch=%%k"
)

:: Initialize variables to indicate that we haven't found a suitable Python version yet
set "pythonFound=0"
set "compatiblePythonPath=NULL"
set "pythonVersion="
set "pathList=%PATH%"
set "windowsapps=C:\Users\%USERNAME%\AppData\Local\Microsoft\WindowsApps"

:nextPath
:: Split the PATH using a semicolon as the delimiter and get the first item
for /f "tokens=1* delims=;" %%a in ("!pathList!") do (
    set "currentPath=%%a"
    set "pathList=%%b"
)

:: Check if 'currentPath' is empty, which means we've reached the end of PATH
if "!currentPath!"=="" goto endSearch
if /I "!currentPath!"=="!windowsapps!" goto nextPath
:: Check for the existence of any Python executable in the current path
for %%e in (!executables!) do (
    if exist "!currentPath!\%%e" (
        echo %%e   found in: !currentPath!
        :: Call a function to check the version
        call :checkPythonVersion "!currentPath!\%%e"
        if !pythonFound! EQU 1 (
            set "compatiblePythonPath=!currentPath!\%%e"
            goto endSearch
        )
    )
)

if exist "!currentPath!\py.exe" (
    echo py.exe found in: !currentPath!
    :: Call a function to check the version
    call :checkPythonVersion "py -3"
    if !pythonFound! EQU 1 (
        set "compatiblePythonPath=py -3"
        goto endSearch
    )
)

:: If 'pathList' is not empty, loop back to nextPath
if not "!pathList!"=="" goto nextPath

goto endSearch

:checkPythonVersion
:: Get and check the Python version
for /f "tokens=2" %%v in ('"%~1" --version 2^>^&1') do set "pythonVersion=%%v"
echo  python version: !pythonVersion!
for /f "tokens=1-3 delims=." %%i in ("!pythonVersion!") do (
    set /a "major=%%i"
    set /a "minor=%%j"
    set /a "patch=%%k"
)

:: Compare the found Python version with the target version
if !major! GTR !targetMajor! (
    set "pythonFound=1"
) else if !major! EQU !targetMajor! (
    if !minor! GTR !targetMinor! (
        set "pythonFound=1"
    ) else if !minor! EQU !targetMinor! if !patch! GEQ !targetPatch! (
        set "pythonFound=1"
    )
)
goto :eof

:endSearch
:: Post-execution actions
if !pythonFound! equ 1 (
    @REM echo Compatible Python version (!pythonVersion!) found at: !compatiblePythonPath!
) else (
    @REM echo No compatible version of Python was found in any of the PATH directories.
)
echo !compatiblePythonPath!
endlocal