@ECHO OFF
CLS
color 0a
echo "Type Any Key to Delete Path"
pause >nul
taskkill /f /im explorer.exe>nul
echo y|Cacls %* /c /t /p Everyone:f >nul
DEL /F/A/Q \\?\%*
RD /S /Q \\?\%*
start %windir%\explorer.exe
exit
