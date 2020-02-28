#!/bin/bash
set -e

IFS='
'

declare -A php_version=(
	[default]='7.3'
)

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

declare -A document=(
	[apache]="ENV APACHE_DOCUMENT_ROOT /var/www/html/public\\n\
RUN set -eu; sed -ri -e \"s!/var/www/html!\\\${APACHE_DOCUMENT_ROOT}!g\" /etc/apache2/sites-available/*.conf; \\\\\\n\
	sed -ri -e \"s!/var/www/!\\\${APACHE_DOCUMENT_ROOT}!g\" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf"
	[fpm]=''
	[fpm-alpine]=''
)

label="LABEL maintainer=\"Alexis Saettler <alexis@saettler.org> (@asbiin)\" \\n\
      org.label-schema.name=\"MonicaHQ, the Personal Relationship Manager\" \\n\
      org.label-schema.description=\"This is MonicaHQ, your personal memory! MonicaHQ is like a CRM but for the friends, family, and acquaintances around you.\" \\n\
      org.label-schema.url=\"https://monicahq.com\" \\n\
      org.label-schema.vcs-url=\"https://github.com/monicahq/monica\" \\n\
      org.label-schema.vendor=\"Monica\" \\n\
      org.label-schema.schema-version=\"1.0\""

apcu_version="$(
	git ls-remote --tags https://github.com/krakjoe/apcu.git \
		| cut -d/ -f3 \
		| grep -vE -- '-rc|-b' \
		| sed -E 's/^v//' \
		| sort -V \
		| tail -1
)"

memcached_version="$(
	git ls-remote --tags https://github.com/php-memcached-dev/php-memcached.git \
		| cut -d/ -f3 \
		| grep -vE -- '-rc|-b' \
		| sed -E 's/^[rv]//' \
		| sort -V \
		| tail -1
)"

redis_version="$(
	git ls-remote --tags https://github.com/phpredis/phpredis.git \
		| cut -d/ -f3 \
		| grep -viE '[a-z]' \
		| tr -d '^{}' \
		| sort -V \
		| tail -1
)"

declare -A pecl_versions=(
	[APCu]="$apcu_version"
	[memcached]="$memcached_version"
	[redis]="$redis_version"
)

version="$(curl -fsSL 'https://api.github.com/repos/monicahq/monica/releases/latest' | jq -r '.tag_name')"
sha512="$(curl -fsSL "https://github.com/monicahq/monica/releases/download/$version/monica-$version.sha512" | grep monica-$version.tar.bz2 | awk '{ print $1 }')"

set -x

for variant in apache fpm fpm-alpine; do
	rm -rf $variant
	mkdir -p $variant
	phpVersion=${php_version[$version]-${php_version[default]}}

	template="Dockerfile-${base[$variant]}.template"
	sed -e '
		s/%%VARIANT%%/'"$variant"'/;
		s/%%PHP_VERSION%%/'"$phpVersion"'/;
		s/%%VERSION%%/'"$version"'/;
		s/%%SHA512%%/'"$sha512"'/;
		s/%%CMD%%/'"${cmd[$variant]}"'/;
		s#%%LABEL%%#'"$label"'#;
		s#%%APACHE_DOCUMENT%%#'"${document[$variant]}"'#;
		s/%%APCU_VERSION%%/'"${pecl_versions[APCu]}"'/;
		s/%%MEMCACHED_VERSION%%/'"${pecl_versions[memcached]}"'/;
		s/%%REDIS_VERSION%%/'"${pecl_versions[redis]}"'/;
	' \
		$template > "$variant/Dockerfile"
	
	for file in entrypoint cron queue; do
		cp docker-$file.sh $variant/$file.sh
	done
	
	cp upgrade.exclude $variant/
done
