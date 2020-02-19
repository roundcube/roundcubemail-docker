FROM php:7.3-apache
LABEL maintainer="Thomas Bruederli <thomas@roundcube.net>"

RUN set -ex; \
	apt-get update; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libicu-dev \
		libjpeg62-turbo-dev \
		libldap2-dev \
		libpng-dev \
		libpq-dev \
		libsqlite3-dev \
		libzip-dev \
	; \
	\
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
	docker-php-ext-install \
		exif \
		gd \
		intl \
		ldap \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# enable mod_rewrite
RUN a2enmod rewrite

# expose these volumes
VOLUME /var/roundcube/config
VOLUME /var/roundcube/db
VOLUME /var/www/html
VOLUME /tmp/roundcube-temp

# Define Roundcubemail version
ENV ROUNDCUBEMAIL_VERSION 1.4.3

# Download package and extract to web volume
RUN set -ex; \
	fetchDeps="gnupg dirmngr"; \
	apt-get -qq update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	curl -o roundcubemail.tar.gz -fSL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz; \
	curl -o roundcubemail.tar.gz.asc -fSL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz.asc; \
	export GNUPGHOME="$(mktemp -d)"; \
	# workaround for "Cannot assign requested address", see e.g. https://github.com/inversepath/usbarmory-debian-base_image/issues/9
	echo "disable-ipv6" > "$GNUPGHOME/dirmngr.conf"; \
	# ha.pool.sks-keyservers.net seems to be unreliable, use pgp.mit.edu as fallback
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys F3E4C04BB3DB5D4215C45F7F5AB2BAA141C4F7D5 || gpg --batch --keyserver pgp.mit.edu --recv-keys F3E4C04BB3DB5D4215C45F7F5AB2BAA141C4F7D5; \
	gpg --batch --verify roundcubemail.tar.gz.asc roundcubemail.tar.gz; \
	tar -xf roundcubemail.tar.gz -C /usr/src/; \
	gpgconf --kill all; \
	rm -r "$GNUPGHOME" roundcubemail.tar.gz.asc roundcubemail.tar.gz; \
	# upstream tarballs include ./roundcubemail-${ROUNDCUBEMAIL_VERSION}/ so this gives us /usr/src/roundcubemail-${ROUNDCUBEMAIL_VERSION}
	mv /usr/src/roundcubemail-${ROUNDCUBEMAIL_VERSION} /usr/src/roundcubemail; \
	rm -rf /usr/src/roundcubemail/installer

# include the wait-for-it.sh script
RUN curl -fL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /wait-for-it.sh && chmod +x /wait-for-it.sh

# use custom PHP settings
COPY php.ini /usr/local/etc/php/conf.d/roundcube-defaults.ini

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
