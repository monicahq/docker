FROM monica:fpm-alpine

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN set -ex;\
    \
    { \
        echo '[www]'; \
        echo 'upload_max_filesize = 500M'; \
        echo 'post_max_size = 500M'; \
        echo 'max_execution_time = 600'; \
    } \
        > $PHP_INI_DIR/conf.d/uploads.ini
