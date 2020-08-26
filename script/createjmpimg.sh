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

MONGO_URI="mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@policy-db:27017/?connetTimeoutMS=600000&socketTimeoutMS=600000"
MONGO_DB="gwdb"
LOG_PATH="/app/log"
MONITOR_PATH="/app/data"

echo -n " Generate apiservice configuration file ..."
cat $WORKINGDIR/../api/appsettings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.LogPath=\"$LOG_PATH/api.log\"" > $WORKINGDIR/../api/appsettings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi
echo -n " Generate foldermonitor configuration file ..."
cat $WORKINGDIR/../foldermonitor/appetings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.LogPath=\"$LOG_PATH/foldermonitr.log\" | .CONF.TriggerFolder=\"$MONITOR_PATH/landing/\" | .CONF.ErrorFolder=\"$MONITOR_PATH/error/\" | .CONF.InProgressFolder=\"$MONITOR_PATH/processing/\" | .CONF.CompletedFolder=\"$MONITOR_PATH/processed/\"" > $WORKINGDIR/../foldermonitor/appsettings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi
echo -n " Generate healthcheck configuration file ..."
cat $WORKINGDIR/../healthcheck/appsetings.json.template | jq -M ".CONF.MongoServer=\"$MONGO_URI\" | .CONF.MongoDb=\"$MONGO_DB\" | .CONF.Host=\"http://apiservice:5000\"" > $WORKINGDIR/../healthcheck/appsetings.json
if [ $? -eq 0 ]; then
	echo "done"
else
	echo "fail"
	exit 1
fi

