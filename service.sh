
#!/bin/bash

export ETCD_PORT=${ETCD_PORT:-4001}
export HOST_IP=${HOST_IP:-172.17.42.1}
export ETCD=$HOST_IP:$ETCD_PORT

if [[ $ENVIRONMENT == "" || $NUMBER == "" || $SERVICE == "" || $ANNOUNCE_VALUE == "" || $HEALTH_URL ]]; then
  echo "[announce-health] please specify ENVIRONMENT, NUMBER and SERVICE";
  exit 1;
fi

THRESHOLD=${THRESHOLD:-5}
TIMEOUT=${TIMEOUT:-45}
TTL=$((THRESHOLD*TIMEOUT))

echo "[announce-health] Start announce service for $SERVICE";

i=0;
while true && i++; do

  if [[ $((i % 3)) -eq 0 ]]; then
    failure=0    
  fi;

  if [[ `curl --silent --max-time 60 $HEALTH_URL -D - -O | grep "200 OK"` ]]; then
      etcdctl set --peers $ETCD /announce/services/$SERVICE/$ENVIRONMENT/$NUMBER $ANNOUNCE_VALUE --ttl $TTL;
      etcdctl set --peers $ETCD /health/services/$SERVICE/$ENVIRONMENT/$NUMBER OK --ttl $TTL;
    else
      failure+=1
      if [ $failure > $THRESHOLD ]; then
        echo "[announce-health] Service $SERVICE failed $failure times in a row";
        etcdctl rm --peers $ETCD /announce/services/$SERVICE/$ENVIRONMENT/$NUMBER ;
        etcdctl set --peers $ETCD /health/services/$SERVICE/$ENVIRONMENT/$NUMBER FAILURE --ttl $TTL;
      fi;
    fi;

	sleep $TIMEOUT;
done

etcdctl rm --peers $ETCD /announce/services/ingress/$ENVIRONMENT/$NUMBER --recursive
etcdctl rm --peers $ETCD /health/services/$SERVICE/$ENVIRONMENT/$NUMBER