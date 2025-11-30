#!/usr/bin/env bash

set -e

script_path="$( cd "$(dirname "$0")" ; pwd -P )"

echo "Starting dash-dev container. Listening on https://dash.dev.localhost"

docker run --rm $@ \
  --net=host \
  --name dash-dev \
  -v ${script_path}/nginx:/etc/nginx:ro \
  -v ${HTTP_TLS_CERTIFICATE}:/certs/ssl.crt:ro \
  -v ${HTTP_TLS_KEY}:/certs/ssl.key:ro \
  --entrypoint /usr/sbin/nginx \
  nginx:1.25.1-alpine-slim -c /etc/nginx/nginx.dev.conf -g "daemon off;"
