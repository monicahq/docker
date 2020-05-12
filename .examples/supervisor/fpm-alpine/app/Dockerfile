FROM monica:fpm-alpine

# supervisord dependencies
RUN set -ex; \
	\
	apk add --no-cache \
        supervisor \
	;

COPY supervisord.conf /etc/supervisord.conf
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
