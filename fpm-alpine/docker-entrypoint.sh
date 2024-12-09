#!/bin/bash
# set -ex

# PWD=`pwd`

if  [[ "$1" == apache2* || "$1" == php-fpm || "$1" == bin* ]]; then
  INSTALLDIR=`pwd`
  # docroot is empty
  if ! [ -e index.php -a -e bin/installto.sh ]; then
    echo >&2 "roundcubemail not found in $PWD - copying now..."
    if [ "$(ls -A)" ]; then
      echo >&2 "WARNING: $PWD is not empty - press Ctrl+C now if this is an error!"
      ( set -x; ls -A; sleep 10 )
    fi
    tar cf - --one-file-system -C /usr/src/roundcubemail . | tar xf -
    echo >&2 "Complete! ROUNDCUBEMAIL has been successfully copied to $INSTALLDIR"
  # update Roundcube in docroot
  else
    echo >&2 "roundcubemail found in $INSTALLDIR - installing update..."
    (cd /usr/src/roundcubemail && bin/installto.sh -y $INSTALLDIR)
    # Re-install composer modules (including plugins)
    composer \
          --working-dir=${INSTALLDIR} \
          --prefer-dist \
          --no-dev \
          --no-interaction \
          --optimize-autoloader \
          install
  fi

  if [ -f /run/secrets/roundcube_db_user ]; then
    ROUNDCUBEMAIL_DB_USER=`cat /run/secrets/roundcube_db_user`
  fi
  if [ -f /run/secrets/roundcube_db_password ]; then
    ROUNDCUBEMAIL_DB_PASSWORD=`cat /run/secrets/roundcube_db_password`
  fi
  if [ -f /run/secrets/roundcube_oauth_client_secret ]; then
    ROUNDCUBEMAIL_OAUTH_CLIENT_SECRET=`cat /run/secrets/roundcube_oauth_client_secret`
  fi

  if [ ! -z "${!POSTGRES_ENV_POSTGRES_*}" ] || [ "$ROUNDCUBEMAIL_DB_TYPE" == "pgsql" ]; then
    : "${ROUNDCUBEMAIL_DB_TYPE:=pgsql}"
    : "${ROUNDCUBEMAIL_DB_HOST:=postgres}"
    : "${ROUNDCUBEMAIL_DB_PORT:=5432}"
    : "${ROUNDCUBEMAIL_DB_USER:=${POSTGRES_ENV_POSTGRES_USER}}"
    : "${ROUNDCUBEMAIL_DB_PASSWORD:=${POSTGRES_ENV_POSTGRES_PASSWORD}}"
    : "${ROUNDCUBEMAIL_DB_NAME:=${POSTGRES_ENV_POSTGRES_DB:-roundcubemail}}"
    : "${ROUNDCUBEMAIL_DSNW:=${ROUNDCUBEMAIL_DB_TYPE}://${ROUNDCUBEMAIL_DB_USER}:${ROUNDCUBEMAIL_DB_PASSWORD}@${ROUNDCUBEMAIL_DB_HOST}:${ROUNDCUBEMAIL_DB_PORT}/${ROUNDCUBEMAIL_DB_NAME}}"

    /wait-for-it.sh ${ROUNDCUBEMAIL_DB_HOST}:${ROUNDCUBEMAIL_DB_PORT} -t 30
  elif [ ! -z "${!MYSQL_ENV_MYSQL_*}" ] || [ "$ROUNDCUBEMAIL_DB_TYPE" == "mysql" ]; then
    : "${ROUNDCUBEMAIL_DB_TYPE:=mysql}"
    : "${ROUNDCUBEMAIL_DB_HOST:=mysql}"
    : "${ROUNDCUBEMAIL_DB_PORT:=3306}"
    : "${ROUNDCUBEMAIL_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}"
    if [ "$ROUNDCUBEMAIL_DB_USER" = 'root' ]; then
      : "${ROUNDCUBEMAIL_DB_PASSWORD:=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}}"
    else
      : "${ROUNDCUBEMAIL_DB_PASSWORD:=${MYSQL_ENV_MYSQL_PASSWORD}}"
    fi
    : "${ROUNDCUBEMAIL_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-roundcubemail}}"
    : "${ROUNDCUBEMAIL_DSNW:=${ROUNDCUBEMAIL_DB_TYPE}://${ROUNDCUBEMAIL_DB_USER}:${ROUNDCUBEMAIL_DB_PASSWORD}@${ROUNDCUBEMAIL_DB_HOST}:${ROUNDCUBEMAIL_DB_PORT}/${ROUNDCUBEMAIL_DB_NAME}}"

    /wait-for-it.sh ${ROUNDCUBEMAIL_DB_HOST}:${ROUNDCUBEMAIL_DB_PORT} -t 30
  else
    # use local SQLite DB in /var/roundcube/db
    : "${ROUNDCUBEMAIL_DB_TYPE:=sqlite}"
    : "${ROUNDCUBEMAIL_DB_DIR:=/var/roundcube/db}"
    : "${ROUNDCUBEMAIL_DB_NAME:=sqlite}"
    : "${ROUNDCUBEMAIL_DSNW:=${ROUNDCUBEMAIL_DB_TYPE}:///$ROUNDCUBEMAIL_DB_DIR/${ROUNDCUBEMAIL_DB_NAME}.db?mode=0646}"

    mkdir -p $ROUNDCUBEMAIL_DB_DIR
    chown www-data:www-data $ROUNDCUBEMAIL_DB_DIR
  fi

  : "${ROUNDCUBEMAIL_DEFAULT_HOST:=localhost}"
  : "${ROUNDCUBEMAIL_DEFAULT_PORT:=143}"
  : "${ROUNDCUBEMAIL_SMTP_SERVER:=localhost}"
  : "${ROUNDCUBEMAIL_SMTP_PORT:=587}"
  : "${ROUNDCUBEMAIL_PLUGINS:=archive,zipdownload}"
  : "${ROUNDCUBEMAIL_SKIN:=elastic}"
  : "${ROUNDCUBEMAIL_TEMP_DIR:=/tmp/roundcube-temp}"
  : "${ROUNDCUBEMAIL_REQUEST_PATH:=/}"
  : "${ROUNDCUBEMAIL_COMPOSER_PLUGINS_FOLDER:=$INSTALLDIR}"

  if [ ! -z "${ROUNDCUBEMAIL_COMPOSER_PLUGINS}" ]; then
    echo "Installing plugins from the list"
    echo "Plugins: ${ROUNDCUBEMAIL_COMPOSER_PLUGINS}"

    # Change ',' into a space
    ROUNDCUBEMAIL_COMPOSER_PLUGINS_SH=`echo "${ROUNDCUBEMAIL_COMPOSER_PLUGINS}" | tr ',' ' '`

    composer \
      --working-dir=${ROUNDCUBEMAIL_COMPOSER_PLUGINS_FOLDER} \
      --prefer-dist \
      --prefer-stable \
      --update-no-dev \
      --no-interaction \
      --optimize-autoloader \
      require \
      -- \
      ${ROUNDCUBEMAIL_COMPOSER_PLUGINS_SH};
  fi

  if [ ! -d skins/${ROUNDCUBEMAIL_SKIN} ]; then
    # Installing missing skin
    echo "Installing missing skin: ${ROUNDCUBEMAIL_SKIN}"
    composer \
      --working-dir=${INSTALLDIR} \
      --prefer-dist \
      --prefer-stable \
      --update-no-dev \
      --no-interaction \
      --optimize-autoloader \
      require \
      -- \
      roundcube/${ROUNDCUBEMAIL_SKIN};
  fi

  if [ ! -e config/config.inc.php ]; then
    GENERATED_DES_KEY=`head /dev/urandom | base64 | head -c 24`
    touch config/config.inc.php

    echo "Write root config to $PWD/config/config.inc.php"
    echo "<?php
    \$config['plugins'] = [];
    \$config['log_driver'] = 'stdout';
    \$config['zipdownload_selection'] = true;
    \$config['des_key'] = '${GENERATED_DES_KEY}';
    \$config['enable_spellcheck'] = true;
    \$config['spellcheck_engine'] = 'pspell';
    include(__DIR__ . '/config.docker.inc.php');
    " > config/config.inc.php

  elif ! grep -q "config.docker.inc.php" config/config.inc.php; then
    echo "include(__DIR__ . '/config.docker.inc.php');" >> config/config.inc.php
  fi

  ROUNDCUBEMAIL_PLUGINS_PHP=`echo "${ROUNDCUBEMAIL_PLUGINS}" | sed -E "s/[, ]+/', '/g"`
  echo "Write Docker config to $PWD/config/config.docker.inc.php"
  echo "<?php
  \$config['db_dsnw'] = '${ROUNDCUBEMAIL_DSNW}';
  \$config['db_dsnr'] = '${ROUNDCUBEMAIL_DSNR}';
  \$config['imap_host'] = '${ROUNDCUBEMAIL_DEFAULT_HOST}:${ROUNDCUBEMAIL_DEFAULT_PORT}';
  \$config['smtp_host'] = '${ROUNDCUBEMAIL_SMTP_SERVER}:${ROUNDCUBEMAIL_SMTP_PORT}';
  \$config['username_domain'] = '${ROUNDCUBEMAIL_USERNAME_DOMAIN}';
  \$config['temp_dir'] = '${ROUNDCUBEMAIL_TEMP_DIR}';
  \$config['skin'] = '${ROUNDCUBEMAIL_SKIN}';
  \$config['request_path'] = '${ROUNDCUBEMAIL_REQUEST_PATH}';
  \$config['plugins'] = array_filter(array_unique(array_merge(\$config['plugins'], ['${ROUNDCUBEMAIL_PLUGINS_PHP}'])));
  " > config/config.docker.inc.php

  if [ -e /run/secrets/roundcube_des_key ]; then
    echo "\$config['des_key'] = file_get_contents('/run/secrets/roundcube_des_key');" >> config/config.docker.inc.php
  elif [ ! -z "${ROUNDCUBEMAIL_DES_KEY}" ]; then
    echo "\$config['des_key'] = getenv('ROUNDCUBEMAIL_DES_KEY');" >> config/config.docker.inc.php
  fi

  if [ ! -z "${ROUNDCUBEMAIL_OAUTH_CLIENT_SECRET}" ]; then
    echo "\$config['oauth_client_secret'] = '${ROUNDCUBEMAIL_OAUTH_CLIENT_SECRET}';" >> config/config.docker.inc.php
  fi

  if [ ! -z "${ROUNDCUBEMAIL_SPELLCHECK_URI}" ]; then
    echo "\$config['spellcheck_engine'] = 'googie';" >> config/config.docker.inc.php
    echo "\$config['spellcheck_uri'] = '${ROUNDCUBEMAIL_SPELLCHECK_URI}';" >> config/config.docker.inc.php
  fi

  # If the "enigma" plugin is enabled but has no storage configured, inject a default value for the mandatory setting.
  if $(echo $ROUNDCUBEMAIL_PLUGINS | grep -Eq '\benigma\b') && ! grep -qr enigma_pgp_homedir /var/roundcube/config/; then
    echo "\$config['enigma_pgp_homedir'] = '/var/roundcube/enigma';" >> config/config.docker.inc.php
  fi

  # include custom config files
  for fn in `ls /var/roundcube/config/*.php 2>/dev/null || true`; do
    echo "include('$fn');" >> config/config.docker.inc.php
  done

  # initialize or update DB
  bin/initdb.sh --dir=$PWD/SQL --update || echo "Failed to initialize/update the database. Please start with an empty database and restart the container."

  if [ ! -z "${ROUNDCUBEMAIL_TEMP_DIR}" ]; then
    mkdir -p ${ROUNDCUBEMAIL_TEMP_DIR} && chown www-data ${ROUNDCUBEMAIL_TEMP_DIR}
  fi

  if [ ! -z "${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" ]; then
    echo "upload_max_filesize=${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" >> /usr/local/etc/php/conf.d/roundcube-override.ini
    echo "post_max_size=${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" >> /usr/local/etc/php/conf.d/roundcube-override.ini
  fi

  : "${ROUNDCUBEMAIL_LOCALE:=en_US.UTF-8 UTF-8}"

  if [ -e /usr/sbin/locale-gen ] && [ ! -z "${ROUNDCUBEMAIL_LOCALE}" ]; then
    echo "${ROUNDCUBEMAIL_LOCALE}" > /etc/locale.gen
    /usr/sbin/locale-gen
  fi

  if [ ! -z "${ROUNDCUBEMAIL_ASPELL_DICTS}" ]; then
    ASPELL_PACKAGES=`echo -n "aspell-${ROUNDCUBEMAIL_ASPELL_DICTS}" | sed -E "s/[, ]+/ aspell-/g"`
    which apt-get && apt-get install -y $ASPELL_PACKAGES
    which apk && apk add --no-cache $ASPELL_PACKAGES
  fi

fi

exec "$@"
