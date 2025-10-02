#!/usr/bin/env bash

set -e

# Check that the file, which a pre-setup-script should have created, is present.
test -f /tmp/something

# Leave a marker that can be checked from the outside.
echo yes > public_html/post_setup_script.txt
