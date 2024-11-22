FROM dunglas/frankenphp:1.3.1-php8.2-bookworm

WORKDIR /app

RUN set -ex; \
    	apt-get update; \
    	\
    	savedAptMark="$(apt-mark showmanual)"; \
         \
# installto.sh & web install dependencies
	fetchDeps="gnupg locales libc-l10n"; \
	installDeps="aspell aspell-en rsync unzip"; \
	apt-get install -y --no-install-recommends \
			$installDeps \
			$fetchDeps; \
	\
    install-php-extensions \
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
        opcache \
        @composer \
    ; \
# Header files ".h"
	rm -r /usr/local/include/php/ext; \
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

# use custom PHP settings
COPY php.ini $PHP_INI_DIR/conf.d/roundcube-defaults.ini

# Configure PHP for production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY Caddyfile /etc/caddy/Caddyfile

COPY --chmod=0755 entrypoint.sh /

# Define Roundcubemail version
ENV ROUNDCUBEMAIL_VERSION 1.6.9

# Define the GPG key used for the bundle verification process
ENV ROUNDCUBEMAIL_KEYID "F3E4 C04B B3DB 5D42 15C4  5F7F 5AB2 BAA1 41C4 F7D5"

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
#	chown -R www-data:www-data /usr/src/roundcubemail/logs; \ WIP: is necessary a non root user?
# Create the config dir
	mkdir -p /var/roundcube/config

ENTRYPOINT ["/entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
