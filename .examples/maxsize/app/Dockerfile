FROM monica:fpm-alpine

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Set the upload limit to 10G
ENV PHP_UPLOAD_LIMIT="10G"

# Set the memory limit to 512M
ENV PHP_MEMORY_LIMIT="512M"
