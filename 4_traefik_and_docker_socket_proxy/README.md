## Traefik with docker socket proxy

## Create network

    docker network create --driver overlay proxy

## Create some services

    docker service create --name service-1 \
        --network proxy --label traefik.port=80 nginx && \
    docker service create --name service-2 \
        --network proxy --label traefik.port=80 httpd

## Nginx configuration

```nginx
# need to run as root to access the docker socket
user  root;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  65;

    upstream docker_sock {
        server unix:/var/run/docker.sock;
    }

    server {
        listen 4999;

        location / {
            deny all;
        }

        location ~ ^/v\d+\.\d+/(info|version|events|services|networks|tasks) {
            limit_except GET {
                deny all;
            }

            proxy_pass http://docker_sock;
        }
    }
}
```

## Create stack file

```yaml
# stack.yaml

version: "3.4"

services:
  # expose docker endpoint using nginx
  docker_proxy:
    image: "nginx"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    configs:
      - source: nginx_conf
        target: "/etc/nginx/nginx.conf"
    deploy:
      mode: global
      placement:
        constraints:
         - node.role == manager

  traefik:
    image: "traefik"
    command:
      - --docker
      - --docker.swarmmode
      - --docker.domain=service.pb.gov.br
      - --docker.endpoint=http://docker_proxy:4999
      - --docker.watch
      - --web
    ports:
      - "80:80"
      - "8080:8080"
    networks:
      - default
      - proxy
    deploy:
      mode: global

configs:
  nginx_conf:
    file: ./nginx.conf

networks:
  proxy:
    external: true
```

## (Optional) Use HAProxy instead of Nginx

## HAProxy configuration

```haproxy
global
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

listen http-in
    bind *:4999
    server docker_sock unix@/var/run/docker.sock maxconn 32

    acl valid_method method GET HEAD
    acl valid_path path_reg ^/v\d+\.\d+/(info|version|events|services|networks|tasks)
    http-request deny unless valid_method valid_path
```

## Create stack file

```yaml
# stack.yaml

version: "3.4"

services:
  # expose docker endpoint using haproxy
  docker_proxy:
    image: "haproxy:1.8.3-alpine"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    configs:
      - source: haproxy_conf
        target: /usr/local/etc/haproxy/haproxy.cfg
    deploy:
      mode: global
      placement:
        constraints:
         - node.role == manager

  traefik:
    image: "traefik"
    command:
      - --docker
      - --docker.swarmmode
      - --docker.domain=service.pb.gov.br
      - --docker.endpoint=http://docker_proxy:4999
      - --docker.watch
      - --web
    ports:
      - "80:80"
      - "8080:8080"
    networks:
      - default
      - proxy
    deploy:
      mode: global

configs:
  nginx_conf:
    file: ./nginx.conf

networks:
  proxy:
    external: true
```

## Deploy stack

    docker stack deploy -c stack.yaml proxy
