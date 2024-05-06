@echo off
pushd %cd%
java -jar "%~dp0\Pasme\target\Pasme-1.0.jar" %*
popd
exit /b %errorlevel%