#!/bin/bash
#Fancy Display
r_fail="\e[1;41m Fail \e[0m"
r_pass="\e[1;42m Pass \e[0m"
WORKINGDIR=`dirname "$0"`
#Check Service
services=("sshd" "docker" "vsftpd")
echo "# Verify Services"
for service in ${services[@]}
do
        status=`systemctl show -p SubState --value $service`
        if [[ "$status" ==  "running" ]]; then
                echo -e " - $r_pass $service --> $status"
        else
                echo -e " - $r_fail $service --> $status"
        fi
done

#Verify Containers
containers=("portainer" "apigw-db" "apimgt-db" "apigw" "apimgt" "policy-db" "apiservice" "foldermonitor" "healthcheck")
echo "# Verify Docker Container"
for container in ${containers[@]}
do
        status=`docker ps -a -f "name=^${container}\$" --format "{{.Status}}"`
        if [ -z "$status" ]; then
                echo -e " - $r_fail $container --> Not Found"
        elif [[ "$status" =~ "Up" ]]; then
                echo -e " - $r_pass $container --> $status"
        else
                echo -e " - $r_fail $container --> $status"
        fi
done

#Verify vsFTPd Configuration
configfiles=("/etc/vsftpd.conf" "/etc/pam.d/vsftpd_vuser" "/etc/ssl/private/vsftp.key" "/etc/vsftpd/ftpd.passwd" "/etc/vsftpd/user_conf/uploader")
echo "# Verify vsFTPd Server"
echo " + Check Config file"
for conffile in ${configfiles[@]}
do
        sudo test -s $conffile
        if [ $? -ne 0 ]; then
                echo -e " - $r_fail $conffile ... not found"
        else
                echo -e " - $r_pass $conffile ... found"
        fi
done
echo " + Check is modified Config file"
cat <<EOF| md5sum -c
2e480eb946d35138ccbe235e34f60de7  /etc/vsftpd.conf
441fb90aed72b90ace678bad7e0fbf3e  /etc/pam.d/vsftpd_vuser
EOF
if [ $? -ne 0 ]; then
        echo -e " - $r_fail vsFTPd Config file is modified"
else
        echo -e " - $r_pass vsFTPd Config file is original"
fi
echo " + Compare password with config file"
source $WORKINGDIR/../jumpstart.conf
crypted=`grep "uploader" /etc/vsftpd/ftpd.passwd | awk '{split($0,ar,":"); print ar[2]}'`
salt=`grep "uploader" /etc/vsftpd/ftpd.passwd | awk '{split($0,ar,"$"); print ar[3]}'`
validpass=`openssl passwd -1 -salt "$salt" "$JMP_FTP_PASSWD"`
if [[ "$crypted" == "$validpass" ]]; then
        echo -e " - $r_pass Password Match"
else
        echo -e " - $r_fail Password Miss Match"
fi
echo "======================================="
read -n1 -p "Would you like to print Firewall rule (y/N) ..."
echo ""
if [ "${REPLY,,}" = "y" ]; then
        echo "Hostname : $(hostname)"
        $WORKINGDIR/getdefaultnetwork.sh print
        echo -n "Firewall "
        sudo ufw status verbose
fi
