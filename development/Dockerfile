FROM docker.io/roundcube/roundcubemail:latest-apache-nonroot

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends npm git sudo \
 && apt-get clean

COPY --chmod=0755 docker-entrypoint.sh /

# Prevent the upstream image from overwriting our code
RUN rm -r /usr/src/roundcubemail

RUN install -d -o www-data -g www-data /var/roundcube

# Pre-download js dependencies (these don't change much over time).
ENV CACHEDIR=/var/cache/roundcubemail/jsdeps
RUN install -o www-data -d "$CACHEDIR"

USER www-data

# We need the code from the repo, not from a released tarball.
RUN cd /tmp \
 && curl -OLs https://github.com/roundcube/roundcubemail/archive/refs/heads/master.zip \
 && unzip -q master.zip \
 && ./roundcubemail-master/bin/install-jsdeps.sh \
 && rm -rf master.zip roundcubemail-master

VOLUME /var/www/html
