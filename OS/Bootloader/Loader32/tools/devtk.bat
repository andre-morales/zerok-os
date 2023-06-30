@echo off
pushd %cd%
cd %~dp0\..
java -jar "..\..\..\..\Tools\DevToolkit\dist\DevToolkit.jar" %*
popd
