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
	exit 1;
fi

# Validate Config file
echo -n "\$JMP_APIMGT_PASSWD : "
if [ ! -z "$JMP_APIMGT_PASSWD" ]; then
	$WORKINGDIR/script/pwvalidate.sh "$JMP_APIMGT_PASSWD"
	if [ $? -eq 0 ]; then
		echo "ok"
	else
		exit 1;
	fi
else
	echo "Missing  \$JMP_APIMGT_PASSWD Parameter"
	exit 1;
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
	exit 1;	
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
	exit 1;
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
	exit 1;
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

# Start Docker
echo "# Startup Docker Process"
echo "Create Docker Internal Network :"
docker_apinet=`$WORKINGDIR/script/cidr.sh $JMP_APINETWORK`
docker network create --subnet $docker_apinet api-net
if [ $? -eq 0 ]; then
	echo " ok"
else
	echo " fail"
	exit 1
fi

echo "Start Portainer (Docker Managment)"
if [ ! -d /opt/portainer ]; then
	sudo install -d /opt/portainer
fi
docker run -d --name portainer --restart always -e "TZ=Asia/Bangkok" -v /opt/portainer:/data -v /var/run/docker.sock:/var/run/docker.sock -p 9000:9000 portainer/portainer:1.24.1
if [ $? -eq 0 ]; then
	echo "Status : Success"
else
	echo "Status : Fail"
	exit 1
fi
echo "Preconfigure Portainer"
sleep 5
curl -X POST -H  "Content-Type:application/json" \
	-d "{ \"Username\": \"apiadm\", \"Password\": \"$JMP_APIMGT_PASSWD\" }" \
	'http://localhost:9000/api/users/admin/init' | jq .
PToken=`curl -X POST -H "Content-Type:application/json" -d "{ \"Username\": \"apiadm\", \"Password\": \"$JMP_APIMGT_PASSWD\" }" 'http://localhost:9000/api/auth' | jq -r .jwt`

if [ ! -z "$PToken" ]; then
	curl -X POST -H "accept: application/json" -H "Content-Type: multipart/form-data" -H "Authorization: Bearer $PToken" -F "Name=Local" -F "EndpointType=1" 'http://localhost:9000/api/endpoints' | jq .
	if [ $? -eq 0 ]; then
		echo "Status: Success"
	else
		echo "Status: Fail"
		exit 1
	fi
else
	echo "Status : Fail"
	exit 1
fi

echo "Start APIGW-DB (Postgres)"
echo "- Create Data volume"
docker volume create apigw-db
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name apigw-db --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apigw-db.env -v apigw-db:/var/lib/postgresql/data postgres:11.8
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
sleep 5

echo "Start APIMGT-DB (Postgres)"
echo "- Create Data volume"
docker volume create apimgt-db
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name apimgt-db --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apimgt-db.env -v apimgt-db:/var/lib/postgresql/data postgres:11.8
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
sleep 5

echo "Start APIGW (Kong)"
echo "- Init DB"
docker run --rm --network api-net --env-file $WORKINGDIR/dockerconf/apigw.env kong:2.1 kong migrations bootstrap
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name apigw --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apigw.env -p 80:8000 -p 443:8443 -p 127.0.0.1:8001:8001 kong:2.1
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi

echo "Start APIGW-MGT (Konga)"
echo "- Create Data Volume"
docker volume create apimgt
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Init DB"
#dbpwurlenc=`jq -nr --arg v "$DBPASSWD" '$v|@uri'`
docker run --rm --network api-net pantsel/konga:0.14.9 -c prepare -a postgres -u "postgres://apimgt:$DBPASSWD@apimgt-db/apimgt"
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name apimgt --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apimgt.env -p 1337:1337 -v apimgt:/app/kongadata pantsel/konga:0.14.9
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi

echo "Start POLICY-DB (MONGO)"
echo "- Create ConfigDB Volume"
docker volume create policy-confdb
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Create Data Volume"
docker volume create policy-db
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name policy-db --restart always --network api-net --env-file $WORKINGDIR/dockerconf/policy-db.env -v policy-confdb:/data/configdb -v policy-db:/data/db mongo:4.2.8
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
sleep 5

echo "Start API-Service"
echo "- Create Log folder"
if [ -d "/var/log/jumpvm/api" ]; then
	echo " Status: Exists"
else
	sudo install -d /var/log/jumpvm/api -o root -g root
	if [ $? -eq 0 ]; then
		echo " Status: Success"
	else
		echo " Status: Fail"
		exit 1
	fi
fi
echo "- Start Docker"
docker run -d --name apiservice --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apiservice.env -v /var/log/jumpvm/api:/app/log oic/jumpstartvm-apiservice
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi

echo "Start Folder Monitor"
echo "- Create Log Directory"
if [ -d "/var/log/jumpvm/foldermonitor" ]; then
	echo " Status: Exists"
else
	sudo install -d /var/log/jumpvm/foldermonitor -o root -g root
	if [ $? -eq 0 ]; then
		echo " Status: Success"
	else
		echo " Status: Fail"
		exit 1
	fi
fi
echo "- Create Working Directory"
sudo install -d /var/ftphome/landing /var/ftphome/error /var/ftphome/processing /var/ftphome/processed -o vuserftp -g nogroup
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi
echo "- Start Docker"
docker run -d --name foldermonitor --restart always --network api-net --env-file $WORKINGDIR/dockerconf/foldermonitor.env -v /var/ftphome:/app/data -v /var/log/jumpvm/foldermonitor:/app/log oic/jumpstartvm-foldermonitor
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi

echo "Start Health Check"
echo "- Create Log Directory"
if [ -d "/var/log/jumpvm/healthcheck" ]; then
	echo " Status: Exits"
else
	sudo install -d /var/log/jumpvm/healthcheck
	if [ $? -eq 0 ]; then
		echo " Status: Success"
	else
		echo " Status: Fail"
		exit 1
	fi
fi
echo "- Start Docker"
docker run -d --name healthcheck --restart always --network api-net --env-file $WORKINGDIR/dockerconf/healthcheck.env -v /var/log/jumpvm/healthcheck:/app/log -p 8080:8080 oic/jumpstartvm-healthcheck
if [ $? -eq 0 ]; then
	echo " Status: Success"
else
	echo " Status: Fail"
	exit 1
fi

if [ -x $WORKINGDIR/script/vsftpinit.sh ]; then
	$WORKINGDIR/script/vsftpinit.sh "$JMP_FTP_PASSWD"
	if [ $? -ne 0 ]; then
		exit 1
	fi
else 
	echo "!! VSFTP init script is missing"
	exit 1
fi

if [ -x $WORKINGDIR/script/firewall.sh ]; then
	$WORKINGDIR/script/firewall.sh "$JMP_IP_WHITELIST"
	if [ $? -eq 0 ]; then
		echo "  Status: Success"
	else
		echo "  Status: Fail"
		exit 1
	fi
else
	echo "!! Firewall script is missing"
	exit 1
fi

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
