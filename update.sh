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

VERSION="${1:-$(curl -fsS https://roundcube.net/VERSION.txt)}"

#set -x
echo "Generating files for version $VERSION..."

for variant in apache fpm fpm-alpine; do
	dir="$variant"
	mkdir -p "$dir"

	template="templates/Dockerfile-${BASE[$variant]}.templ"
	cp templates/docker-entrypoint.sh "$dir/docker-entrypoint.sh"
	cp templates/php.ini "$dir/php.ini"
	sed -E -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%VERSION%%/'"$VERSION"'/;
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
perl -pi -e "s/1\.[0-9]\.[0-9]+-/${VERSION}-/" .github/workflows/build.yml
echo "Updating version in build.yml workflow"

echo "Done."
