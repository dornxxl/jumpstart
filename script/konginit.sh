#!/bin/bash
WORKINGDIR=`dirname "$0"`
plugins_url='http://localhost:8001/plugins'
service_url='http://localhost:8001/services/'
route_url()
{
	echo "http://localhost:8001/services/$1/routes"
}

echo "# API Import configuration" | tee $WORKINGDIR/konginit.log
if [ ! -f $WORKINGDIR/kong.json ]; then
	echo "   Missing Kong Conf" | tee -a $WORKINGDIR/konginit.log
	exit 1
fi

echo "- Import Content Security Policy" | tee -a $WORKINGDIR/konginit.log
csp=`jq '.csp' $WORKINGDIR/kong.json`

if [ "$csp" == "null" ]; then
	echo "  CSP Configuration is Missing" | tee -a $WORKINGDIR/konginit.log
	exit 1
fi

rescode=`curl -s -X POST $plugins_url -d "$csp" -H "Content-Type: application/json" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then 
	echo "  Fail : Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "  Success"
fi 

echo "- Import API Endpoint Configuration" | tee -a $WORKINGDIR/konginit.log
services=$(jq -r '.apis | .[].name' $WORKINGDIR/kong.json)
if [ $? -ne 0 ]; then
	echo "  API Endpoint Configuration is Missing" | tee -a $WORKINGDIR/konginit.log
	exit 1
fi 
for service in ${services[@]}; do 
	echo "  + Adding $service service" | tee -a $WORKINGDIR/konginit.log
	s_payload=`jq ".apis | .[].service | select(.name==\"${service}\")" $WORKINGDIR/kong.json`
	if [ -z "$s_payload" ]; then
		echo "    Fail : API configuration is missing" | tee -a $WORKINGDIR/konginit.log
		exit 1
	fi
	rescode=`curl -s -X POST $service_url -d "$s_payload" -H "Content-Type: application/json" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
	if [ $rescode -ne 201 ]; then
		echo "    Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
		exit 1
	else 
		echo "    Success"
	fi
	echo "  + Adding $service route" | tee -a $WORKINGDIR/konginit.log
	r_payload=`jq ".apis | .[].route | select(.name==\"${service}\")" $WORKINGDIR/kong.json`
	if [ -z "$r_payload" ]; then
		echo "    Fail : Route Configuration is missing" | tee -a $WORKINGDIR/konginit.log
		exit 1
	fi
	rescode=`curl -s -X POST $(route_url $service) -d "$r_payload" -H "Content-Type: application/json" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
	if [ $rescode -ne 201 ]; then
		echo "    Fail : Return $rescode" | tee -a $WORKINGDIR/konginit.log
		exit 1
	else
		echo "    Success"
	fi
done
echo "# API Import Configuration Complete"
