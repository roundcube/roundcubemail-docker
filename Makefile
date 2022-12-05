IMAGE_TAG ?= phpmyadmin-snapshots
# All: linux/386,linux/amd64,linux/arm/v5,linux/arm/v7,linux/arm64/v8,linux/mips64le,linux/ppc64le,linux/s390x
PLATFORM ?= linux/amd64
VERSION_RANGE ?= 5.2

ACTION ?= load
PROGRESS_MODE ?= plain

.PHONY: docker-build docker-push

docker-build:
	# https://github.com/docker/buildx#building
	docker buildx build \
		--tag $(IMAGE_TAG) \
		--progress $(PROGRESS_MODE) \
		--platform $(PLATFORM) \
		--build-arg VERSION_RANGE="$(VERSION_RANGE)" \
		--build-arg VCS_REF=`git rev-parse HEAD` \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		--$(ACTION) \
		./docker

docker-push:
	docker push $(IMAGE_TAG)
