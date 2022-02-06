FROM php:7.4-fpm-alpine
LABEL maintainer="Thomas Bruederli <thomas@roundcube.net>"

# entrypoint.sh and installto.sh dependencies
RUN set -ex; \
	\
	apk add --no-cache \
		bash \
		coreutils \
		rsync \
		tzdata

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		icu-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		libtool \
		openldap-dev \
		postgresql-dev \
		sqlite-dev \
	; \
	\
	docker-php-ext-configure gd; \
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
	pecl install imagick redis; \
	docker-php-ext-enable imagick opcache redis; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		)"; \
	apk add --virtual .roundcubemail-phpext-rundeps imagemagick $runDeps; \
	apk del .build-deps

# add composer.phar
ADD https://getcomposer.org/installer /tmp/composer-installer.php

RUN php /tmp/composer-installer.php --install-dir=/usr/local/bin/; \
	rm /tmp/composer-installer.php


# expose these volumes
VOLUME /var/roundcube/config
VOLUME /var/roundcube/db
VOLUME /var/www/html
VOLUME /tmp/roundcube-temp

# Define Roundcubemail version
ENV ROUNDCUBEMAIL_VERSION 1.4.13

# Define the GPG key used for the bundle verification process
ENV ROUNDCUBEMAIL_KEYID "F3E4 C04B B3DB 5D42 15C4  5F7F 5AB2 BAA1 41C4 F7D5"

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
	curl -fSL https://roundcube.net/download/pubkey.asc -o /tmp/pubkey.asc; \
	LC_ALL=C.UTF-8 gpg -n --show-keys --with-fingerprint --keyid-format=long /tmp/pubkey.asc | if [ $(grep -c -o 'Key fingerprint') != 1 ]; then echo 'The key file should contain only one GPG key'; exit 1; fi; \
	LC_ALL=C.UTF-8 gpg -n --show-keys --with-fingerprint --keyid-format=long /tmp/pubkey.asc | if [ $(grep -c -o "${ROUNDCUBEMAIL_KEYID}") != 1 ]; then echo 'The key ID should be the roundcube one'; exit 1; fi; \
	gpg --batch --import /tmp/pubkey.asc; \
	rm /tmp/pubkey.asc; \
	gpg --batch --verify roundcubemail.tar.gz.asc roundcubemail.tar.gz; \
	gpgconf --kill all; \
	mkdir /usr/src/roundcubemail; \
	tar -xf roundcubemail.tar.gz -C /usr/src/roundcubemail --strip-components=1 --no-same-owner; \
	rm -r "$GNUPGHOME" roundcubemail.tar.gz.asc roundcubemail.tar.gz; \
	rm -rf /usr/src/roundcubemail/installer; \
	chown -R www-data:www-data /usr/src/roundcubemail/logs; \
	apk del .fetch-deps

# include the wait-for-it.sh script
RUN curl -fL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /wait-for-it.sh && chmod +x /wait-for-it.sh

# use custom PHP settings
COPY php.ini /usr/local/etc/php/conf.d/roundcube-defaults.ini

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["php-fpm"]
