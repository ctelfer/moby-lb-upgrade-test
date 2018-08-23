#!/bin/bash
if [ $# -lt 1 -a "$1" = "-h" ] ; then
	echo usage $0 "[MYNAME [VERSION]]"
	exit 1
fi

U=""
if [ $# -gt 0 ] ; then
	U="$1/"
	shift
fi

V=":latest"
if [ $# -gt 0 ] ; then
	V=":"$1
	shift
fi

SCTAG=${U}swarmctl$V
TESTTAG=${U}lb-upgrade-test-cli$V

docker build -t $SCTAG swarmctl
docker build -t $TESTTAG testcli
if [ "$U" != "" ] ; then
	docker image push $SCTAG
	docker image push $TESTTAG
fi
