@echo off
goto header
ActivePerl 用の ppm モジュールを生成する
事前に dmake モジュールを導入しておくこと ( ppm install dmake )
正常に終了すると .ppmx ファイルが生成されるので次のように使用する

ppm install *.ppmx
:header

set mod=Thread-Logger
set moc=Thread::Logger

perl Makefile.PL
if not "%ERRORLEVEL%" == "0" goto error

dmake test
if not "%ERRORLEVEL%" == "0" goto error

dmake ppd
if not "%ERRORLEVEL%" == "0" goto error

for /f "usebackq" %%t in (`perl -Ilib -M%moc% -e "print $%moc%::VERSION"`) do set ver=%%t

perl -p -e "s/<ARCHITECTURE.*/<ARCHITECTURE NAME=\"noarch\"\/>/" %mod%.ppd > %mod%-%ver%.ppd

set filename="%mod%-%ver%.ppmx"
if not exist %filename% goto file_skip
del %filename%
:file_skip

del /q /s .exists > nul
for /f %%d in ('dir /ad /b /s') do rd /q %%d 2>nul
for /f %%d in ('dir /ad /b /s') do rd /q %%d 2>nul
for /f %%d in ('dir /ad /b /s') do rd /q %%d 2>nul
for /f %%d in ('dir /ad /b /s') do rd /q %%d 2>nul
for /f %%d in ('dir /ad /b /s') do rd /q %%d 2>nul

ptar.bat -v -c -C -z -f %filename% blib %mod%-%ver%.ppd
if not "%ERRORLEVEL%" == "0" goto error

@echo on
echo === Success ===
goto end
:error
@echo on
echo === Failed ===
:end
