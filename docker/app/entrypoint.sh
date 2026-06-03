#!/usr/bin/env sh
set -eu

mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/framework/testing \
    storage/logs \
    bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache

if [ "${RUN_MIGRATIONS_ON_START:-false}" = "true" ]; then
    php artisan migrate --force
    php artisan storage:link --force
fi

exec "$@"

