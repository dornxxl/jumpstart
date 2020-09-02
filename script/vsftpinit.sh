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
echo "- Generate Certificate"
sudo openssl req -x509 -nodes -days 1780 -newkey rsa:2048 -keyout /etc/ssl/private/vsftp.key -out /etc/ssl/private/vsftp.key -subj "/C=TH/ST=Bangkok/O=JumpStart Project/OU=JumpStart FTP Services/CN=$(hostname)"
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
