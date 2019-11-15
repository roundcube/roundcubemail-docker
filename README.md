
[![Build Status](https://travis-ci.org/roundcube/roundcubemail-docker.svg)](https://travis-ci.org/roundcube/roundcubemail-docker)
[![Docker Pulls](https://img.shields.io/docker/pulls/roundcube/roundcubemail.svg)](https://hub.docker.com/r/roundcube/roundcubemail/)

# Running Roundcube in a Docker Container

The simplest method is to run the official image:

```
docker run -e ROUNDCUBEMAIL_DEFAULT_HOST=mail -e ROUNDCUBEMAIL_SMTP_SERVER=mail -d roundcube/roundcubemail
```

where `mail` should be replaced by your host name for the IMAP and SMTP server.

## Tags and Variants

Roundcube comes in three different variants (`apache`, `fpm` and `fpm-alpine`) which are all built on top of official `php` images of the same variants.

The `latest-*` tags always contain the **latest stable** version of Roundcube Webmail with the latest version of the `php` base images available. For recent major versions of Roundcube we have tags like `1.3.x`. Those are continuously updated with versions of the according release series and updates to the base images.

We also publish full version tags (e.g. `1.3.10`) but these just represent the version and base image at the time of the release. These tags do not receive any updates.

## Configuration/Environment Variables

The following env variables can be set to configure your Roundcube Docker instance:

`ROUNDCUBEMAIL_DEFAULT_HOST` - Hostname of the IMAP server to connect to, use `tls://` prefix for STARTTLS

`ROUNDCUBEMAIL_DEFAULT_PORT` - IMAP port number; defaults to `143`

`ROUNDCUBEMAIL_SMTP_SERVER` - Hostname of the SMTP server to send mails, use `tls://` prefix for STARTTLS

`ROUNDCUBEMAIL_SMTP_PORT`  - SMTP port number; defaults to `587`

`ROUNDCUBEMAIL_PLUGINS` - List of built-in plugins to activate. Defaults to `archive,zipdownload`

`ROUNDCUBEMAIL_SKIN` - Configures the default theme. Defaults to `larry`

`ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE` - File upload size limit; defaults to `5M`

By default, the image will use a local SQLite database for storing user account metadata.
It'll be created inside the `/var/www/html` directory and can be backed up from there. Please note that
this option should not be used for production environments.

### Connect to a Database

The recommended way to run Roundcube is connected to a MySQL database. Specify the following env variables to do so:

`ROUNDCUBEMAIL_DB_TYPE` - Database provider; currently supported: `mysql`, `pgsql`, `sqlite`

`ROUNDCUBEMAIL_DB_HOST` - Host (or Docker instance) name of the database service; defaults to `mysql` or `postgres` depending on linked containers.

`ROUNDCUBEMAIL_DB_PORT` - Port number of the database service; defaults to `3306` or `5432` depending on linked containers.

`ROUNDCUBEMAIL_DB_USER` - The database username for Roundcube; defaults to `root` on `mysql`

`ROUNDCUBEMAIL_DB_PASSWORD` - The password for the database connection

`ROUNDCUBEMAIL_DB_NAME` - The database name for Roundcube to use; defaults to `roundcubemail`

Before starting the container, please make sure that the supplied database exists and the given database user
has privileges to create tables.

Run it with a link to the MySQL host and the username/password variables:

```
docker run --link=mysql:mysql -d roundcube/roundcubemail
```

## Docker Secrets

When running the Roundcube container in a Docker Swarm, you can use [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
to share credentials accross all instances. The following secrets are currently supported by Roundcube:

* `roundcube_des_key`: Unique and random key for encryption purposes
* `roundcube_db_user`: Database connection username (mappend to `ROUNDCUBEMAIL_DB_USER`)
* `roundcube_db_password`: Database connection password (mappend to `ROUNDCUBEMAIL_DB_PASSWORD`)

### Advanced configuration

Apart from the above described environment variables, the Docker image also allows to add custom config files
which are merged into Roundcube's default config. Therefore the image defines a volume `/var/roundcube/config`
where additional config files (`*.php`) are searched and included. Mount a local directory with your config
files - check for valid PHP syntax - when starting the Docker container:

```
docker run -v ./config/:/var/roundcube/config/ -d roundcube/roundcubemail
```

Check the Roundcube Webmail wiki for a reference of [Roundcube config options](https://github.com/roundcube/roundcubemail/wiki/Configuration).

Customized PHP settings can be implemented by mounting a configuration file to `/usr/local/etc/php/conf.d/zzz_roundcube-custom.ini`.
For example, it may be used to increase the PHP memory limit (`memory_limit=128M`).

## Building a Docker image

Use the `Dockerfile` in this repository to build your own Docker image.
It pulls the latest build of Roundcube Webmail from the Github download page and builds it on top of a `php:7.3-apache` Docker image.

Build it from this directory with

```
docker build -t roundcubemail .
```

You can also create your own Docker image by extending from this image.

For instance, you could extend this image to add composer and install requirements for builtin plugins or even external plugins:
```Dockerfile
FROM roundcube/roundcubemail:latest

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
    ; \
    \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer; \
    mv /usr/src/roundcubemail/composer.json-dist /usr/src/roundcubemail/composer.json; \
    \
    composer \
        --working-dir=/usr/src/roundcubemail/ \
        --prefer-dist --prefer-stable \
        --no-update --no-interaction \
        --optimize-autoloader --apcu-autoloader \
        require \
            johndoh/contextmenu \
    ; \
    composer \
        --working-dir=/usr/src/roundcubemail/ \
        --prefer-dist --no-dev \
        --no-interaction \
        --optimize-autoloader --apcu-autoloader \
        update;

```
