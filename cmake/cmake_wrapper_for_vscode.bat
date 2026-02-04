@echo off

:: Only for VSCode usage
setlocal enabledelayedexpansion

:: Determine the platform-specific prebuild script
set SCRIPT_DIR=%~dp0
set PREBUILD_SCRIPT=%VS_WORKSPACE%\00_build_env\conan\_generated\host\windows\x86_64\conanbuild.bat

:: Check if this is a configure step (arguments contain -B, --preset, or configure)
echo %* | findstr /C:"-B" /C:"--preset" /C:"configure" >nul
if %errorlevel% equ 0 (
    echo [CMAKE WRAPPER] Running Windows prebuild environment setup...
    if exist "%PREBUILD_SCRIPT%" (
        call "%PREBUILD_SCRIPT%"
        if errorlevel 1 (
            echo [CMAKE WRAPPER] Warning: Prebuild script failed, continuing...
        ) else (
            echo [CMAKE WRAPPER] Environment setup completed successfully
        )
    ) else (
        echo [CMAKE WRAPPER] Warning: Prebuild script not found: %PREBUILD_SCRIPT%
    )
)

:: Find and execute the real cmake
for /f "tokens=*" %%i in ('where cmake.exe 2^>nul') do (
    set CMAKE_REAL=%%i
    goto :found
)

echo [CMAKE WRAPPER] Error: cmake.exe not found in PATH
exit /b 1

:found
echo [CMAKE WRAPPER] Executing: %CMAKE_REAL% %*
"%CMAKE_REAL%" %*
exit /b %errorlevel%