FROM php:7.3-fpm-alpine
LABEL maintainer="Thomas Bruederli <thomas@roundcube.net>"

# entrypoint.sh and cron.sh dependencies
RUN set -ex; \
	\
	apk add --no-cache \
		bash \
		coreutils \
		tzdata

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		icu-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		openldap-dev \
		postgresql-dev \
		sqlite-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-configure ldap; \
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
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		)"; \
	apk add --virtual .roundcubemail-phpext-rundeps $runDeps; \
	apk del .build-deps

# expose these volumes
VOLUME /var/roundcube/config
VOLUME /var/roundcube/db
VOLUME /var/www/html
VOLUME /tmp/roundcube-temp

# Define Roundcubemail version
ENV ROUNDCUBEMAIL_VERSION 1.4.3

# Download package and extract to web volume
RUN set -ex; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
	; \
	\
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
	rm -rf /usr/src/roundcubemail/installer; \
	apk del .fetch-deps

# include the wait-for-it.sh script
RUN curl -fL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /wait-for-it.sh && chmod +x /wait-for-it.sh

# use custom PHP settings
COPY php.ini /usr/local/etc/php/conf.d/roundcube-defaults.ini

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php-fpm"]
