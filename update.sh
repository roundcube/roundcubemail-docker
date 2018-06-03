#!/bin/bash
set -eu

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A extras=(
	[apache]='\n# enable mod_rewrite\nRUN a2enmod rewrite'
	[fpm]=''
	[fpm-alpine]=''
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

latest="$(
	git ls-remote --tags https://github.com/roundcube/roundcubemail.git \
		| cut -d/ -f3 \
		| grep -P -- '^[\d\.]+$' \
		| sort -V \
		| tail -1
)"

set -x

for variant in apache fpm fpm-alpine; do
	template="Dockerfile-${base[$variant]}.template"
	cp $template "php-$variant/Dockerfile"
	cp docker-entrypoint.sh "php-$variant/docker-entrypoint.sh"
	sed -ri -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%VARIANT_EXTRAS%%/'"${extras[$variant]}"'/;
		s/%%VERSION%%/'"$latest"'/;
		s/%%CMD%%/'"${cmd[$variant]}"'/;
	' "php-$variant/Dockerfile"
done
