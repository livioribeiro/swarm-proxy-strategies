import logging
import time
import os

import docker
import requests


_TRAEFIK_ADDR = os.getenv('TRAEFIK_ADDR', '192.168.99.1:8080')
_TRAEFIK_DOMAIN = os.getenv('TRAEFIK_DOMAIN', 'localtest.me')
_REFRESH_INTERVAL = int(os.getenv('REFRESH_INTERVAL', '300'))

docker_client = docker.from_env()


def filter_func(serv):
    return 'Ports' in serv.attrs['Endpoint'] and len(serv.attrs['Endpoint']['Ports']) > 0


def map_func(serv):
    serv_name = serv.name
    serv_port = serv.attrs['Endpoint']['Ports'][0]['PublishedPort']
    return serv_name, serv_port


def get_payload(mappings, nodes):
    payload = {
     'frontends': {},
     'backends': {}
    }

    for service, port in mappings:
        frontend_name = f'{service}-frontend'
        route_name = f'{frontend_name}-route'
        backend_name = f'{service}-backend'

        payload['frontends'][frontend_name] = {
            'routes': {route_name: {'rule': f'Host:{service}.{_TRAEFIK_DOMAIN}'}},
            'backend': backend_name,
            'passHostHeader': True
        }

        payload['backends'][backend_name] = {
            'loadBalancer': {'method': 'drr'},
            'servers': {f'{backend_name}-server-{i+1}': {'url': f'http://{addr}:{port}'} for i, addr in enumerate(nodes)}
        }

    return payload


if __name__ == '__main__':

    while True:
        mappings = list(map(map_func, filter(filter_func, docker_client.services.list())))
        nodes = [n.attrs['Status']['Addr'] for n in docker_client.nodes.list() if n.attrs['Status']['State'] == 'ready']
        payload = get_payload(mappings, nodes)

        try:
            res = requests.put(f'http://{_TRAEFIK_ADDR}/api/providers/rest', json=payload)
            logging.info(res)
        except Exception as e:
            logging.error(e)

        time.sleep(_REFRESH_INTERVAL)
