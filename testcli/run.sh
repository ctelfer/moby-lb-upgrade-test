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

echo `date`: "Starting client service" >> /output/client.log

COUNT=0
while true ; do
	for i in 1 2 3 4 5 ; do
		curl -sS http://$SERVER > /dev/null 2>/tmp/j$i.out &
	done

	for i in 1 2 3 4 5 ; do
		nextjob=$(jobs -l | awk '{print $2}')
		wait $nextjob
		if [ $? -ne 0 ] ; then
			( echo `date`: "Connection failure:" &&
			  cat /tmp/j$i.out ) >> /output/client.log
			ERRS=1
		fi
	done

	COUNT=$(($COUNT + 5))
	if [ $COUNT -gt 1200 ] ; then
		echo `date`: "Connected 1200 times" >> /output/client.log
		COUNT=0
	fi

	sleep 0.25
done
