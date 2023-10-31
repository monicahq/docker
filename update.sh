#!/bin/bash
set -e

IFS='
'

_template() {
    sed -e 's/\\/\\\\/g' $1 | sed -E ':a;N;$!ba;s/\r{0,1}\n/%0A/g'
}

releases=(
    4
    5
)

variants=(
    apache
    fpm
    fpm-alpine
)

declare -A php_version=(
    [default]='8.2'
    [5]='8.2'
    [4]='8.1'
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

echo Initialisation

apcu_version="$(
    git ls-remote --tags https://github.com/krakjoe/apcu.git \
        | cut -d/ -f3 \
        | grep -viE -- 'rc|b' \
        | sed -E 's/^v//' \
        | sort -V \
        | tail -1
)"
echo "  APCu version: $apcu_version"

memcached_version="$(
    git ls-remote --tags https://github.com/php-memcached-dev/php-memcached.git \
        | cut -d/ -f3 \
        | grep -viE -- 'rc|b' \
        | sed -E 's/^[rv]//' \
        | sort -V \
        | tail -1
)"
echo "  Memcached version: $memcached_version"

redis_version="$(
    git ls-remote --tags https://github.com/phpredis/phpredis.git \
        | cut -d/ -f3 \
        | grep -viE '[a-z]' \
        | tr -d '^{}' \
        | sort -V \
        | tail -1
)"
echo "  Redis version: $redis_version"

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

head=$(_template .templates/Dockerfile-head.template)
extra=$(_template .templates/Dockerfile-extra.template)
install=$(_template .templates/Dockerfile-install.template)

if [ -n "${1:-}" ]; then
    releases=( "$1" )
fi
if [ -n "${2:-}" ]; then
    variants=( "$2" )
fi

for release in "${releases[@]}"; do

    echo "Processing release $release"

    version="$(_githubapi 'https://api.github.com/repos/monicahq/monica/releases' | jq -r 'map(select(.tag_name | startswith ("v'$release'"))) | .[0].tag_name')"

    echo "  Monica version: $version"
    commit="$(_githubapi 'https://api.github.com/repos/monicahq/monica/tags' | jq -r 'map(select(.name | contains ("'$version'"))) | .[].commit.sha')"
    echo "  Commit: $commit"

    foot=$(_template .templates/Dockerfile-foot$release.template)

    for variant in "${variants[@]}"; do
        echo Generating $variant variant...
        rm -rf $release/$variant
        mkdir -p $release/$variant
        phpVersion=${php_version[$release]-${php_version[default]}}

        template=".templates/Dockerfile-${base[$variant]}.template"

        sed -e '
            s@%%HEAD%%@'"$head"'@;
            s@%%FOOT%%@'"$foot"'@;
            s@%%EXTRA_INSTALL%%@'"$extra"'@;
            s@%%INSTALL%%@'"$install"'@;
            s/%%VARIANT%%/'"$variant"'/;
            s/%%PHP_VERSION%%/'"$phpVersion"'/;
            s#%%LABEL%%#'"$label"'#;
            s/%%VERSION%%/'"$version"'/g;
            s/%%COMMIT%%/'"$commit"'/;
            s/%%CMD%%/'"${cmd[$variant]}"'/;
            s@%%APACHE_DOCUMENT%%@'"${document[$variant]}"'@;
            s/%%APCU_VERSION%%/'"${pecl_versions[APCu]}"'/;
            s/%%MEMCACHED_VERSION%%/'"${pecl_versions[memcached]}"'/;
            s/%%REDIS_VERSION%%/'"${pecl_versions[redis]}"'/;
        ' \
            -e "s/%0A/\n/g;" \
            $template > "$release/$variant/Dockerfile"
        
        cp .templates/scripts/$release/* $release/$variant/
    done
done
