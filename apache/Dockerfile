FROM php:8.4-apache AS root

# Define Roundcubemail version
# Use an ARG to make it overwritable from a build argument and not leak into the container runtime
# environment.
ARG ROUNDCUBEMAIL_VERSION=1.7.5

# Define the GPG key used for the bundle verification process
ARG ROUNDCUBEMAIL_KEYID="F3E4 C04B B3DB 5D42 15C4  5F7F 5AB2 BAA1 41C4 F7D5"

# PHP extensions that are not bundled with PHP, built from their release source tarballs.
# Versions and checksums are maintained by update.sh.
ARG PHP_EXT_IMAGICK_VERSION=3.8.1
ARG PHP_EXT_IMAGICK_SHA256=b0e9279ddf6e75a8c6b4068e16daec0475427dbca7ce2e144e30a51a88aa5ddc
ARG PHP_EXT_REDIS_VERSION=6.3.0
ARG PHP_EXT_REDIS_SHA256=cb8f81df1a275599e4f8ddcfec7e1f65ed1953e6f5673649149fd680ebff4cad
ARG PHP_EXT_PSPELL_VERSION=1.0.1
ARG PHP_EXT_PSPELL_SHA256=c98cbfe35039ff2daa51370a4a1515258435d22b73a22cb3f45ed741dd45662a

LABEL maintainer="Thomas Bruederli <thomas@roundcube.net>"
LABEL org.opencontainers.image.source="https://github.com/roundcube/roundcubemail-docker"
LABEL org.opencontainers.image.version="${ROUNDCUBEMAIL_VERSION}"

# This should be done by the upstream images, but as long as they don't do it,
# we rather use our own hands than suffer from outdated packages.
# Kept as standalone command to make it stand out and be easy to remove.
RUN apt-get update && apt-get -y upgrade && apt-get clean

RUN set -ex; \
	if [ "apache" = "apache" ]; then \
		a2enmod rewrite; \
		# Make Apache use public_html/ as document root to protect files outside of it \
		# against unauthorized access. \
		# This is possible and recommended since a while, and will be required for Roundcubemail v1.7. \
		sed -i -e 's|\(DocumentRoot /var/www/html\)$|\1/public_html|' /etc/apache2/sites-available/000-default.conf; \
	fi; \
	apt-get update; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libicu-dev \
		libjpeg62-turbo-dev \
		libldap2-dev \
		libsasl2-dev \
		libmagickwand-dev \
		libpng-dev \
		libpq-dev \
		libsqlite3-dev \
		libzip-dev \
		libpspell-dev \
		libonig-dev \
		libldap-common \
	; \
# installto.sh & web install dependencies
	fetchDeps="gnupg locales libc-l10n"; \
	installDeps="aspell aspell-en rsync unzip"; \
	apt-get install -y --no-install-recommends \
			$installDeps \
			$fetchDeps \
	; \
	\
# Download and verify the sources of the non-bundled extensions into the PHP source tree,
# so docker-php-ext-install can build them like the bundled ones.
# Using curl and docker-php-ext-install instead of PIE, since PIE would be an additional tool, and doesn't
# (yet?) provide pspell, and requires additional build tools for imagick.
	fetchAndExtractPHPExtension() { \
		extName="$1"; \
		extUrl="$2"; \
		extShasum="$3"; \
		curl -fsSL "$extUrl" -o "/tmp/$extName.tar.gz"; \
		echo "$extShasum  /tmp/$extName.tar.gz" | sha256sum -c -; \
		mkdir -p "/usr/src/php/ext/$extName"; \
		tar -xzf "/tmp/$extName.tar.gz" -C "/usr/src/php/ext/$extName" --strip-components=1; \
		rm "/tmp/$extName.tar.gz"; \
	}; \
	docker-php-source extract; \
	fetchAndExtractPHPExtension imagick "https://github.com/Imagick/imagick/archive/refs/tags/${PHP_EXT_IMAGICK_VERSION}.tar.gz" "$PHP_EXT_IMAGICK_SHA256"; \
# imagick's git sources contain a version placeholder that is normally filled in by its release packaging.
	sed -i -e "s/@PACKAGE_VERSION@/${PHP_EXT_IMAGICK_VERSION}/" /usr/src/php/ext/imagick/php_imagick.h; \
	fetchAndExtractPHPExtension redis "https://github.com/phpredis/phpredis/archive/refs/tags/${PHP_EXT_REDIS_VERSION}.tar.gz" "$PHP_EXT_REDIS_SHA256"; \
	fetchAndExtractPHPExtension pspell "https://github.com/php/pecl-text-pspell/archive/refs/tags/${PHP_EXT_PSPELL_VERSION}.tar.gz" "$PHP_EXT_PSPELL_SHA256"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd --with-jpeg --with-freetype; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch" --with-ldap-sasl; \
	docker-php-ext-install \
		exif \
		gd \
		intl \
		ldap \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		zip \
		pspell \
		imagick \
		redis \
	; \
	docker-php-ext-enable imagick opcache redis; \
	docker-php-source delete; \
# Display installed modules
	php -m; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark $installDeps $fetchDeps; \
	extdir="$(php -r 'echo ini_get("extension_dir");')"; \
	ldd "$extdir"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	ldd "$extdir"/*.so | grep -qzv "=> not found" || (echo "Sanity check failed: missing libraries:"; ldd "$extdir"/*.so | grep " => not found"; exit 1); \
	ldd "$extdir"/*.so | grep -q "libzip.so.* => .*/libzip.so.*" || (echo "Sanity check failed: libzip.so is not referenced"; ldd "$extdir"/*.so; exit 1); \
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ] || (echo "Sanity check failed: php returned errors; $err"; exit 1;); \
# include the wait-for-it.sh script (latest commit)
	curl -fL https://raw.githubusercontent.com/vishnubob/wait-for-it/81b1373f17855a4dc21156cfe1694c31d7d1792e/wait-for-it.sh -o /wait-for-it.sh; \
	chmod +x /wait-for-it.sh;

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# use custom PHP settings
COPY php.ini /usr/local/etc/php/conf.d/roundcube-defaults.ini

COPY --chmod=0755 docker-entrypoint.sh /

# Download package and extract to web volume
RUN set -ex; \
	curl -o roundcubemail.tar.gz -fSL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz; \
	curl -o roundcubemail.tar.gz.asc -fSL https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBEMAIL_VERSION}/roundcubemail-${ROUNDCUBEMAIL_VERSION}-complete.tar.gz.asc; \
	export GNUPGHOME="$(mktemp -d)"; \
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
# Create the config dir
	mkdir -p /var/roundcube/config /var/roundcube/enigma; \
	chown -R www-data:www-data /var/roundcube; \
	chmod +t /var/roundcube

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]


#### non-root stage

FROM root AS nonroot

# Prepare locale config for locale-gen
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
	/usr/sbin/locale-gen

RUN sed -i 's/^Listen 80$/Listen 8000/' /etc/apache2/ports.conf
RUN sed -i /etc/apache2/sites-enabled/000-default.conf -e 's/:80>/:8000>/'

EXPOSE 8000

USER 33:33
