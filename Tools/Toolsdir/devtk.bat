@echo off
pushd %cd%
cd %~dp0\..
java -jar "DevToolkit\dist\DevToolkit.jar" %*
popd
