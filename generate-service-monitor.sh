#!/bin/bash

set -e

echo -e "Environment variables:"
echo "PROJECT NAME=$1"
echo "MSP=$2"

echo -e "Convert service monitor template file to project folder '$1', MSP '$2'"
sed -e "s/_PROJECT_/$1/g" -e "s/_MSP_/$2/g" -e "s/_PORT_/$3/g"  ./proj-$1/servicemonitor.yaml > ./proj-$1/$2-servicemonitor.yaml
echo -e "Done!!! Please view config file in folder './proj-$1/$2-servicemonitor.yaml'"