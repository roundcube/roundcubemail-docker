#!/usr/bin/env bash

image_name=roundcube/roundcubemail:nightly

set -eu

cd "$(dirname "$0")"

# Build image
docker buildx build --tag $image_name --load .

export ROUNDCUBEMAIL_TEST_IMAGE="$image_name"
exec docker compose -f ../tests/docker-compose.test-apache-postgres.yml up --exit-code-from=sut --abort-on-container-exit
