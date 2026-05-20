#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage $(basename $0) [--tag-as-latest] [--run-tests] [--push] [--target root|nonroot] [--platforms PLATFORM,…] --variant VARIANT --version VERSION"
    echo "E.g.:  $(basename $0) --variant apache --version 1.7.0 --tag-as-latest --platforms x86_64,arm64 --push"
    echo "Or:    $(basename $0) --variant fpm --version 1.2.3 --target nonroot --run-tests"
    exit 1
}

tag_as_latest=no
target=root
push=no
platforms=''
run_tests=no
tag_suffix=''

while [[ $# -gt 0 ]]; do
    ARG="$1"
    shift
    case "$ARG" in
        --variant)
            variant="$1"
            shift
            ;;
        --version)
            version="$1"
            shift
            ;;
        --run-tests)
            run_tests="yes"
            ;;
        --tag-as-latest)
            tag_as_latest="yes"
            ;;
        --target)
            target="$1"
            shift
            ;;
        --platforms)
            platforms="$1"
            shift
            ;;
        --push)
            push="yes"
            ;;
        ''|-h|--help)
            usage
            ;;
        esac
done

if [[ -z "$variant" ]]; then
    usage
fi

if [[ -z "$version" ]]; then
    usage
fi

if [[ "$target" = "nonroot" ]]; then
    tag_suffix='-nonroot'
    http_port=8000
else
    http_port=80
fi

# Required to generate $version_branch
shopt -s extglob

version_branch="${version/%.+([0-9])/.x}"

image_tags=(
    "${version}-${variant}${tag_suffix}"
    "${version_branch}-${variant}${tag_suffix}"
)

if [[ "$tag_as_latest" != "no" ]]; then
    image_tags+=("latest-${variant}${tag_suffix}")

    if [[ "$variant" = "apache" ]]; then
        image_tags+=("latest${tag_suffix}")
    fi
fi

args=(
    "--build-arg ROUNDCUBEMAIL_VERSION=${version}"
    "--target $target"
)

image_name='roundcube/roundcubemail'
main_image_ref=${image_name}:${image_tags[0]}

for tag in ${image_tags[@]}; do
    args+=("-t ${image_name}:${tag}")
done

set -eu

if test -n "$platforms"; then
    args+=("--platforms ${platforms}")
fi

# Build image
docker buildx build ${args[*]} $variant

if test "$run_tests" = 'yes'; then
    # Test the native image.
    if [[ "$variant" = "apache" ]]; then
        test_file_name_suffix='apache-postgres'
    else
        test_file_name_suffix='fpm-postgres'
    fi
    export ROUNDCUBEMAIL_TEST_IMAGE=${main_image_ref}
    export HTTP_PORT=${http_port}
    docker compose -f ./tests/docker-compose.test-${test_file_name_suffix}.yml up --exit-code-from=sut --abort-on-container-exit
fi

if test "$push" = 'yes'; then
    # Push all the images with all the tags
    docker push --all-tags "${main_image_ref}"
fi
