#!/bin/bash

for f in *
do
    if test -d $f; then
	cd $f
	for file in *
	do
	    if [ -f $file ] && [ ${file##*.} == "proto" ]; then
		#echo $file
		protoc -I . -I ../common -o ${file%.*}.pb $file
	    fi
	done
	cd ..
    fi
done
