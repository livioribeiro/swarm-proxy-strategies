# Traefik

## Create network

    $ docker network create --driver overlay proxy

## Create some services

    $ docker service create --name service-1 \
        --network proxy --label traefik.port=80 nginx
    $ docker service create --name service-2 \
        --network proxy --label traefik.port=80 httpd

## Deploy traefik

    $ docker service create --name traefik \
        --constraint=node.role==manager \
        --publish 80:80 --publish 8080:8080 \
        --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
        --network proxy \
        --docker \
        --docker.swarmmode \
        --docker.domain=traefik \
        --docker.watch \
        --web
