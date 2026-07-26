# syntax=docker/dockerfile:1

FROM composer:2 AS composer-bin

FROM php:8.3-cli-alpine AS composer-deps
COPY --from=composer-bin /usr/bin/composer /usr/bin/composer
RUN apk add --no-cache \
    autoconf \
    bash \
    curl \
    freetype-dev \
    g++ \
    gpgme-dev \
    git \
    icu-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    make \
    oniguruma-dev \
    php83-dev \
    redis \
    sqlite-dev \
    unzip \
    zlib-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql zip bcmath \
    && pecl install gnupg mailparse redis \
    && docker-php-ext-enable gnupg mailparse redis
WORKDIR /src
COPY composer.json composer.lock ./
COPY postfix/composer.json postfix/composer.lock ./postfix/
COPY . .
RUN rm -f bootstrap/cache/*.php \
    && CACHE_DRIVER=file composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader
RUN cd postfix && CACHE_DRIVER=file composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader

FROM node:24-alpine AS assets
WORKDIR /src
ARG APP_URL=http://localhost
ENV NPM_CONFIG_REGISTRY=https://packagefeedproxy.microsoft.io/npm/
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
COPY --from=composer-deps /src/vendor /src/vendor
RUN APP_URL="${APP_URL}" npm run production

FROM php:8.3-fpm-alpine AS mail-runtime

RUN apk add --no-cache \
    autoconf \
    bash \
    curl \
    freetype-dev \
    g++ \
    gpgme-dev \
    icu-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    make \
    nginx \
    oniguruma-dev \
    openssl \
    php83-dev \
    postfix \
    postfix-mysql \
    redis \
    sqlite-dev \
    supervisor \
    zlib-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql zip bcmath \
    && pecl install gnupg mailparse redis \
    && docker-php-ext-enable gnupg mailparse redis

WORKDIR /var/www/html

COPY --from=composer-deps /usr/bin/composer /usr/bin/composer
COPY --from=composer-deps /src /var/www/html
COPY --from=assets /src/public/build /var/www/html/public/build

RUN mkdir -p storage/framework/{cache,sessions,views,testing} storage/logs bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache

COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/mail/entrypoint.sh /usr/local/bin/anonaddy-mail-entrypoint

RUN chmod +x /usr/local/bin/anonaddy-mail-entrypoint \
    && cp /etc/postfix/master.cf /etc/postfix/master.cf.dist \
    && mkdir -p /etc/postfix/certs /var/log/mail

EXPOSE 25

CMD ["/usr/local/bin/anonaddy-mail-entrypoint"]

