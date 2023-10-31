FROM php:8.1-fpm-alpine

# opencontainers annotations https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.authors="Alexis Saettler <alexis@saettler.org>" \
      org.opencontainers.image.title="MonicaHQ, the Personal Relationship Manager" \
      org.opencontainers.image.description="This is MonicaHQ, your personal memory! MonicaHQ is like a CRM but for the friends, family, and acquaintances around you." \
      org.opencontainers.image.url="https://monicahq.com" \
      org.opencontainers.image.source="https://github.com/monicahq/docker" \
      org.opencontainers.image.vendor="Monica"

# entrypoint.sh dependencies
RUN set -ex; \
    \
    apk add --no-cache \
        bash \
        coreutils

# Install required PHP extensions
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        icu-dev \
        zlib-dev \
        libzip-dev \
        libxml2-dev \
        freetype-dev \
        libpng-dev \
        libpq-dev \
        libjpeg-turbo-dev \
        jpeg-dev \
        gmp-dev \
        libmemcached-dev \
        libwebp-dev \
    ; \
    \
    docker-php-ext-configure intl; \
    docker-php-ext-configure gd --with-jpeg --with-freetype --with-webp; \
    docker-php-ext-configure gmp; \
    docker-php-ext-install -j "$(nproc)" \
        intl \
        zip \
        bcmath \
        gd \
        gmp \
        pdo_mysql \
        mysqli \
        pdo_pgsql \
        soap \
    ; \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install APCu-5.1.22; \
    pecl install memcached-3.2.0; \
    pecl install redis-6.0.2; \
    \
    docker-php-ext-enable \
        apcu \
        memcached \
        redis \
    ; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
        | tr ',' '\n' \
        | sort -u \
        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
        )"; \
    apk add --no-network --virtual .monica-phpext-rundeps $runDeps; \
    apk del --no-network .build-deps

# Set crontab for schedules
RUN set -ex; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    rm -f /var/spool/cron/crontabs/root; \
    echo '* * * * * php /var/www/html/artisan schedule:run -v' > /var/spool/cron/crontabs/www-data

# Opcache
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="20000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"
# Limits
ENV PHP_MEMORY_LIMIT="512M" \
    PHP_UPLOAD_LIMIT="512M"
RUN set -ex; \
    \
    docker-php-ext-enable opcache; \
    { \
        echo '[opcache]'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}'; \
        echo 'opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCELERATED_FILES}'; \
        echo 'opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}'; \
        echo 'opcache.max_wasted_percentage=${PHP_OPCACHE_MAX_WASTED_PERCENTAGE}'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini; \
    \
    { \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
    } > $PHP_INI_DIR/conf.d/limits.ini;



WORKDIR /var/www/html

# Define Monica version
ENV MONICA_VERSION v4.0.0
LABEL org.opencontainers.image.revision="e1a3e1315b1a92a5ff0ccab6c22ba9ded77a599e" \
      org.opencontainers.image.version="v4.0.0"

RUN set -ex; \
    apk add --no-cache --virtual .fetch-deps \
        bzip2 \
        gnupg \
    ; \
    \
    for ext in tar.bz2 tar.bz2.asc; do \
        curl -fsSL -o monica-${MONICA_VERSION}.$ext "https://github.com/monicahq/monica/releases/download/${MONICA_VERSION}/monica-${MONICA_VERSION}.$ext"; \
    done; \
    \
    GPGKEY='BDAB0D0D36A00466A2964E85DE15667131EA6018'; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$GPGKEY"; \
    gpg --batch --verify monica-${MONICA_VERSION}.tar.bz2.asc monica-${MONICA_VERSION}.tar.bz2; \
    \
    tar -xf monica-${MONICA_VERSION}.tar.bz2 -C /var/www/html --strip-components=1; \
    \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" monica-${MONICA_VERSION}.tar.bz2 monica-${MONICA_VERSION}.tar.bz2.asc; \
    \
    cp /var/www/html/.env.example /var/www/html/.env; \
    chown -R www-data:www-data /var/www/html; \
    \
    apk del .fetch-deps

COPY entrypoint.sh \
    queue.sh \
    cron.sh \
    /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
