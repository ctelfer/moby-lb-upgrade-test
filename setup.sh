#!/bin/bash
if [ $# -lt 1 -o "$1" = "-h" ] ; then
	echo usage $0 "MYNAME [VERSION]"
	exit 1
fi

NAME="$1"
U="$1/"
shift

V=":latest"
if [ $# -gt 0 ] ; then
	V=":"$1
	shift
fi

TESTTAG=${U}lb-upgrade-test-cli$V
docker build -t $TESTTAG testcli
echo pushing $TESTTAG
docker image push $TESTTAG
sed -e "s/MYNAME/$NAME/g" docker-compose.yml.tmpl > docker-compose.yml
