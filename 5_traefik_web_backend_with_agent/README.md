# Traefik rest api backend with agent

## Create some services

    docker service create --name service-1 --publish 80 nginx && \
    docker service create --name service-2 --publish 80 httpd
