FROM monica:fpm-alpine

RUN set -ex;\
    \
    { \
        echo '[www]'; \
        echo 'upload_max_filesize = 500M'; \
        echo 'post_max_size = 500M'; \
        echo 'max_execution_time = 600'; \
    } \
        > $PHP_INI_DIR/conf.d/uploads.ini
