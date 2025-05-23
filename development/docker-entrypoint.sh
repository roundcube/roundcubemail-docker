#!/bin/bash -ex

if [[ ! -f index.php ]]; then
    echo "Error: No source code in /var/www/html – you must mount your code base to that path!"
    exit 1
fi

if  [[ "$1" != apache2* && "$1" != php-fpm && "$1" != bin* ]]; then
    exec $@
fi

# Ensure two very essential requirements are set in the config file.
if ! grep -q "log_driver.*stdout" config/config.inc.php; then
    echo "\$config['log_driver'] = 'stdout';" >> config/config.inc.php
fi
if ! grep -q "db_dsnw" config/config.inc.php; then
    echo "\$config['db_dsnw'] = 'sqlite:////var/roundcube/sqlite.db?mode=0644';" >> config/config.inc.php
fi

# Run the steps necessary to actually use the repository code.

# Install dependencies
if [[ ! -f composer.json ]]; then
    # For older versions of Roundcubemail.
    cp -v composer.json-dist composer.json
fi
composer --prefer-dist --no-interaction --optimize-autoloader install

# Download external Javascript dependencies.
bin/install-jsdeps.sh

# Translate elastic's styles to CSS.
if grep -q css-elastic Makefile; then
    make css-elastic
else
    # Older versions
    (
    	npm install less && \
    	npm install less-plugin-clean-css && \
        cd skins/elastic && \
		npx lessc --clean-css="--s1 --advanced" styles/styles.less > styles/styles.min.css && \
		npx lessc --clean-css="--s1 --advanced" styles/print.less > styles/print.min.css && \
		npx lessc --clean-css="--s1 --advanced" styles/embed.less > styles/embed.min.css \
	)
fi

# Update cache-buster parameters in CSS-URLs.
bin/updatecss.sh

# Initialize or update the database.
sudo -u www-data bin/initdb.sh --dir=$PWD/SQL --update || echo "Failed to initialize/update the database. Please start with an empty database and restart the container."

exec apache2-foreground
