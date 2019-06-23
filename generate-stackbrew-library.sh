#!/bin/bash
set -e

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

defaultVariant='apache'

# Get the most recent commit which modified any of "$@".
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# Get the most recent commit which modified "$1/Dockerfile" or any file that
# the Dockerfile copies into the rootfs (with COPY).
dockerfileCommit() {
	local dir="$1"; shift
	(
		cd "$dir";
		fileCommit Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++)
							print $i;
				}
			')
	)
}

# Depends on https://github.com/roundcube/roundcubemail/issues/5827
#getArches() {
#	local repo="$1"; shift
#	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'
#
#	eval "declare -g -A parentRepoToArches=( $(
#		find -name 'Dockerfile' -exec awk '
#				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
#					print "'"$officialImagesUrl"'" $2
#				}
#			' '{}' + \
#			| sort -u \
#			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
#	) )"
#}
#getArches 'roundcubemail'

# Header.
cat <<-EOH
# This file is generated via https://github.com/roundcube/roundcubemail-docker$(fileCommit "$self")/$self
Maintainers: Thomas Bruederli <thomas@roundcube.net>
GitRepo: https://github.com/roundcube/roundcubemail-docker.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

latest="$(
	git ls-remote --tags https://github.com/roundcube/roundcubemail.git \
		| cut -d/ -f3 \
		| grep -P -- '^[\d\.]+$' \
		| sort -V \
		| tail -1
)"

variants=( */ )
variants=( "${variants[@]%/}" )

for variant in "${variants[@]}"; do
	commit="$(dockerfileCommit "$variant")"
	fullversion="$(git show "$commit":"$variant/Dockerfile" | awk '$1 == "ENV" && $2 == "ROUNDCUBEMAIL_VERSION" { print $3; exit }')"

	versionAliases=( "$fullversion" "${fullversion%.*}" "${fullversion%.*.*}" )
	if [ "$fullversion" = "$latest" ]; then
		versionAliases+=( "latest" )
	fi

	variantAliases=( "${versionAliases[@]/%/-$variant}" )
	variantAliases=( "${variantAliases[@]//latest-}" )

	if [ "$variant" = $defaultVariant ]; then
		variantAliases+=( "${versionAliases[@]}" )
	fi

	variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$variant/Dockerfile")"
	#variantArches="${parentRepoToArches[$variantParent]}"
	variantArches="amd64 arm64v8 i386"

	cat <<-EOE

		Tags: $(join ', ' "${variantAliases[@]}")
		Architectures: $(join ', ' $variantArches)
		GitCommit: $commit
		Directory: $variant
	EOE
done
