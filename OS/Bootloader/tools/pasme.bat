@echo off
pushd %cd%
cd %~dp0\..
java -jar "..\..\Tools\Pasme\target\Pasme-1.0.jar" %*
popd