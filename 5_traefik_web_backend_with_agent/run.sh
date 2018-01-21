#!/bin/bash

set -e

AGENT_IMAGE="swarm-proxy-strategies/traefik-with-agent:1.0"
AGENT_NAME="traefik-agent"
AGENT_MOUNTS=-"-mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock"
AGENT_PLACEMENT="--constraint node.role==manager"
AGENT_SERVICE="--name $AGENT_NAME $AGENT_MOUNTS $AGENT_PLACEMENT -e REFRESH_INTERVAL=10 $AGENT_IMAGE"

PROXY_IMAGE="traefik:1.5-alpine"
PROXY_NAME="traefik"
PROXY_PORTS="--publish 80:80 --publish 8080:8080"
PROXY_ARGS="--api --api.dashboard --rest --accesslog --loglevel=DEBUG --debug"
PROXY_SERVICE="--name traefik $PROXY_PORTS $PROXY_IMAGE $PROXY_ARGS"

# AGENT_CREATED=$(docker-machine ssh master docker service ls -q --filter "name=$AGENT_NAME")
# PROXY_CREATED=$(docker service ls -q --filter "name=$PROXY_NAME")

function agent-created {
  docker-machine ssh master docker service ls -q --filter "name=$AGENT_NAME"
}

function proxy-created {
  docker service ls -q --filter "name=$PROXY_NAME"
}
# PROXY_CRE

function setup-docker-machine {
  local machines=(master worker1 worker2)

  if [[ ! -z $(docker-machine ls -q) ]]
  then
    return
  fi

  for machine in ${machines[@]}
  do
    docker-machine create --virtualbox-memory 2048 $machine
  done

  local master_ip=$(docker-machine ip master)

  docker-machine ssh master docker swarm init --advertise-addr $master_ip
  local token=$(docker-machine ssh master docker swarm join-token -q worker)

  for machine in worker1 worker2
  do
    docker-machine ssh $machine docker swarm join --token $token $master_ip:2377
  done
}

function agent-build {
  eval $(docker-machine env master)
  # docker-machine scp -r agent master:/home/docker/agent
	docker image build -t $AGENT_IMAGE agent
  eval $(docker-machine env --unset)
}

function agent-deploy {
  eval $(docker-machine env master)
  if [ -z $(agent-created) ]
  then
    docker service create $AGENT_SERVICE
  else
    docker service update --force $AGENT_NAME
  fi
  eval $(docker-machine env --unset)
}

function agent-undeploy {
  eval $(docker-machine env master)
  if [ ! -z $(agent-created) ]
  then
    docker service rm $AGENT_NAME
  fi
  eval $(docker-machine env --unset)
}

function proxy-deploy {
  if [ -z $(proxy-created) ]
  then
    docker service create $PROXY_SERVICE
  else
    docker service update --force $PROXY_NAME
  fi
}

function proxy-undeploy {
  if [ ! -z $(proxy-created) ]
  then
    docker service rm $PROXY_NAME
  fi
}

case $1 in
deploy)
  setup-docker-machine
  agent-build && agent-deploy && proxy-deploy
  ;;
redeploy)
  agent-undeploy && proxy-undeploy
  sleep 2
  agent-build && agent-deploy && proxy-deploy
  ;;
undeploy)
  agent-undeploy && proxy-undeploy
  ;;
*)
  echo USAGE:
  echo "./run.sh deploy"
  echo "./run.sh undeploy"
  echo "./run.sh redeploy"
  ;;
esac
