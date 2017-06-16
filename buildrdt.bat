echo on
::tclkit.exe sdx.kit wrap rdt.exe -runtime tclkit_icon_u.exe
del rdt.exe
::tclkit.exe sdx.kit wrap rdt.exe -runtime tclkit-8.6.3.exe
tclkit-8.5.19 sdx.kit wrap rdt.exe -runtime tclkit-8.6.3.exe
copy rdt.ext output\rdt
rem copy rdt_build.exe rdt.ext
rem upx -d uncompressed
rem  upx -q --ultra-brute --compress-resources=0 mytclkit.head.exe , to skip icon compression
pause
