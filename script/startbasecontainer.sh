#!/bin/bash
WORKINGDIR=`dirname "$0"`
conf_files=("apigw-db.env" "apimgt-db.env" "apigw.env" "apimgt.env")
echo "# Start Base Docker Container"
echo "- Load jumpstart Configuration File"
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

echo "- Checking Container Configuration File"
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

echo "- Create Container Internal Network"
if [[ ! -z "$JMP_APINETWORK" && "$JMP_APINETWORK" =~ .*"/".* ]]; then
    docker_net=`$WORKINGDIR/cidr.sh $JMP_APINETWORK`
    if [ $? -ne 0 ]; then
        echo "  Fail: \$JMP_APINETWORK is not useable"
        exit 1
    fi
    docker network create --subnet $docker_net api-net
    if [ $? -ne 0 ]; then
        echo "  Fail: Unable to create Container Internal Network"
        exit 1
    fi
    echo "  Success"
else
    echo "  Fail: \$JMP_APINETWORK is Missing"
    exit 1
fi

echo "- Start Portainer (Docker Managment)"
echo -n "  + Checking /opt/portainer ..."
if [ ! -d /opt/portainer ]; then
    sudo install -d /opt/portainer
    if [ $? -eq 0 ]; then
        echo "created"
    else
        echo "fail"
        exit 1
    fi
else
    echo "exists"
fi
echo  "  + Starting Docker"
docker run -d --name portainer --restart always -e "TZ=Asia/Bangkok" -v /opt/portainer:/data -v /var/run/docker.sock:/var/run/docker.sock -p 9000:9000 portainer/portainer:1.24.1
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
sleep 5

echo "  + Preconfigure Portainer"
curl -sX POST -H "Content-Type: application/json" -d "{ \"Username\": \"apiadm\", \"Password\": \"$JMP_PORTAINER_PASSWD\" }" http://localhost:9000/api/users/admin/init | jq .
PToken=`curl -sX POST -H "Content-Type: application/json" -d "{ \"Username\": \"apiadm\", \"Password\": \"$JMP_PORTAINER_PASSWD\" }" http://localhost:9000/api/auth | jq -r '.jwt'`
if [ ! -z "$PToken" ]; then
    curl -sX POST -H "Accept: application/json" -H "Content-Type: multipart/form-data" -H "Authorization: Bearer $PToken" -F "Name=Local" -F "EndpointType=1" http://localhost:9000/api/endpoints | jq .
    if [ $? -ne 0 ]; then
        echo "    Status: Fail"
        exit 1
    fi
    echo "    Status: Success"
else
    echo "    Status: Fail"
    exit 1
fi

echo "- Start Postgres (APIGW-DB)"
echo "  + Create Data volume"
docker volume create apigw-db
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  + Start Docker"
docker run -d --name apigw-db --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/apigw-db.env -v apigw-db:/var/lib/postgresql/data postgres:11.8
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"

echo "- Start Postgres (APIMGT-DB)"
echo "  + Create Data volume"
docker volume create apimgt-db
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  + Start Docker"
docker run -d --name apimgt-db --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/apimgt-db.env -v apimgt-db:/var/lib/postgresql/data postgres:11.8
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
sleep 5

echo "- Start Kong (APIGW)"
echo "  + Initial Database"
docker run --rm --network api-net --env-file $WORKINGDIR/../dockerconf/apigw.env kong:2.1 kong migrations bootstrap
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  + Start Docker"
docker run -d --name apigw --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/apigw.env -p 80:8000 -p 443:8443 -p 127.0.0.1:8001:8001 kong:2.1
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"

echo "- Start Konga (APIGW-MGT)"
echo "  + Create Data volume"
docker volume create apimgt
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  + Initial Database"
docker run --rm --network api-net pantsel/konga:0.14.9 -c prepare -a postgres -u "postgres://apimgt:$DBPASSWD@apimgt-db/apimgt"
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "  + Start Docker"
docker run -d --name apimgt --restart always --network api-net --env-file $WORKINGDIR/../dockerconf/apimgt.env -p 1337:1337 -v apimgt:/app/kongadata pantsel/konga:0.14.9
if [ $? -ne 0 ]; then
    echo "    Status: Fail"
    exit 1
fi
echo "    Status: Success"
echo "# Start Base Docker Container Complete"
