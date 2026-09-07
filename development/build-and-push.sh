#!/usr/bin/env bash

image_name=roundcube/roundcubemail:development

set -eu

cd "$(dirname "$0")"

docker buildx build --tag $image_name --platform "linux/arm64,linux/arm/v6,linux/arm/v7,linux/386,linux/amd64" .
docker push $image_name
