rem For CYOU
rem Date 2012-05-21
@echo off

set workdir=c:\tools
set cygwindir=C:\tools\cygwin
set packages=C:\tools\cygwin\cygwin\release
set desdir=C:\cygwin

net stop sshd
net stop cron
sc delete cron
sc delete sshd
net user cyou_server /delete
net user sshd /delete
rmdir /S /Q %desdir%

setx Path "%Path%;c:\tools" -m
setx Path "%Path%;c:\tools\msbp" -m
setx Path "%Path%;c:\cygwin\bin" -m

rem install cygwin
cd %cygwindir%
setup.exe -R %desdir% -q -L -l %packages%

rem install sshd
cd %desdir%\bin
chmod +r /etc/passwd
chmod +r /etc/group
chmod 775 /var
cp -f %workdir%\sshd_config %desdir%\etc\
bash --login -i ssh-host-config -y -c ntsec -w fbnms6kxgT2EFa2RQgj7wcELU --privileged
net start sshd

cd %desdir%\bin
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/sshd_config
chmod -R 777 /cygdrive/c/tools
ln -s /cygdrive/c/tools/biosdecode.exe biosdecode.exe
ln -s /cygdrive/c/tools/dmidecode.exe dmidecode.exe
ln -s /cygdrive/c/tools/ipmiutil.exe ipmitool.exe
ln -s /cygdrive/c/tools/MegaCli.exe MegaCli.exe
ln -s /cygdrive/c/tools/megarc.exe megarc.exe
ln -s /cygdrive/c/tools/ownership.exe ownership.exe
ln -s /cygdrive/c/tools/Rar.exe rar.exe
ln -s /cygdrive/c/tools/vpddecode.exe vpddecode.exe
ln -s /cygdrive/c/tools/unison.exe unison.exe
ln -s /cygdrive/c/tools/msbp/msbp.exe msbp.exe
ln -s /cygdrive/c/dba/ /home/dba

mkdir  c:\dba\version\
mkdir  c:\dba\dblists\
mkdir  c:\dba\backup/scripts\
mkdir  c:\dba\backup/iptables\
mkdir  c:\dba\backup/sysconf\
mkdir  c:\dba\scripts\
mkdir  c:\dba\packages\
mkdir  c:\dba\operations\
mkdir  c:\dba\logs\

rem net user root /delete
rem net user root D7y5ZNG1rrvK /add /passwordchg:no /active:yes
rem wmic /?
rem wmic path Win32_UserAccount where name='root' set  PasswordExpires=false

rem install crond
cd %desdir%\bin
bash --login -i cron-install
net stop cron
net start cron

rem copy ini
cp -f %workdir%\.vimrc %desdir%\home\Administrator\
cd %desdir%\home\Administrator\ 
mkdir .ssh
cd %desdir%\bin
cp -f %workdir%\authorized_keys %desdir%\home\Administrator\.ssh\

net stop sshd
net start sshd

cscript c:\WINDOWS\system32\pagefileconfig.vbs /Change /m 10240 /i 10240 /vo c:

cd %workdir%\ipmi_drive\x86_64
dir > c:\ipmi.txt
call %workdir%\ipmi_drive\x86_64\install.bat

echo windows2003 securit
call %workdir%\windows_2k3_security_init.bat

shutdown -r -t 10

