#!/bin/bash
#####################################
# Setup Script for Jumpstart Server #
# Please Edit jumpstart.conf before #
# run this script.                  #
# Website : http://oicgateway.com   #
# email : cit@oic.go.th             #
#####################################
WORKINGDIR=`dirname "$0"`

echo "#Starting Setup Script"
echo "#Loading Configfile"
if [ -s "$WORKINGDIR/jumpstart.conf" ]; then
	source $WORKINGDIR/jumpstart.conf
else
	echo "Config file is missing"
	exit 1
fi

# Validate Config file
echo -n "\$JMP_PORTAINER_PASSWD : "
if [ ! -z "$JMP_PORTAINER_PASSWD" ]; then
	$WORKINGDIR/script/pwvalidate.sh "$JMP_PORTAINER_PASSWD"
	if [ $? -eq 0 ]; then
		echo "ok"
	else
		exit 1
	fi
else
	echo "Missing  \$JMP_PORTAINER_PASSWD Parameter"
	exit 1
fi


echo -n "\$JMP_FTP_PASSWD :"
if [ ! -z "$JMP_FTP_PASSWD" ]; then
	$WORKINGDIR/script/pwvalidate.sh "$JMP_FTP_PASSWD"
	if [ $? -eq 0 ]; then
		echo " ok"
	else
		exit 1
	fi
else
	echo "Missing \$JMP_FTP_PASSWD Parameter"
	exit 1
fi

echo -n "\$JMP_HEALTHCHECK_PASSWD :"
if [ ! -z "$JMP_HEALTHCHECK_PASSWD" ]; then
	$WORKINGDIR/script/pwvalidate.sh "$JMP_HEALTHCHECK_PASSWD"
	if [ $? -eq 0 ]; then
		echo " ok"
	else
		exit 1
	fi
else
	echo "Missing \$JMP_HEALTHCHECK_PASSWD Parameter"
	exit 1
fi

echo -n "\$JMP_APINETWORK : "
if [ ! -z "$JMP_APINETWORK" ]; then
	$WORKINGDIR/script/cidr.sh "$JMP_APINETWORK"
	if [ $? -eq 0 ]; then
		echo " ok"
	else
		echo "$JMP_APINETWORK fail"
		exit 1
	fi
else
	echo "Missing \$JMP_APINETWORK Parameter"
	exit 1
fi

echo "\$JMP_IP_WHITELIST :"
if [ ! -z "$JMP_IP_WHITELIST" ]; then
	OIFS=$IFS
	IFS=','
	networks=($JMP_IP_WHITELIST)
	for network in ${networks[@]}
	do
		echo -n " - "
		$WORKINGDIR/script/cidr.sh "$network"
		if [ $? -eq 0 ]; then
			echo " ok"
		else
			echo "$network fail"
			exit 1
		fi
	done
else
	echo "Missing \$JMP_IP_WHITELIST Parameter"
	exit 1
fi


echo '# Cofiguration file validate complete'

if [ -x $WORKINGDIR/script/chcontainer.sh ]; then
	$WORKINGDIR/script/chcontainer.sh
	if [ $? -ne 0 ]; then
		exit 1
	fi
fi

# Configuration Generator
echo '# Generate Docker Environment File'
DBPASSWD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`
echo -n 'Checking Config Diretory :' 
if [ ! -d "$WORKINGDIR/dockerconf" ]; then
	echo " not exists"
	echo -n "Create Config Directory :"
	mkdir $WORKINGDIR/dockerconf
	if [ $? -eq 0 ]; then
		echo " ok"
	else
		echo " fail"
		exit 1
	fi
else
	echo "exists - Posible old installation remain please remove it and run $0 again"
	exit 1
fi

echo -n "Generate apigw-db.env"
cat << EOF > $WORKINGDIR/dockerconf/apigw-db.env
POSTGRES_USER=apigw
POSTGRES_DB=apigw
POSTGRES_PASSWORD=$DBPASSWD
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate apimgt-db.env"
cat << EOF > $WORKINGDIR/dockerconf/apimgt-db.env
POSTGRES_USER=apimgt
POSTGRES_DB=apimgt
POSTGRES_PASSWORD=$DBPASSWD
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate apigw.env"
cat << EOF > $WORKINGDIR/dockerconf/apigw.env
KONG_DATABASE=postgres
KONG_PG_HOST=apigw-db
KONG_PG_USER=apigw
KONG_PG_DATABASE=apigw
KONG_PG_PASSWORD=$DBPASSWD
KONG_PROXY_ACCESS_LOG=/dev/stdout
KONG_ADMIN_ACCESS_LOG=/dev/stdout
KONG_PROXY_ERROR_LOG=/dev/stderr
KONG_ADMIN_ERROR_LOG=/dev/stderr
KONG_ADMIN_LISTEN=0.0.0.0:8001
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate apimgt.env"
cat << EOF > $WORKINGDIR/dockerconf/apimgt.env
DB_ADAPTER=postgres
DB_URI=postgres://apimgt:$DBPASSWD@apimgt-db/apimgt
NODE_ENV=production
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate policy-db.env"
cat << EOF > $WORKINGDIR/dockerconf/policy-db.env
MONGO_INITDB_ROOT_USERNAME=mongoadmin
MONGO_INITDB_ROOT_PASSWORD=$DBPASSWD
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate apiservice.env"
cat << EOF > $WORKINGDIR/dockerconf/apiservice.env
ASPNETCORE_URLS=http://*:5000
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate foldermonitor.env"
cat << EOF > $WORKINGDIR/dockerconf/foldermonitor.env
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo -n "Generate healthcheck.env"
cat << EOF > $WORKINGDIR/dockerconf/healthcheck.env
ASPNETCORE_URLS=http://*:8080
TZ=Asia/Bangkok
EOF

if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo "# Finish Generate Docker Environment file"

#Check Docker Image
if [ -x $WORKINGDIR/script/chdockerimg.sh ]; then
	echo "# Checking Docker Image"
	$WORKINGDIR/script/chdockerimg.sh
	echo "# Finish Check Docker Image"
fi

#Create Config File for JumpStart Docker
if [ ! -x $WORKINGDIR/script/createjmpimg.sh ]; then
	echo "!! JumpStart image create script not found"
	exit 1
fi
$WORKINGDIR/script/createjmpimg.sh
if [ $? -ne 0 ]; then
	exit 1
fi

#Start Base Docker 
if [ ! -x $WORKINGDIR/script/startbasecontainer.sh ]; then
	echo "!! Start Base Container script not found"
	exit 1
fi
$WORKINGDIR/script/startbasecontainer.sh
if [ $? -ne 0 ]; then
	exit 1
fi

#Start Jumpstart Docker
if [ ! -x $WORKINGDIR/script/startjmpcontainer.sh ]; then
	echo "!! Start Jumpstart Container script not found"
	exit 1
fi
$WORKINGDIR/script/startjmpcontainer.sh
if [ $? -ne 0 ]; then
	exit 1
fi

#Import Kong Configuration
if [ ! -x  $WORKINGDIR/script/konginit.sh]; then
	echo "!! Kong Preconfig script is missing"
	exit 1
fi
$WORKINGDIR/script/konginit.sh
if [ $? -ne 0 ]; then
	exit 1
fi

#Add user to vsftp
if [ ! -x $WORKINGDIR/script/vsftpinit.sh ]; then
	echo "!! VSFTP init script is missing"
	exit 1
fi 	
$WORKINGDIR/script/vsftpinit.sh "$JMP_FTP_PASSWD"
if [ $? -ne 0 ]; then
	exit 1
fi

#Setup Firewall
if [ ! -x $WORKINGDIR/script/firewall.sh ]; then
	echo "!! Firewall script is missing"
	exit 1
fi
$WORKINGDIR/script/firewall.sh "$JMP_IP_WHITELIST"
if [ $? -ne 0 ]; then
	echo "  Status: Fail"
	exit 1
fi
echo "  Status: Success" 

# Remove Passsword Less Sudo Configuration
if [ -f /etc/sudoers.d/apiadm ]; then
	echo "# Remove Password less sudo config"
	sudo rm /etc/sudoers.d/apiadm
	if [ $? -eq 0 ]; then
		echo "  Status: Success"
	else
		echo "  Status: Fail"
		exit 1
	fi
fi

echo "### Setup Complete ###"
