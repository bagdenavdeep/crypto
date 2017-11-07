#!/bin/bash

# Run:
# bash startMicroservice.sh

npm install

npm install forever -g

path=/var/log/

logFiles=(microservice microservice.out microservice.error geth)

for file in ${logFiles[*]}
do
    logFileName=${path}$file.log

    if [ ! -e $logFileName ] ; then
        touch $logFileName
    fi

    if [ ! -w $logFileName ] ; then
        chmod 755 $logFileName
        chown `whoami`:`groups` $logFileNamex
    fi
done

PORT=8000 NODE_ENV=development forever start config/forever.json
