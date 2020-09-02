#!/bin/bash
# Create Jump Start Docker Image
WORKINGDIR=`dirname "$0"`
echo "# Create Jump Start Docker Image"
if [ ! -f "$WORKINGDIR/../dockerconf/policy-db.env" ]; then
	echo "  Policy Database Configfile is not exists"
	exit 1
fi

source $WORKINGDIR/../dockerconf/policy-db.env
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ]; then
	echo "  \$MONGO_INITDB_ROOT_USERNAME var is not exists"
	exit 1
fi

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
	echo "  \$MONGO_INITDB_ROOT_PASSWORD var is not exists"
	exit 1
fi

if [ ! -f "$WORKINGDIR/../jumpstart.conf" ]; then
        echo " jumpstart.conf is missing"
fi
source $WORKINGDIR/../jumpstart.conf
if [ -z "JMP_HEALTHCHECK_PASSWD" ]; then
        echo " \$JMP_HEALTHCHECK_PASSWD var is not exists"
        exit 1
fi

if [ ! -f "$WORKINGDIR/../appversion.json" ]; then
	echo " appversion.json is missing"
	exit 1
fi 


MONGO_URI="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@policy-db:27017/?connetTimeoutMS=600000&socketTimeoutMS=600000"
MONGO_DB="gwdb"
LOG_PATH="/app/log"
MONITOR_PATH="/app/data"

echo -n "- Generate apiservice configuration file ..."
cat $WORKINGDIR/../api/appsettings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.LogPath=\"$LOG_PATH/api.log\"" > $WORKINGDIR/../api/appsettings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi
echo -n "- Generate foldermonitor configuration file ..."
cat $WORKINGDIR/../foldermonitor/appsettings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.LogPath=\"$LOG_PATH/foldermonitr.log\" | .CONF.TriggerFolder=\"$MONITOR_PATH/landing/\" | .CONF.ErrorFolder=\"$MONITOR_PATH/error/\" | .CONF.InProgressFolder=\"$MONITOR_PATH/processing/\" | .CONF.CompletedFolder=\"$MONITOR_PATH/processed/\"" > $WORKINGDIR/../foldermonitor/appsettings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi
echo -n "- Generate healthcheck configuration file ..."
cat $WORKINGDIR/../healthcheck/appsettings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.Host=\"http://apiservice:5000/\" | .CONF.DefaultPassword=\"$JMP_HEALTHCHECK_PASSWD\"" > $WORKINGDIR/../healthcheck/appsettings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi

echo "- Create apiservice docker image"
apitags=$(jq -r '.apiservice.tags[]' $WORKINGDIR/../appversion.json)
apibuildimage='docker build -t oicthailand/jumpstartvm-apiservice'
for apitag in ${apitags[@]}
do
	apibuildimage+=" -t oicthailand/jumpstartvm-apiservice:${apitag}"
done
apibuildimage+=" ."
pushd $WORKINGDIR/../api
eval $apibuildimage
if [ $? -ne 0 ]; then
	popd
	exit 1
fi
popd

echo "- Create foldermonitor docker image"
foldermontags=$(jq -r '.foldermonitor.tags[]' $WORKINGDIR/../appversion.json)
foldermonbuildimage='docker build -t oicthailand/jumpstartvm-foldermonitor'
for foldermontag in ${foldermontags[@]}
do
	foldermonbuildimage+=" -t oicthailand/jumpstartvm-foldermonitor:${foldermontag}"
done
foldermonbuildimage+=" ."
pushd $WORKINGDIR/../foldermonitor
eval $foldermonbuildimage
if [ $? -ne 0 ]; then
	popd
	exit 1
fi
popd

echo "- Create healthcheck docker image"
healthchktags=$(jq -r 'healthcheck.tags[]' $WORKINGDIR/../appversion.json)
healthchkbuildimage='docker build -t oicthailand/jumpstartvm-healthcheck'
for healthchktag in ${healthchktahs[@]}
do
	healthchkbuildimage+=" -t oicthailand/jumpstartvm-healthcheck:${healthchktag}"
done
healthchkbuildimage+=" ."
pushd $WORKINGDIR/../healthcheck
eval $healthchkbuildimage
if [ $? -ne 0 ]; then
	popd
	exit 1
fi
popd
