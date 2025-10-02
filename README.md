
[![Build & Test](https://github.com/roundcube/roundcubemail-docker/actions/workflows/test.yml/badge.svg)](https://github.com/roundcube/roundcubemail-docker/actions/workflows/test.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/roundcube/roundcubemail.svg)](https://hub.docker.com/r/roundcube/roundcubemail/)

# Running Roundcube in a Docker Container

The simplest method is to run the official image:

```sh
docker run -e ROUNDCUBEMAIL_DEFAULT_HOST=mail -e ROUNDCUBEMAIL_SMTP_SERVER=mail -p 8000:80 -d roundcube/roundcubemail
```

where `mail` should be replaced by your host name for the IMAP and SMTP server.

## Tags and Variants

Roundcube comes in three different variants (`apache`, `fpm` and `fpm-alpine`) which are all built on top of official `php` images of the same variants.

The `latest-*` tags always contain the **latest stable** version of Roundcube Webmail with the latest version of the `php` base images available. For recent major versions of Roundcube we have tags like `1.3.x`. Those are continuously updated with versions of the according release series and updates to the base images.

We also publish full version tags (e.g. `1.3.10`) but these just represent the version and base image at the time of the release. These tags do not receive any updates.

## Configuration/Environment Variables

The following env variables can be set to configure your Roundcube Docker instance:

`ROUNDCUBEMAIL_DEFAULT_HOST` - Hostname of the IMAP server to connect to. For encrypted connections, prefix the host with `tls://` (STARTTLS) or `ssl://` (SSL/TLS).

`ROUNDCUBEMAIL_DEFAULT_PORT` - IMAP port number; defaults to `143`

`ROUNDCUBEMAIL_SMTP_SERVER` - Hostname of the SMTP server to send mails. For encrypted connections, prefix the host with `tls://` (STARTTLS) or `ssl://` (SSL/TLS).

`ROUNDCUBEMAIL_SMTP_PORT` - SMTP port number; defaults to `587`

`ROUNDCUBEMAIL_USERNAME_DOMAIN` - Automatically add this domain to user names for login. See [defaults.inc.php](https://github.com/roundcube/roundcubemail/blob/master/config/defaults.inc.php) for more information.

`ROUNDCUBEMAIL_REQUEST_PATH` - Specify request path with reverse proxy; defaults to `/`. See [defaults.inc.php](https://github.com/roundcube/roundcubemail/blob/master/config/defaults.inc.php) for possible values.

`ROUNDCUBEMAIL_PLUGINS` - List of built-in plugins to activate. Defaults to `archive,zipdownload`

`ROUNDCUBEMAIL_COMPOSER_PLUGINS` - The list of composer packages to install on startup. Use `ROUNDCUBEMAIL_PLUGINS` to enable them.

`ROUNDCUBEMAIL_SKIN` - Configures the default theme. Defaults to `elastic`

`ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE` - File upload size limit; defaults to `5M`. (*Note: this variable does not work in the `nonroot`-image!*)

`ROUNDCUBEMAIL_SPELLCHECK_URI` - Fully qualified URL to a Google XML spell check API like [google-spell-pspell](https://github.com/roundcube/google-spell-pspell)

`ROUNDCUBEMAIL_ASPELL_DICTS` - List of aspell dictionaries to install for spell checking (comma-separated, e.g. `de,fr,pl`). (*Note: this variable does not work in the `nonroot`-image!*)

By default, the image will use a local SQLite database for storing user account metadata.
It'll be created inside the container directory `/var/roundcube/db`. In order to persist the database, a volume
mount should be added to this path.
(For production environments, please assess individually if SQLite is the right database choice.)

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

```sh
docker run --link=mysql:mysql -d roundcube/roundcubemail
```

## Nonroot image

We provide `nonroot`-images that run all processes as a normal user instead of as root. This limits possible damage in case of a mis-configuration or breach.

Not running any process as root disables a few features that require to install packages or write to system files on container start. Specifically you cannot use the environment variables `ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE` and `ROUNDCUBEMAIL_ASPELL_DICTS`.

* To specify a maximum upload filesize, write the required php configuration options into a file and bind-mount that to `/usr/local/etc/php/conf.d/$filename`. See `examples/docker-compose-nonroot.yaml` and `examples/nonroot-custom-php-config.ini` for an example.
* To install additionall aspell dictionaries you will have to build your own container image on top of ours and install them during the build.

## Persistent data

The Roundcube containers do not store any data persistently by default. There are, however,
some directories that could be mounted as volume or bind mount to share data between containers
or to inject additional data into the container:

* `/var/www/html`: Roundcube installation directory
  This is the document root of Roundcube. Plugins and additional skins are stored here amongst the Roundcube sources.
  Share this directory when using the FPM variant and let a webserver container serve the static files from here.

* `/var/roundcube/config`: Location for additional config files
  See the [Advanced configuration](#advanced-configuration) section for details.

* `/var/roundcube/db`: storage location of the SQLite database
  Only needed if using `ROUNDCUBEMAIL_DB_TYPE=sqlite` to persist the Roundcube database.

* `/var/roundcube/enigma`: storage location of the enigma plugin
  If enabled, the "enigma" plugin stores OpenPGP keys here.

* `/tmp/roundcube-temp`: Roundcube's temp folder
  Temp files like uploaded attachments or thumbnail images are stored here.
  Share this directory via a volume when running multiple replicas of the roundcube container.

## Docker Secrets

When running the Roundcube container in a Docker Swarm, you can use [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
to share credentials across all instances. The following secrets are currently supported by Roundcube:

* `roundcube_des_key`: Unique and random key for encryption purposes
* `roundcube_db_user`: Database connection username (mappend to `ROUNDCUBEMAIL_DB_USER`)
* `roundcube_db_password`: Database connection password (mappend to `ROUNDCUBEMAIL_DB_PASSWORD`)
* `roundcube_oauth_client_secret`: OAuth client secret (mappend to `ROUNDCUBEMAIL_OAUTH_CLIENT_SECRET`)

## Advanced configuration

Apart from the above described environment variables, the Docker image also allows to add custom config files
which are merged into Roundcube's default config. Therefore the image defines the path `/var/roundcube/config`
where additional config files (`*.php`) are searched and included. Mount a local directory with your config
files - check for valid PHP syntax - when starting the Docker container:

```sh
docker run -v ./config/:/var/roundcube/config/ -d roundcube/roundcubemail
```

Check the Roundcube Webmail wiki for a reference of [Roundcube config options](https://github.com/roundcube/roundcubemail/wiki/Configuration).

Customized PHP settings can be implemented by mounting a configuration file to `/usr/local/etc/php/conf.d/zzz_roundcube-custom.ini`.
For example, it may be used to increase the PHP memory limit (`memory_limit=128M`).

## Installing Roundcube Plugins

With the latest updates, the Roundcube image is now able to install plugins.
You need to fill `ROUNDCUBEMAIL_COMPOSER_PLUGINS` with the list of composer packages to install.
And set them in `ROUNDCUBEMAIL_PLUGINS` in order to enable the installed plugins.

For example:

```yaml
  ROUNDCUBEMAIL_COMPOSER_PLUGINS: "weird-birds/thunderbird_labels,jfcherng-roundcube/show-folder-size,germancoding/tls_icon:^1.2"
  ROUNDCUBEMAIL_PLUGINS: thunderbird_labels, show_folder_size, tls_icon
```

To overwrite the default config of a plugin you might need to use a post-setup script (see below) that moves a custom config file into the plugin's directory.

## Pre-setup and post-setup tasks

In order to execute custom tasks before or after Roundcubemail is set up in the container, you can bind-mount directories to `/entrypoint-tasks/pre-setup/` and `/entrypoint-tasks/post-setup/`. Then all executable files in those directories are executed at the beginning or the end of the actual entrypoint-script, respectively. If an executable exits with a code > 1, the entrypoint script exits, too.

Each executable receives the container's `CMD` as arguments.

They are executed in alphabetical order (the way `bash` understands it in `en_US` locale).

If the Roundcubemail-setup is skipped due to a custom `CMD`, these tasks are skipped as well.


## HTTPS

Currently all images are configured to speak HTTP. To provide HTTPS please run an additional reverse proxy in front of them, which handles certificates and terminates TLS. Alternatively you could derive from our images (or use the advanced configuration methods) to make Apache or nginx provide HTTPS – but please refrain from opening issues asking for support with such a setup.


## Examples

A few example setups using `docker-compose` can be found in our [Github repository](https://github.com/roundcube/roundcubemail-docker/tree/master/examples).

## Building a Docker image

Use the `Dockerfile` in this repository to build your own Docker image.
It pulls the latest build of Roundcube Webmail from the Github download page and builds it on top of a `php:7.4-apache` Docker image.

Build it from one of the variants directories with

```sh
docker build -t roundcubemail .
```

You can also create your own Docker image by extending from this image.

For instance, you could extend this image to add composer and install requirements for special plugins:

```Dockerfile
FROM roundcube/roundcubemail:latest

# COMPOSER_ALLOW_SUPERUSER is needed to run plugins when using a container
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
    ; \
```

# License

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

For more details about licensing and the exceptions for skins and plugins
see [roundcube.net/license][license].
