#!/bin/bash
# set -eu

declare -A CMD=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A BASE=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

VERSION_STABLE="${1:-$(curl -fsS https://roundcube.net/VERSION.txt)}"
VERSION_LTS="${1:-$(curl -fLsS https://raw.githubusercontent.com/roundcube/roundcube.github.com/refs/heads/master/_data/downloads.json | yq '.lts.packages[0].version')}"

#set -x
echo "Generating files for stable version $VERSION_STABLE..."

for variant in apache fpm fpm-alpine; do
	dir="$variant"
	mkdir -p "$dir"

	template="templates/Dockerfile-${BASE[$variant]}.templ"
	cp templates/docker-entrypoint.sh "$dir/docker-entrypoint.sh"
	cp templates/php.ini "$dir/php.ini"
	sed -E -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%VERSION%%/'"$VERSION_STABLE"'/;
		s/%%CMD%%/'"${CMD[$variant]}"'/;
	' $template | tr '¬' '\n' > "$dir/Dockerfile"

	if [[ -f "$dir/nonroot-add.txt" ]]; then
		sed -i -e '/%%NONROOT_ADD%%/ {' -e 'r '"$dir/nonroot-add.txt" -e 'd' -e '}' $dir/Dockerfile
	else
		sed -i 's/%%NONROOT_ADD%%//' $dir/Dockerfile
	fi

	echo "✓ Wrote $dir/Dockerfile"
done

# Use perl to avoid problems with BSD vs. GNU sed, which have incompatible
# argument syntax for editing files in-place.
perl -pi -e "s/version: \['1\.[0-9]\.[0-9]+',\s*'1\.[0-9]\.[0-9]+'\]/version: ['${VERSION_STABLE}', '${VERSION_LTS}']/" .github/workflows/build.yml
echo "Updating version numbers in build.yml workflow"

echo "Done."
