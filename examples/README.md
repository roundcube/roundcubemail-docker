# Roundcube Docker Examples

This folder contains a few `docker-compose` files to spin up a Roundcube webmail webserver using the three different variants of images we provide.

## Simple Roundcube with Apache and SQLite DB

See [docker-compose-simple.yaml](./docker-compose-simple.yaml).

Directly serves Roundcube webmail via HTTP.
The Roundcube sources and the database file are stored on connected volumes.

## Standalone Roundcube with Apache using a MySQL DB

See [docker-compose-mysql.yaml](./docker-compose-mysql.yaml).

Directly serves Roundcube webmail via HTTP and connects to a MySQL database container.
The Roundcube sources and the database files are stored on connected volumes.

## Roundcube served from PHP-FPM via Nginx using a Postrgres DB

See [docker-compose-fpm.yaml](./docker-compose-fpm.yaml) or [docker-compose-fpm-alpine.yaml](./docker-compose-fpm-alpine.yaml).

An Nginx webserver serves Roundcube from a PHP-FPM container via CGI and static files from the shared Roundcube sources.
A Posrgres database container is used to store Roundcube's session and user data.
The Roundcube sources and the database files are stored on connected volumes.

## Installing Roundcube Plugins

With the latest updates, the Roundcube images contain the [Composer](https://getcomposer.org) binary
which is used to install plugins. You can add and activate plugins by executing `composer.phar require <package-name>` 
inside a running Roundcube container:

```
$ docker exec -it roundcubemail composer.phar require johndoh/contextmenu --update-no-dev
```

If you have mounted the container's volume `/var/www/html` the plugins installed persist on your host system. Otherwise they need to be (re-)installed every time you update or restart the Roundcube container.

## Kubernetes Cluster

The sample [kubernetes.yaml](./kubernetes.yaml) file configures a Roundcube installation on a Kubernetes cluster with three individual deployments and services which can be scaled individually:

* roundcubedb: Postgres database
* roundcubemail: PHP-FPM with Roundcube
* roundcubenginx: Nginx service serving HTTP

The setup defines three PersistentVolumeClaims for database and shared temp file storage as well as for sharing the static file of Roundcube with the Nginx pods which finally serve them via HTTP.

This is only an example and needs to be modified and tweaked for productive systems. At least set the `ROUNDCUBEMAIL_DEFAULT_HOST` and `ROUNDCUBEMAIL_SMTP_SERVER` and change the values of the `roundcubemail-shared-secret` Secret.
