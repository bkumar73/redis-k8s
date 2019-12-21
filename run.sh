#!/bin/bash

REDIS_PORT=6379
REDIS_MASTER_PORT_NUMBER=6379
ARGS=("--port" "${REDIS_PORT}")

masterrun()
{
	if [[ -n "$REDIS_PASSWORD" ]]
	then
		ARGS+=("--requirepass" "${REDIS_PASSWORD}")
		ARGS+=("--masterauth" "${REDIS_PASSWORD}")
	else
		ARGS+=("--protected-mode" "no")
	fi
	
	ARGS+=("--include" "/data/etc/conf/redis.conf")

	if [[ -f /data/etc/mounted/redis.conf ]]
        then
        	cp /data/etc/mounted/redis.conf /data/etc/conf/redis.conf
        fi

	#echo "all startup options are -"
	#echo "${ARGS[@]}"

	exec /usr/local/bin/redis-server "${ARGS[@]}"
}


sentinelrun()
{

        if [[ -f /data/etc/mounted/sentinel.conf ]]
        then
                cp /data/etc/mounted/sentinel.conf /data/etc/conf/sentinel.conf
        fi

        if [[ -n "$REDIS_PASSWORD" ]]
	then
		printf "\nsentinel auth-pass mymasterSet $REDIS_PASSWORD" >> /data/etc/conf/sentinel.conf
	fi

	if [[ -n "$REDIS_TYPE" ]] && [[ -n "${REDIS_HOST}" ]]
	then
		if [[ "$REDIS_TYPE" == "master" ]] 
		then
			if [[ -n "$REDIS_PASSWORD" ]] 
			then
				existing_sentinels=$(timeout -s 9 5 redis-cli --raw -h ${REDIS_HOST} -a "$REDIS_PASSWORD" -p 26379 SENTINEL sentinels  mymasterSet)
			else
				existing_sentinels=$(timeout -s 9 5 redis-cli --raw -h ${REDIS_HOST} -p 26379 SENTINEL sentinels  mymasterSet)
			fi
		fi

		echo "adding existing running sentinel info in config file"
		echo "$existing_sentinels" | awk -f /data/etc/parse_sentinels.awk | tee -a /data/etc/conf/sentinel.conf 
	fi

	#cat /data/etc/conf/sentinel.conf 

	exec /usr/local/bin/redis-server /data/etc/conf/sentinel.conf --sentinel
}


slaverun()
{
	if [[ -n "$REDIS_PASSWORD" ]] 
	then
        	ARGS+=("--requirepass" "${REDIS_PASSWORD}")
	        ARGS+=("--masterauth" "${REDIS_PASSWORD}")
	else
        	ARGS+=("--protected-mode" "no")
	fi

        if [[ -n "$REDIS_MASTER_HOST" ]]
	then
		ARGS+=("--slaveof" "${REDIS_MASTER_HOST}" "${REDIS_MASTER_PORT_NUMBER}")
	else
		echo "To run slave, set env REDIS_MASTER_HOST"
	fi

	ARGS+=("--include" "/data/etc/conf/slave.conf")

        if [[ -f /data/etc/mounted/slave.conf ]]
        then    
                cp /data/etc/mounted/slave.conf /data/etc/conf/slave.conf
        fi

        #echo "all startup options are -"
        #echo "${ARGS[@]}"

	exec /usr/local/bin/redis-server "${ARGS[@]}"
}


#- initialize script here
REDIS_MODE=$1

case $REDIS_MODE in
master)
	masterrun ;;
slave)
	slaverun ;;
sentinel)
	sentinelrun ;;
*)
	exec "$@" ;;
esac
