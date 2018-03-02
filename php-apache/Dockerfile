FROM php:7.1-apache
LABEL maintainer="Thomas Bruederli <thomas@roundcube.net>"

RUN set -ex; \
	apt-get update; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get install -y --no-install-recommends \
		libicu-dev \
		libjpeg62-turbo-dev \
		libldap2-dev \
		libpng-dev \
		libpq-dev \
		libsqlite3-dev \
		zlib1g-dev \
	; \
	\
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
	docker-php-ext-install \
		exif \
		gd \
		intl \
		ldap \
		pdo \
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
VOLUME /tmp/roundcube-temp

# Define Roundcubemail version
ENV ROUNDCUBEMAIL_VERSION 1.3.4

# Download package and extract to web volume
RUN set -ex; \
	curl -o roundcubemail.tar.gz -SL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz; \
	curl -o roundcubemail.tar.gz.asc -SL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz.asc; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F3E4C04BB3DB5D4215C45F7F5AB2BAA141C4F7D5; \
	gpg --batch --verify roundcubemail.tar.gz.asc roundcubemail.tar.gz; \
	rm -r "$GNUPGHOME" roundcubemail.tar.gz.asc; \
	tar -xzf roundcubemail.tar.gz -C /usr/src/; \
# upstream tarballs include ./roundcubemail-${ROUNDCUBEMAIL_VERSION}/ so this gives us /usr/src/roundcubemail-${ROUNDCUBEMAIL_VERSION}
	mv /usr/src/roundcubemail-${ROUNDCUBEMAIL_VERSION} /usr/src/roundcubemail; \
	rm -rf /usr/src/roundcubemail/installer; \
	rm roundcubemail.tar.gz

# include the wait-for-it.sh script
RUN curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /wait-for-it.sh && chmod +x /wait-for-it.sh

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

