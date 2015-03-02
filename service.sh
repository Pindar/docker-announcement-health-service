#!/bin/bash

export ETCD_PORT=${ETCD_PORT:-4001}
export HOST_IP=${HOST_IP:-172.17.42.1}
export ETCD=$HOST_IP:$ETCD_PORT

if [[ $ENVIRONMENT == "" || $NUMBER == "" || $SERVICE == "" || $ANNOUNCE_VALUE == "" || $HEALTH_URL == "" ]]; then
  echo "[announce-health] please specify ENVIRONMENT, NUMBER, SERVICE, ANNOUNCE_VALUE, HEALTH_URL";
  exit 1;
fi

THRESHOLD=${THRESHOLD:-5}
TIMEOUT=${TIMEOUT:-45}
TTL=$((THRESHOLD*TIMEOUT))

echo "[announce-health] Start announce service for $SERVICE";


function clean_up
{
  etcdctl --peers $ETCD rm /announce/services/$SERVICE/$ENVIRONMENT/$NUMBER --recursive
  etcdctl --peers $ETCD rm /health/services/$SERVICE/$ENVIRONMENT/$NUMBER
  exit;
}


trap clean_up SIGHUP SIGINT SIGTERM

i=0;
while true; do

  if [[ $((i % 3)) -eq 0 ]]; then
    failure=0    
  fi;

  echo "[announce-health] check";

  if [[ `curl -f --silent --max-time 60 $HEALTH_URL -D - | grep "200 OK"` ]]; then
      echo "[announce-health] Service $SERVICE success";
      etcdctl --peers $ETCD set /announce/services/$SERVICE/$ENVIRONMENT/$NUMBER "$ANNOUNCE_VALUE" --ttl $TTL;
      etcdctl --peers $ETCD set /health/services/$SERVICE/$ENVIRONMENT/$NUMBER OK --ttl $TTL;
    else
      failure+=1
      if [ $failure > $THRESHOLD ]; then
        echo "[announce-health] Service $SERVICE failed $failure times in a row";
        etcdctl --peers $ETCD rm /announce/services/$SERVICE/$ENVIRONMENT/$NUMBER ;
        etcdctl --peers $ETCD set /health/services/$SERVICE/$ENVIRONMENT/$NUMBER FAILURE --ttl $TTL;
      fi;
    fi;

  i=$((i+1));
	sleep $TIMEOUT;
done
