#!/bin/sh

set -eu

# findText needle haystack
findText () {
    # avoid grep exit code 1 on non match using cat
    NBR="$(echo "${2}" | grep -c -F "${1}" | cat)"
    if [ $NBR -gt 0 ]; then
        echo "[OK] Found \"${1}\" ${NBR} time(s) in the input" > /dev/stdout
        return 0
    fi
    echo "[FAIL] \"${1}\" was not found in the input \"${2}\"" > /dev/stderr
    return 1
}

echo 'Installing packages'

apk add --no-cache --update html2text curl

echo 'Starting tests...'
ROUNDCUBE_URL="${ROUNDCUBE_URL:-"http://roundcubemail/"}"
echo 'Fetching homepage'
HOMEPAGE_TEXT=$(curl -s --fail "${ROUNDCUBE_URL}" | html2text)
echo 'Checking homepage'
findText 'Roundcube' "${HOMEPAGE_TEXT}"
findText 'Roundcube Webmail' "${HOMEPAGE_TEXT}"
findText 'Username [_user               ]' "${HOMEPAGE_TEXT}"
findText 'Password [********************]' "${HOMEPAGE_TEXT}"
findText 'Login' "${HOMEPAGE_TEXT}"
findText 'Warning: This webmail service requires Javascript!' "${HOMEPAGE_TEXT}"
echo 'Homepage is okay'

if test "$SKIP_POST_SETUP_SCRIPT_TEST" != "yes"; then
    echo 'Checking post-setup-script marker'
    POST_SETUP_SCRIPT_TEXT=$(curl -s --fail "${ROUNDCUBE_URL}post_setup_script.txt")
    findText 'yes' "${POST_SETUP_SCRIPT_TEXT}"
    echo 'post-setup-script marker is ok'
fi

echo 'End.'
