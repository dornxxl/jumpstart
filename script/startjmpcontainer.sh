#!/bin/bash
WORKINGDIR=`dirname "$0"`
conf_files=("policy-db.env" "apiservice.env" "foldermonitor.env" "healthcheck.env")
echo "# Start JumpStart Docker Container"
echo "+ Load jumpstart Configuration File"
if [ ! -f $WORKINGDIR/../jumpstart.conf ]; then
    echo "  Fail: Jumpstat Configuration File is Missing"
    exit 1
else
    source $WORKINGDIR/../jumpstart.conf
    if [ $? -eq 0 ]; then
        echo "  Success"
    else
        echo "  Fail: Error in Jumpstart Configuration File"
        exit 1
    fi
fi

echo "+ Checking Container Configuration File"
if [ ! -d $WORKINGDIR/../dockerconf ]; then
    echo "  Fail: Configuration Directory is Missing"
    exit 1
fi

missconfig=0
pushd $WORKINGDIR/../dockerconf
for configfile in ${conf_files[@]}; do
    echo -n "  + $configfile ..."
        if [ -f $configfile ]; then
            echo "exists"
        else
            echo "miss"
            missconfig=1
        fi
done
popd
if [ $missconfig -ne 0 ]; then
    echo "  Fail: Some Configuration File is Missing"
    exit 1
else
    echo "  Success"
fi

echo "+ Start MongoDB (Policy-DB)"
echo "  - Create ConfigDB volume"
docker volume create policy-configdb
if [ $? -ne 0 ]; then
    echo "    Staus: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  - Create Data volume"
docker volume create policy-db
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  - Start Docker"
docker run -d --name policy-db --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/policy-db.env -v policy-confdb:/data/configdb -v policy-db:/data/db mongo:4.2.8
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi 
echo "    Staus: Success"

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
docker run -d --name apiservice --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/apiservice.env -v /var/log/jumpvm/api:/app/log oic/jumpstartvm-apiservice
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
docker run -d --name foldermonitor --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/foldermonitor.env -v /var/ftphome:/app/data -v /var/log/jumpvm/foldermonitor:/app/log oic/jumpstartvm-foldermonitor
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
docker run -d --name healthcheck --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/healthcheck.env -v /var/log/jumpvm/healthcheck:/app/log -p 8080:8080 oic/jumpstartvm-healthcheck
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "# Start Jumpstart Container Success"