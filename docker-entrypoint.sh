#!/bin/bash
# set -ex

# PWD=`pwd`

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
  if ! [ -e index.php -a -e bin/installto.sh ]; then
    echo >&2 "roundcubemail not found in $PWD - copying now..."
    if [ "$(ls -A)" ]; then
      echo >&2 "WARNING: $PWD is not empty - press Ctrl+C now if this is an error!"
      ( set -x; ls -A; sleep 10 )
    fi
    tar cf - --one-file-system -C /usr/src/roundcubemail . | tar xf -
    echo >&2 "Complete! ROUNDCUBEMAIL has been successfully copied to $PWD"
  fi

  if [ -f /run/secrets/roundcube_db_user ]; then
    ROUNDCUBEMAIL_DB_USER=`cat /run/secrets/roundcube_db_user`
  fi
  if [ -f /run/secrets/roundcube_db_password ]; then
    ROUNDCUBEMAIL_DB_PASSWORD=`cat /run/secrets/roundcube_db_password`
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
  : "${ROUNDCUBEMAIL_SKIN:=larry}"
  : "${ROUNDCUBEMAIL_TEMP_DIR:=/tmp/roundcube-temp}"

  if [ ! -e config/config.inc.php ]; then
    ROUNDCUBEMAIL_PLUGINS_PHP=`echo "${ROUNDCUBEMAIL_PLUGINS}" | sed -E "s/[, ]+/', '/g"`
    ROUNDCUBEMAIL_DES_KEY=`test -f /run/secrets/roundcube_des_key && cat /run/secrets/roundcube_des_key || head /dev/urandom | base64 | head -c 24`
    touch config/config.inc.php

    echo "Write config to $PWD/config/config.inc.php"
    echo "<?php
    \$config['db_dsnw'] = '${ROUNDCUBEMAIL_DSNW}';
    \$config['db_dsnr'] = '${ROUNDCUBEMAIL_DSNR}';
    \$config['default_host'] = '${ROUNDCUBEMAIL_DEFAULT_HOST}';
    \$config['default_port'] = '${ROUNDCUBEMAIL_DEFAULT_PORT}';
    \$config['smtp_server'] = '${ROUNDCUBEMAIL_SMTP_SERVER}';
    \$config['smtp_port'] = '${ROUNDCUBEMAIL_SMTP_PORT}';
    \$config['des_key'] = '${ROUNDCUBEMAIL_DES_KEY}';
    \$config['temp_dir'] = '${ROUNDCUBEMAIL_TEMP_DIR}';
    \$config['plugins'] = ['${ROUNDCUBEMAIL_PLUGINS_PHP}'];
    \$config['zipdownload_selection'] = true;
    \$config['log_driver'] = 'stdout';
    \$config['skin'] = '${ROUNDCUBEMAIL_SKIN}';
    " > config/config.inc.php

    for fn in `ls /var/roundcube/config/*.php 2>/dev/null || true`; do
      echo "include('$fn');" >> config/config.inc.php
    done

    # initialize DB if not SQLite
    echo "${ROUNDCUBEMAIL_DSNW}" | grep -q 'sqlite:' || bin/initdb.sh --dir=$PWD/SQL || bin/updatedb.sh --dir=$PWD/SQL --package=roundcube || echo "Failed to initialize databse. Please run $PWD/bin/initdb.sh manually."
  else
    echo "WARNING: $PWD/config/config.inc.php already exists."
    echo "ROUNDCUBEMAIL_* environment variables have been ignored."
  fi

  if [ ! -z "${ROUNDCUBEMAIL_TEMP_DIR}" ]; then
    mkdir -p ${ROUNDCUBEMAIL_TEMP_DIR} && chown www-data ${ROUNDCUBEMAIL_TEMP_DIR}
  fi

  if [ ! -z "${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" ]; then
    echo "upload_max_filesize=${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" >> /usr/local/etc/php/conf.d/roundcube-override.ini
    echo "post_max_size=${ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE}" >> /usr/local/etc/php/conf.d/roundcube-override.ini
  fi
fi

exec "$@"
