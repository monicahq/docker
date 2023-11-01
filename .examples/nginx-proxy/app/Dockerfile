FROM monica:fpm

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

ENV PHP_UPLOAD_LIMIT="10G"
