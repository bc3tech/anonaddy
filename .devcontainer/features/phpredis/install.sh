#!/usr/bin/env bash
set -euo pipefail

php_bin='/usr/local/php/current/bin/php'
pecl_bin='/usr/local/php/current/bin/pecl'

test -x "${php_bin}"
test -x "${pecl_bin}"

if "${php_bin}" -m | grep -qx redis; then
  exit 0
fi

apt-get update
apt-get install -y --no-install-recommends autoconf build-essential pkg-config
"${pecl_bin}" install redis

php_ini_dir="$("${php_bin}" --ini | awk -F ': ' '/^Scan for additional .ini files in:/ { print $2 }')"
test -n "${php_ini_dir}"
printf '%s\n' 'extension=redis' > "${php_ini_dir}/redis.ini"

apt-get purge -y --auto-remove autoconf build-essential pkg-config
rm -rf /var/lib/apt/lists/*
