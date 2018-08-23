#!/bin/bash

SERVER=service
if [ $# -ge 1 ] ; then
	SERVER=$1
	shift
fi

shopt -s huponexit

ERRS=0
doexit() {
	exit $ERRS
}

trap doexit TERM INT

sleep 5

while true ; do 
	for i in 1 2 3 4 ; do 
		curl -sS http://$SERVER > /dev/null 2>/tmp/j$i.out & 
	done

	for i in 1 2 3 4 ; do 
		nextjob=$(jobs -l | awk '{print $2}')
		wait $nextjob
		if [ $? -ne 0 ] ; then
			echo "Connection failure:"
			cat /tmp/j$i.out 
			ERRS=1
		fi
	done

	sleep 0.25
done
