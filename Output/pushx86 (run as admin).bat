c:
cd "%USERPROFILE%\Google Drive\Code\rdt"
xcopy rdt.exe "c:\apps\RDT\" /d /y
cd ..
xcopy *.dll "c:\apps\RDT\" /d /y
xcopy *.txt "c:\apps\RDT\" /d /y
pause