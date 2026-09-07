#!/usr/bin/env bash

image_name=roundcube/roundcubemail:development

set -eu

cd "$(dirname "$0")"

# Build image
docker buildx build --tag $image_name --load .

EXPECTED_STRING='Error: No source code in /var/www/html – you must mount your code base to that path!'

ContID="$(docker run -d $image_name)"
sleep 5

if $(docker logs "$ContID" 2>&1 | grep -q "$EXPECTED_STRING"); then
    docker rm -f "$ContID" >/dev/null 2>&1
    echo "✅ Test successful "
    exit 0
fi

echo "⚠️ Error: The container output did not contain the expected string '$EXPECTED_STRING', the test failed!"
echo "Container output:"
docker logs "$ContID"

docker rm -f "$ContID" >/dev/null 2>&1 
exit 1
