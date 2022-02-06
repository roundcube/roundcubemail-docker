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

declare -A EXTRAS=(
	[apache]='¬RUN a2enmod rewrite'
	[fpm]=''
	[fpm-alpine]=''
)

VERSION="1.4.13"

#set -x
echo "Generating files for version $VERSION..."

travisEnv=
for variant in apache fpm fpm-alpine; do
	dir="$variant"
	mkdir -p "$dir"

	template="templates/Dockerfile-${BASE[$variant]}.templ"
	cp templates/docker-entrypoint.sh "$dir/docker-entrypoint.sh"
	cp templates/php.ini "$dir/php.ini"
	sed -E -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%EXTRAS%%/'"${EXTRAS[$variant]}"'/;
		s/%%VERSION%%/'"$VERSION"'/;
		s/%%CMD%%/'"${CMD[$variant]}"'/;
	' $template | tr '¬' '\n' > "$dir/Dockerfile"

	echo "✓ Wrote $dir/Dockerfile"

	travisEnv+='¬  - VERSION='"$VERSION"' VARIANT='"$variant"
done

sed -E -e 's/%%ENV%%/'"$travisEnv"'/;' templates/travis.yml | tr '¬' '\n' > .travis.yml

echo "Done."
