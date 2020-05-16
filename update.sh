#!/bin/bash
set -e

IFS='
'

_template() {
    sed -e 's/\\/\\\\/g' $1 | sed -E ':a;N;$!ba;s/\r{0,1}\n/%0A/g'
}

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
    [apache]=$(_template .templates/Dockerfile-apache.template)
    [fpm]=''
    [fpm-alpine]=''
)

label=$(_template .templates/Dockerfile-label.template)

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

_githubapi() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: token $GITHUB_TOKEN" $1;
    else
        curl -fsSL $1;
    fi
}

version="$(_githubapi 'https://api.github.com/repos/monicahq/monica/releases/latest' | jq -r '.tag_name')"
commit="$(_githubapi 'https://api.github.com/repos/monicahq/monica/tags' | jq -r 'map(select(.name | contains ("'$version'"))) | .[].commit.sha')"

head=$(_template .templates/Dockerfile-head.template)
foot=$(_template .templates/Dockerfile-foot.template)
extra=$(_template .templates/Dockerfile-extra.template)
install=$(_template .templates/Dockerfile-install.template)

set -x

for variant in apache fpm fpm-alpine; do
    rm -rf $variant
    mkdir -p $variant
    phpVersion=${php_version[$version]-${php_version[default]}}

    template="Dockerfile-${base[$variant]}.template"

    sed -e '
        s@%%HEAD%%@'"$head"'@;
        s@%%FOOT%%@'"$foot"'@;
        s@%%EXTRA_INSTALL%%@'"$extra"'@;
        s@%%INSTALL%%@'"$install"'@;
        s/%%VARIANT%%/'"$variant"'/;
        s/%%PHP_VERSION%%/'"$phpVersion"'/;
        s#%%LABEL%%#'"$label"'#;
        s/%%VERSION%%/'"$version"'/;
        s/%%COMMIT%%/'"$commit"'/;
        s/%%CMD%%/'"${cmd[$variant]}"'/;
        s#%%APACHE_DOCUMENT%%#'"${document[$variant]}"'#;
        s/%%APCU_VERSION%%/'"${pecl_versions[APCu]}"'/;
        s/%%MEMCACHED_VERSION%%/'"${pecl_versions[memcached]}"'/;
        s/%%REDIS_VERSION%%/'"${pecl_versions[redis]}"'/;
    ' \
        -e "s/%0A/\n/g;" \
        $template > "$variant/Dockerfile"
    
    for file in entrypoint cron queue; do
        cp docker-$file.sh $variant/$file.sh
    done
done
