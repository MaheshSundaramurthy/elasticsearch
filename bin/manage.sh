#!/bin/bash

if [[ -z ${CONSUL} ]]; then
    echo "Missing CONSUL environment variable"
    exit 1
fi

onStart() {
    MASTER=null
    while true
    do
        # get the list of ES master-only nodes from Consul
        MASTER=$(curl -Ls --fail http://${CONSUL}:8500/v1/catalog/service/elasticsearch-master | jq -r '.[0].ServiceAddress')
        if [[ $MASTER != "null" ]] && [[ -n $MASTER ]]; then
            break
        fi
        # if this is the first master-only node, use itself to bootstrap
        if [ ${ES_NODE_MASTER} == true ] && [ ${ES_NODE_DATA} == false ]; then
            MASTER=127.0.0.1
            break
        fi
        # this is not a master-only node and there are not master-only
        # nodes up yet, so wait and retry
        sleep 1.7
    done

    # update discovery.zen.ping.unicast.hosts
    REPLACEMENT=$(printf 's/^discovery\.zen\.ping\.unicast\.hosts.*$/discovery.zen.ping.unicast.hosts: ["%s"]/' ${MASTER})
    sed -i "${REPLACEMENT}" /etc/elasticsearch/elasticsearch.yml
}

health() {
    local privateIp=$(ip addr show eth0 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    /usr/bin/curl --fail -s -o /dev/null http://${privateIp}:9200
}

# do whatever the arg is
$1