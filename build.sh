#!/bin/bash
set -ex

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

nocache="--no-cache"
if [ -n "${1:-}" ]; then
	releases=( "$1" )
fi
if [ -n "${2:-}" ]; then
	variants=( "$2" )
	nocache=""
fi

for release in ${releases[@]}; do
	for variant in ${variants[@]}; do
	    php=${php_version[$release]-${php_version[default]}}
		docker pull php:$php-$variant
		docker build $nocache -t monica:$release-$variant $release/$variant
	done
done

docker images
