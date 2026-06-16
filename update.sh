#!/bin/bash

set -eu

VERSION_STABLE="${1:-$(curl -fsS https://roundcube.net/VERSION.txt)}"
VERSION_LTS="${2:-$(curl -fLsS https://raw.githubusercontent.com/roundcube/roundcube.github.com/refs/heads/master/_data/downloads.json | yq '.lts.packages[0].version')}"

if test -z "$VERSION_STABLE" -o -z "$VERSION_LTS"; then
	echo "Failed to get version numbers, cancelling this script run."
	exit 1
fi

#set -x
echo "Generating files for stable version $VERSION_STABLE..."

update_build_files_from_templates() {
    variant="$1"
    base="$2"
    cmd="$3"
	dir="$variant"
	mkdir -p "$dir"

	template="templates/Dockerfile-${base}.templ"
	cp templates/docker-entrypoint.sh "$dir/docker-entrypoint.sh"
	cp templates/php.ini "$dir/php.ini"
	sed -E -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%VERSION%%/'"$VERSION_STABLE"'/;
		s/%%CMD%%/'"${cmd}"'/;
	' $template | tr '¬' '\n' > "$dir/Dockerfile"

	if [[ -f "$dir/nonroot-add.txt" ]]; then
		sed -i -e '/%%NONROOT_ADD%%/ {' -e 'r '"$dir/nonroot-add.txt" -e 'd' -e '}' $dir/Dockerfile
	else
		sed -i 's/%%NONROOT_ADD%%//' $dir/Dockerfile
	fi

	echo "✓ Wrote $dir/Dockerfile"
}

update_build_files_from_templates apache debian apache2-foreground
update_build_files_from_templates fpm debian php-fpm
update_build_files_from_templates fpm-alpine alpine php-fpm

export VERSION_STABLE VERSION_LTS
yq -i '.jobs.build-and-testvariants.strategy.matrix.version = [strenv(VERSION_STABLE), strenv(VERSION_LTS)]' .github/workflows/test.yml
yq -i '.jobs.build-and-testvariants.strategy.matrix.version = [strenv(VERSION_STABLE), strenv(VERSION_LTS)]' .github/workflows/build.yml
yq -i '.jobs.build-and-testvariants.strategy.matrix.include[0].version = strenv(VERSION_STABLE)' .github/workflows/build.yml
echo "Updated version numbers in build.yml and test.yml workflows"

echo "Done."
