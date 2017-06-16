cd ..
set /p ver= Enter Version Number:
del output\rdt-full-%ver%.zip
zip -r output\rdt-full-%ver%.zip *.dll rdt.exe *.txt rdt.vfs\* 
zip -r output\rdt-full-%ver%.zip output\buildrdt.bat tclkit.exe tclkit-8.5.19.exe sdx.kit
del output\rdt-portable-%ver%.zip
zip -r output\rdt-portable-%ver%.zip *.dll rdt.exe *.txt
echo complete
pause