@echo off
pushd %cd%
java -jar "%~dp0\DevToolkit\dist\DevToolkit.jar" %*
popd
exit /b %errorlevel%