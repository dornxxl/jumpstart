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

# Edit Later
echo "  + Adding Consumer" | tee -a $WORKINGDIR/konginit.log
echo "    -> mypolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers --data "username=mypolicyapplication" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "    -> oiccheckpolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers --data "username=oiccheckpolicyapplication" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi

echo "  + Add acl group"
echo "    -> mypolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers/mypolicyapplication/acls --data "group=mypolicyaclgroup" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "    -> oiccheckpolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers/oiccheckpolicyapplication/acls --data "group=oiccheckpolicyaclgroup" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi

echo "  + Generate Oauth2 Key"
echo "    -> mypolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers/mypolicyapplication/oauth2 --data "name=mypolicyoauth2" --data "redirect_uris=http://google.com/" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "    -> oiccheckpolicyapplication"
rescode=`curl -sX POST http://localhost:8001/consumers/oiccheckpolicyapplication/oauth2 --data "name=oiccheckpolicyoauth2" --data "redirect_uris=http://google.com/" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi

echo "  + Add Oauth2 Route plugins"
echo "    -> mypolicy"
rescode=`curl -sX POST http://localhost:8001/routes/mypolicy/plugins --data "name=oauth2" --data "config.enable_client_credentials=true" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "    -> oiccheckpolicy"
rescode=`curl -sX POST http://localhost:8001/routes/oiccheckpolicy/plugins --data "name=oauth2" --data "config.enable_client_credentials=true" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi

echo "  + Add ACL Route plugins"
echo "    -> mypolicy"
rescode=`curl -sX POST http://localhost:8001/routes/mypolicy/plugins --data "name=acl" --data "config.allow=mypolicyaclgroup" --data "config.hide_groups_header=true" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "    -> oiccheckpolicy"
rescode=`curl -sX POST http://localhost:8001/routes/oiccheckpolicy/plugins --data "name=acl" --data "config.allow=oiccheckpolicyaclgroup" --data "config.hide_groups_header=true" -w "%{http_code}" -o >(jq -M '.' >> $WORKINGDIR/konginit.log)`
if [ $rescode -ne 201 ]; then
	echo "      Fail: Return $rescode" | tee -a $WORKINGDIR/konginit.log
	exit 1
else
	echo "      Success" | tee -a $WORKINGDIR/konginit.log
fi
echo "# API Import Configuration Complete"
