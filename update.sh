#!/bin/bash
WORKINGDIR=`dirname "$0"`
dockerconfs=("policy-db.env" "apiservice.env" "foldermonitor.env" "healthcheck.env")
appsettings=("api/appsettings.json" "foldermonitor/appsettings.json" "healthcheck/appsettings.json")
echo "# Update JumpStart Application"
if [ ! -f "$WORKINGDIR/appversion.json" ]; then
    echo "!!! Missing appversion.json file"
    read -n1 -p "Would you like to continue (Y/N)..."
    if [ ! "${REPLY,,}" = "y" ]; then
        echo "Abort"
        exit 1
    fi
fi
echo "+ Checking Docker Configuration"
pushd $WORKINGDIR/dockerconf
for dockerconf in ${dockerconfs[@]}
do
    if [ ! -f "$dockerconf" ]; then
        echo "  !!! Docker ENV file : ${dockerconf} is missing"
        popd
        exit 1
    fi
done
echo "  Status Complete"
popd
echo "+ Checking JumpStart App Configfile"
for appsetting in ${appsettings[@]}
do 
    if [ ! -f "$WORKINGDIR/$appsetting" ]; then
        echo " !!! Jumpstart Configfile is missing"
        exit 1
    fi
done
echo "  Status Complete"

echo "+ Create Docker Image"
if [ ! -x $WORKINGDIR/script/createjmpimg.sh ]; then
    echo "  !!! Docker Image Generate file is missing"
    exit 1
fi
$WORKINGDIR/script/createjmpimg.sh
if [ $? -ne 0 ]; then
    echo "  Status: Fail"
    exit 1
fi

#Check Policy-DB is exists
echo "+ Check Policy DB Container"
status=`docker ps -a -f "name=^policy-db\$" --format "{{.Status}}"` 
if [ -z "$status" ]; then
    echo "  Policy DB Container is not exists ... Abort!"
    exit 1
fi
echo "  Staus : $status"

# Stop and Delete old container
jumpcontainers=("healthcheck" "foldermonitor" "apiservice")
echo "+ Remove Existing Container"
echo "  This process will stop and delete jumpstart container."
read -n1 -p "Would you like to continue (Y/N)..."
if [ ! "${REPLY,,}" = "y" ]; then
        echo "Abort"
        exit 1
fi 
echo ""
echo "  Removing Container"
for container in ${jumpcontainers[@]}
do
    status=`docker ps -a -f "name=^${container}\$" --format "{{.Status}}"`
    if [ ! -z "$status" ]; then	
    	docker rm --force  $container
    	if [ $? -ne 0 ]; then
        	echo " Remove $container failed"
        	exit 1
    	fi
	echo "  -> $container removed"
     else 
	echo "  -> $container not exists"	     
    fi
done
sleep 5

# Start new Container
echo "+ Start APIService"
echo "  - Create Log Directory"
if [ -d "/var/log/jumpvm/api" ]; then
    echo "    Status: Exists"
else
    sudo install -d /var/log/jumpvm/api -o root -g root
    if [ $? -ne 0 ]; then
        echo "    Status: Fail"
        exit 1
    fi
    echo "    Status: Success"
fi 
echo "  - Start Docker"
docker run -d --name apiservice --restart always --network api-net --env-file $WORKINGDIR/dockerconf/apiservice.env -v /var/log/jumpvm/api:/app/log oicthailand/jumpstartvm-apiservice:latest
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"

echo "+ Start Folder Monitor"
echo "  - Create Log Directory"
if [ -d "/var/log/jumpvm/foldermonitor" ]; then
    echo "    Status: Exists"
else
    sudo install -d /var/log/jumpvm/foldermonitor -o root -g root
    if [ $? -ne 0 ]; then
        echo "    Status: Fail"
        exit 1
    fi
    echo "    Status: Success"
fi
echo "  - Create Working Directory"
sudo install -d /var/ftphome/landing /var/ftphome/error /var/ftphome/processing /var/ftphome/processed -o vuserftp -g nogroup
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  - Start Docker"
docker run -d --name foldermonitor --restart always --network api-net --env-file $WORKINGDIR/dockerconf/foldermonitor.env -v /var/ftphome:/app/data -v /var/log/jumpvm/foldermonitor:/app/log oicthailand/jumpstartvm-foldermonitor:latest
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"

echo "+ Start Health Check"
echo "  - Create Log Directory"
if [ -d "/var/log/jumpvm/healthcheck" ]; then
    echo "    Status: Exists"
else
    sudo install -d /var/log/jumpvm/healthcheck -o root -g root
    if [ $? -ne 0 ]; then
        echo "    Status: Fail"
        exit 1
    fi
    echo "    Staus: Success"
fi
echo "  - Start Docker"
docker run -d --name healthcheck --restart always --network api-net --env-file $WORKINGDIR/dockerconf/healthcheck.env -v /var/log/jumpvm/healthcheck:/app/log -p 8080:8080 oicthailand/jumpstartvm-healthcheck:latest
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
