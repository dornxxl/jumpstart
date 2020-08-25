#!/bin/bash
WORKINGDIR=`dirname "$0"`
containers=("portainer" "apigw-db" "apimgt-db" "apigw" "apimgt" "policy-db" "apiservice" "foldermonitor" "healthcheck")
echo "# Checking Existing Docker Contianer"
flags=0
for container in ${containers[@]}
do
	echo -n " - $container --> " 
	status=`docker ps -a -f "name=^${container}\$" --format "{{.Status}}"` 
	if [ ! -z "$status" ]; then 
		echo "$status"
		flags=1	
	else
		echo "Not Found"
	fi
done
if [ $flags -ne 0 ]; then
	echo "*** Docker Container exists! Please remove it and runing setup script again"
fi
exit $flags
