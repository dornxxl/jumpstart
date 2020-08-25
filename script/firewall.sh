#!/bin/bash
###############################################
# Script to create simple firewall rule to    #
# Protect Application                         #
# website : https://www.oicgateway.com        #
###############################################
WORKINGDIR=`dirname "$0"`
if [ $# -ne 1 ]; then
	echo "Usage : $0 <whitelist>" 
	exit 1
fi	
echo "# Setting up Firewall"
echo "- Getting IP Address of Default Interface"
if [ -x $WORKINGDIR/getdefaultnetwork.sh ]; then
	echo -n "  "
	source $WORKINGDIR/getdefaultnetwork.sh print
else 
	echo " Missing getdefaultnetwork.sh script"
	exit 1
fi
LOCALNET=`$WORKINGDIR/cidr.sh "$DEF_NETWORK"`
local_net_in_whitelist=1 

echo "- Validate IP Whitelist"
if [ ! -z "$1" ]; then
	declare -a cidrs
	OIFS=$IFS
	IFS=','
	networks=($1)
	IFS=$OIFS
	for network in ${networks[@]}
	do
		echo -n "  "
		cidr=`$WORKINGDIR/cidr.sh "$network"`
		if [ $? -eq 0 ]; then
			echo "  $cidr ok"
			cidrs+=$cidr
			if [ "$cidr" = "$LOCALNET" ]; then
				local_net_in_whitelist=0
			fi
		else
			echo "  $network fail"
			exit 1
		fi
	done
	if [ $local_net_in_whitelist -ne 0 ]; then
		echo "*** Warning! Local Network is not in the White list"
	fi
else
	echo "Missing ip-whitelist parameter"
	exit 1;
fi

echo "- Checking UFW Application file"
if [ -f /etc/ufw/applications.d/ufw-jumpstart ]; then
	echo "  Status: Exists"
else
	sudo cp $WORKINGDIR/ufw-jumpstart /etc/ufw/applications.d/
	if [ $? -eq 0 ]; then
		echo "  Status: Created"
	else
		echo "  Status: Failed"
		exit 1
	fi
fi

sudo ufw disable
sudo ufw --force reset 
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Limit number of connection to SSH
sudo ufw limit SSH
# Permit Public Access
sudo ufw allow APIGW
# White List for Protect Service
for net in ${cidrs[@]}
do
	sudo ufw allow from $net to any app APIMGT
	sudo ufw allow from $net to any app DOCKERMGT
	sudo ufw allow from $net to any app FTP
	sudo ufw allow from $net to any app HEALTHCHECK
done
sudo ufw enable
