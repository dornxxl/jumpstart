#!/bin/bash
export DEF_INTERFACE=`ip route | awk '$1 ~ /^default$/ { print $5 }'`
export DEF_NETWORK=`ip addr show dev "$DEF_INTERFACE" | awk '$1 ~ /^inet$/ { print $2}'`

if [ "$1" = "print" ]; then
	echo "Defult Interface is $DEF_INTERFACE : $DEF_NETWORK"
fi
