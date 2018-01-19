# Port Mapping

## create some services

    $ docker service create --name service-1 --publish 9001:80 nginx
    $ docker service create --name service-2 --publish 9002:80 httpd

## configure nginx

```nginx
upstream swarm_cluster {
    server swarm_cluster_1;
    server swarm_cluster_2;
    server swarm_cluster_3;
}

server {
    listen 80;
    server_name service1.example.com;

    location / {
        proxy_pass http://swarm_cluster:9001;
    }
}

server {
    listen 80;
    server_name service2.example.com;

    location / {
        proxy_pass http://swarm_cluster:9002;
    }
}
```
