#!/bin/bash
#Script to init vsftpd
if [ $# -ne 1 ]; then
	echo "Usage : $0 <credetial>"
	exit 1
fi
WORKINGDIR=`dirname "$0"`
echo "# VSFTPd Setup"
echo "- Validate Password"
$WORKINGDIR/pwvalidate.sh $1
if [ $? -eq 0 ]; then
	echo " Status: Pass"
else
	echo " Status: Fail"
	exit 1	
fi
echo "- Add User"
sudo htpasswd -c -p -b /etc/vsftpd/ftpd.passwd uploader $(openssl passwd -1 -noverify "$1")
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Config Home directory"
echo "local_root=/var/ftphome" | sudo tee /etc/vsftpd/user_conf/uploader
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Enable and Start Service"
sudo systemctl enable vsftpd.service --now
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "# Finish Setup vsftpd"
