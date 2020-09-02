#!/bin/bash
dockerimgs=("kong:2.1" "mcr.microsoft.com/dotnet/core/aspnet:3.1" "mongo:4.2.8" "postgres:11.8" "portainer/portainer-ce:latest" "pantsel/konga:0.14.9")
dkimgflag=0
for img in ${dockerimgs[@]} 
do
	echo -n "$img"
	docker image inspect $img > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo " found"
	else
		echo " miss"
		dkimgflag=1
	fi
done

if [ $dkimgflag -eq 1 ]; then
	echo "*** Some docker image in missing need internet access to download them"
fi
