#!/usr/bin/env bash

EXPECTED_STRING='Error: No source code in /var/www/html – you must mount your code base to that path!'

ContID="$(docker run -d roundcube/roundcubemail:development)"
sleep 5

if $(docker logs $ContID 2>&1 | grep -q "$EXPECTED_STRING"); then
    docker rm -f $ContID 2>&1 >/dev/null
    echo "✅ Test successful "
    exit 0
fi

echo "⚠️ Error: The container output did not contain the expected string '$EXPECTED_STRING', the test failed!"
echo "Container output:"
docker logs $ContID

docker rm -f $ContID 2>&1 >/dev/null
exit 1
