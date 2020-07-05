#!/bin/bash
set -ex

for variant in apache fpm fpm-alpine; do
	pushd $variant
	docker pull php:7.3-$variant
	docker build --no-cache -t monica:$variant .
	popd
done

docker images
