### Temporary build container to use npm in.
FROM docker.io/roundcube/roundcubemail:latest-apache AS builder

# install nodejs and lessc compiler
RUN apt-get -qq update && apt-get install -y --no-install-recommends npm git

# Download source and build package into src directory
RUN set -ex; \
	rm -rf /usr/src/roundcubemail; \
	curl -o roundcubemail.tar.gz -SL https://github.com/roundcube/roundcubemail/archive/master.tar.gz; \
	tar -xzf roundcubemail.tar.gz -C /usr/src/; \
	rm roundcubemail.tar.gz; \
	mv /usr/src/roundcubemail-master /usr/src/roundcubemail; \
	cd /usr/src/roundcubemail; \
	rm -rf installer tests public_html .ci .github .gitignore .editorconfig .tx .travis.yml; \
	make css-elastic; \
	composer require kolab/net_ldap3 --no-install; \
	composer require bjeavons/zxcvbn-php --no-install; \
	composer install --no-dev --prefer-dist; \
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
FROM docker.io/roundcube/roundcubemail:latest-apache

RUN mkdir -p /usr/src
COPY --from=builder /usr/src/roundcubemail /usr/src/roundcubemail
