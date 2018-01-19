# Nginx mapping subdomain to service name

## Create network

    $ docker network create --driver overlay proxy

## Create some services

    docker service create --name service-1 \
        --network proxy --label traefik.port=80 nginx && \
    docker service create --name service-2 \
        --network proxy --label traefik.port=80 httpd

## Create nginx swarm config

    docker config create nginx.conf ./nginx.conf

## Deploy nginx service

    docker service create --name nginx \
        --publish 80:80
        --network proxy
        --config source=nginx.conf,target=/etc/nginx/conf.d/default.conf
        nginx
