#!/bin/bash
set -ex

for variant in apache fpm fpm-alpine; do
	pushd $variant
	docker pull php:8.1-$variant
	docker build --no-cache -t monica:$variant .
	popd
done

docker images
