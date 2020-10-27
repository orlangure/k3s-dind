#!/bin/bash

child=0
sig_handler() {
    sig_send=$1
    code=$2
    if [ $child -ne 0 ]; then
        kill -$sig_send $child
        wait $child
    fi
    exit $code
}
trap 'sig_handler HUP 129' HUP
trap 'sig_handler TERM 130' INT
trap 'sig_handler TERM 131' QUIT
trap 'sig_handler TERM 143' TERM

K3S_LOG="/var/log/k3s.log"

function dockerReady {
    docker info >& /dev/null
}

function runDocker {
    dockerd \
    --host=unix:///var/run/docker.sock \
    --host=tcp://0.0.0.0:2375 \
    > /var/log/docker.log 2>&1 < /dev/null &

    until dockerReady ; do
        sleep 0.2
    done
}

# DOCKER_HOST is how the host machine can be accessed from inside a container.
# It is important to add this address to SAN to allow accessing this container
# from another container using host port binding
DOCKER_HOST=`/sbin/ip route|awk '/default/ { print $3 }'`

K3S_NAME=${K3S_API_HOST}
K3S_ARGS=( \
    --no-deploy=traefik \
    --docker \
    --https-listen-port=${K3S_API_PORT:-8443} \
    --node-name=${K3S_NAME} \
    --tls-san=${K3S_NAME} \
    --tls-san=${DOCKER_HOST} \
)

function runServer {
    k3s server "${K3S_ARGS[@]}" >> ${K3S_LOG} 2>&1 &
}

function getKubeconfig {
    local cfg=$(cat /etc/rancher/k3s/k3s.yaml)
    if [[ $cfg =~ server ]]; then
        echo "${cfg}" | sed 's/\/\/127.0.0.1:/\/\/'"${K3S_NAME}"':/'
    fi
}

function waitForKubeconfig {
    local cfg=""
    while [ -z "${cfg}" ]; do
        sleep 1
        cfg=$(getKubeconfig)
    done

    echo "${cfg}" > /tmp/kubeconfig
    mv /tmp/kubeconfig /kubeconfig

	mkdir /config
	cp /kubeconfig /config/kubeconfig
}



echo > ${K3S_LOG}
tail -F ${K3S_LOG} &
child=$!

runDocker
runServer
waitForKubeconfig

touch /minikube_startup_complete
echo Kubeconfig is ready

config-server
