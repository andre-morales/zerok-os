@echo off
echo %cd%
echo %~dp0
echo %~dp0\..\Pasme\target\Pasme-1.0.jar
pushd %cd%
java -jar "%~dp0\..\Pasme\target\Pasme-1.0.jar" %*
popd