FROM php:7.3-apache

# opencontainers annotations https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL maintainer="Alexis Saettler <alexis@saettler.org> (@asbiin)" \
	  org.opencontainers.image.authors="Alexis Saettler <alexis@saettler.org>" \
      org.opencontainers.image.title="MonicaHQ, the Personal Relationship Manager" \
      org.opencontainers.image.description="This is MonicaHQ, your personal memory! MonicaHQ is like a CRM but for the friends, family, and acquaintances around you." \
      org.opencontainers.image.url="https://monicahq.com" \
	  org.opencontainers.image.revision="e3c79ada95ba6b34281628ee044a7bf0e9920f26" \
      org.opencontainers.image.source="https://github.com/monicahq/docker" \
      org.opencontainers.image.vendor="Monica" \
      org.opencontainers.image.version="v2.16.0"

# entrypoint.sh dependencies
RUN set -ex; \
    \
    apt-get update; \
    apt-get -y autoremove; \
    apt-get install -y --no-install-recommends \
        rsync \
        bash \
        busybox-static \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install required PHP extensions
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libicu-dev \
        zlib1g-dev \
        libzip-dev \
        libpng-dev \
        libxml2-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libgmp-dev \
        libsodium-dev \
        libmemcached-dev \
    ; \
    \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    if [ ! -e /usr/include/gmp.h ]; then ln -s /usr/include/$debMultiarch/gmp.h /usr/include/gmp.h; fi;\
    docker-php-ext-configure intl; \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/; \
    docker-php-ext-configure gmp --with-gmp="/usr/include/$debMultiarch"; \
    docker-php-ext-install -j$(nproc) \
        intl \
        zip \
        json \
        iconv \
        bcmath \
        gd \
        gmp \
        pdo_mysql \
        mysqli \
        soap \
        sodium \
        mbstring \
        opcache \
    ; \
    \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install APCu-5.1.18; \
    pecl install memcached-3.1.5; \
    pecl install redis-5.2.0; \
    \
    docker-php-ext-enable \
        apcu \
        memcached \
        redis \
    ; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
        ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
        \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    \
    if command -v a2enmod; then \
        a2enmod rewrite; \
    fi

# Set crontab for schedules
RUN set -ex; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    echo '*/5 * * * * php /var/www/html/artisan schedule:run -v > /proc/1/fd/1 2> /proc/1/fd/2' > /var/spool/cron/crontabs/www-data

# Opcache
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="20000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"
RUN { \
        echo '[opcache]'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.revalidate_freq=0'; \
        echo "opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}"; \
        echo "opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCELERATED_FILES}"; \
        echo "opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}"; \
        echo "opcache.max_wasted_percentage=${PHP_OPCACHE_MAX_WASTED_PERCENTAGE}"; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini; \
    \
    echo 'memory_limit=512M' > $PHP_INI_DIR/conf.d/memory-limit.ini

# Sentry
RUN if [ $(uname -m) = "x86_64" ]; then \
        PLATFORM=$(uname -s); \
        if [ "$PLATFORM" = "Linux" -o "$PLATFORM" = "Windows" -o "$PLATFORM" = "Darwin" ]; then \
            mkdir -p /root/.local/bin; \
            curl -sL https://sentry.io/get-cli/ | INSTALL_DIR=/root/.local/bin bash; \
        fi \
    fi

VOLUME /var/www/html

# Define Monica version and expected SHA512 signature
ENV MONICA_VERSION v2.16.0
ENV MONICA_SHA512 f2d1a434b5615bcd100388066854dfd36c81f403e817f45a21d4c04ec9ee022339c25334913586a51e763928d17d8b3fa79b6bf1883cac6fffe1aabfbd14ae3c
ENV MONICA_SRC /usr/src/monica

ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN set -eu; sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf; \
	sed -ri -e "s!/var/www/!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

RUN set -eu; \
    curl -fsSL -o monica.tar.bz2 "https://github.com/monicahq/monica/releases/download/${MONICA_VERSION}/monica-${MONICA_VERSION}.tar.bz2"; \
    echo "$MONICA_SHA512 *monica.tar.bz2" | sha512sum -c -; \
    \
    mkdir $MONICA_SRC; \
    tar -xf monica.tar.bz2 -C $MONICA_SRC --strip-components=1; \
    rm monica.tar.bz2; \
    \
    cp $MONICA_SRC/.env.example $MONICA_SRC/.env; \
    chown -R www-data:www-data $MONICA_SRC

COPY upgrade.exclude \
    /usr/local/share/
COPY entrypoint.sh \
    queue.sh \
    cron.sh \
    /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
