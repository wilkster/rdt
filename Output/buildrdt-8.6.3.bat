echo on
cd ..
del rdt.exe
::tclkit.exe sdx.kit wrap rdt.exe -runtime tclkit-8.6.3.exe
tclkit-8.5.19 sdx.kit wrap rdt.exe -runtime tclkit-8.6.3.exe
copy rdt.exe output\rdt.exe
rem cd Output
rem "C:\Program Files (x86)\Inno Setup 5\Compil32.exe" /cc "Dropbox rdtBuild.iss"
rem copy rdt_build.exe rdt.ext
rem upx -d uncompressed
rem  upx -q --ultra-brute --compress-resources=0 mytclkit.head.exe , to skip icon compression
