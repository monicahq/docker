FROM php:7.3-fpm-alpine

LABEL maintainer="Alexis Saettler <alexis@saettler.org> (@asbiin)" \
      org.label-schema.name="MonicaHQ, the Personal Relationship Manager" \
      org.label-schema.description="This is MonicaHQ, your personal memory! MonicaHQ is like a CRM but for the friends, family, and acquaintances around you." \
      org.label-schema.url="https://monicahq.com" \
      org.label-schema.vcs-url="https://github.com/monicahq/monica" \
      org.label-schema.vendor="Monica" \
      org.label-schema.schema-version="1.0"

# entrypoint.sh dependencies
RUN set -ex; \
    \
	apk add --no-cache \
		bash \
		coreutils \
		rsync \
	; \
    rm -rf /var/cache/apk/*

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
        libjpeg-turbo-dev \
        jpeg-dev \
        gmp-dev \
		libsodium-dev \
        libmemcached-dev \
	; \
	\
	docker-php-ext-configure intl; \
	docker-php-ext-configure gd \
		--with-gd \
		--with-freetype-dir=/usr/include/ \
		--with-jpeg-dir=/usr/include/ \
		--with-png-dir=/usr/include/ \
	; \
	docker-php-ext-configure gmp; \
	docker-php-ext-install -j "$(nproc)" \
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
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-5.1.18; \
	pecl install memcached-3.1.5; \
	pecl install redis-5.1.1; \
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
	apk add --virtual .monica-phpext-rundeps $runDeps; \
	apk del .build-deps; \
    rm -rf /var/cache/apk/*

# Set crontab for schedules
RUN set -ex; \
	\
	rm /var/spool/cron/crontabs/root; \
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
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
    \
    echo 'apc.enable_cli=1' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini; \
    \
    echo 'memory_limit=512M' > /usr/local/etc/php/conf.d/memory-limit.ini

# Sentry
RUN mkdir -p /root/.local/bin; \
    curl -sL https://sentry.io/get-cli/ | INSTALL_DIR=/root/.local/bin bash

VOLUME /var/www/html

# Define Monica version and expected SHA512 signature
ENV MONICA_VERSION v2.16.0
ENV MONICA_SHA512 f2d1a434b5615bcd100388066854dfd36c81f403e817f45a21d4c04ec9ee022339c25334913586a51e763928d17d8b3fa79b6bf1883cac6fffe1aabfbd14ae3c

RUN set -ex; \
    apk add --no-cache --virtual .fetch-deps \
        bzip2 \
    ; \
    \
	curl -fsSL -o monica.tar.bz2 "https://github.com/monicahq/monica/releases/download/${MONICA_VERSION}/monica-${MONICA_VERSION}.tar.bz2"; \
	echo "$MONICA_SHA512 *monica.tar.bz2" | sha512sum -c -; \
    \
	mkdir /usr/src/monica; \
	tar -xf monica.tar.bz2 -C /usr/src/monica --strip-components=1; \
	rm monica.tar.bz2; \
    \
	cp /usr/src/monica/.env.example /usr/src/monica/.env; \
	chown -R www-data:www-data /usr/src/monica; \
    \
	apk del .fetch-deps; \
    rm -rf /var/cache/apk/*

COPY upgrade.exclude \
    /usr/local/share/
COPY entrypoint.sh \
    queue.sh \
    cron.sh \
    /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
