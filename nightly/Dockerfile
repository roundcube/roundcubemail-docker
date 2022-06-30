FROM php:8.0-apache AS base
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
		libmagickwand-dev \
		libpng-dev \
		libpq-dev \
		libsqlite3-dev \
		libzip-dev \
	; \
	\
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd; \
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
	pecl install imagick redis; \
	docker-php-ext-enable imagick opcache redis; \
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

# installto.sh dependencies
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
			rsync \
	; \
	rm -rf /var/lib/apt/lists/*

# ... and composer.phar
ADD https://getcomposer.org/installer /tmp/composer-installer.php

RUN php /tmp/composer-installer.php --install-dir=/usr/local/bin/; \
	rm /tmp/composer-installer.php

RUN a2enmod rewrite

### Temporary build image
FROM base AS builder

# install nodejs and lessc compiler
RUN apt-get -qq update; \
	apt-get install -y --no-install-recommends unzip gnupg dirmngr; \
	curl -sL https://deb.nodesource.com/setup_14.x | bash -; \
	apt-get install -y nodejs; \
	npm install -g less; \
	npm install -g uglify-js; \
	npm install -g lessc; \
	npm install -g less-plugin-clean-css; \
	npm install -g csso-cli

# Download source and build package into src directory
RUN set -ex; \
	curl -o roundcubemail.tar.gz -SL https://github.com/roundcube/roundcubemail/archive/master.tar.gz; \
	tar -xzf roundcubemail.tar.gz -C /usr/src/; \
	rm roundcubemail.tar.gz; \
	mv /usr/src/roundcubemail-master /usr/src/roundcubemail; \
	cd /usr/src/roundcubemail; \
	rm -rf installer tests public_html .ci .github .gitignore .editorconfig .tx .travis.yml; \
	(cd /usr/src/roundcubemail/skins/elastic; \
		lessc --clean-css="--s1 --advanced" styles/styles.less > styles/styles.min.css; \
		lessc --clean-css="--s1 --advanced" styles/print.less > styles/print.css; \
		lessc --clean-css="--s1 --advanced" styles/embed.less > styles/embed.css); \
	mv composer.json-dist composer.json; \
	composer.phar require kolab/net_ldap3 --no-install; \
	composer.phar require bjeavons/zxcvbn-php --no-install; \
	composer.phar install --no-dev --prefer-dist; \
	bin/install-jsdeps.sh; \
	bin/updatecss.sh; \
	rm -rf vendor/masterminds/html5/test \
		vendor/pear/*/tests vendor/*/*/.git* \
		vendor/pear/crypt_gpg/tools \
		vendor/pear/console_commandline/docs \
		vendor/pear/mail_mime/scripts \
		vendor/pear/net_ldap2/doc \
		vendor/pear/net_smtp/docs \
		vendor/pear/net_smtp/examples \
		vendor/pear/net_smtp/README.rst \
		vendor/endroid/qrcode/tests \
		temp/js_cache

### Final image
FROM base

RUN mkdir -p /usr/src
COPY --from=builder /usr/src/roundcubemail /usr/src/roundcubemail

# include the wait-for-it.sh script
RUN curl -fL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /wait-for-it.sh && chmod +x /wait-for-it.sh

# use custom PHP settings
COPY php.ini /usr/local/etc/php/conf.d/roundcube-defaults.ini

COPY docker-entrypoint.sh /

RUN mkdir -p /var/roundcube/config

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
