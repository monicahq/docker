#!/bin/bash
set -euo pipefail

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
defaultVariant='apache'

# Get the most recent commit which modified any of "$@".
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# Get the most recent commit which modified "$1/Dockerfile" or any file that
# the Dockerfile copies into the rootfs (with COPY).
dockerfileCommit() {
	local dir="$1"; shift
	(
		cd "$dir";
		fileCommit Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++)
							print $i;
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -maxdepth 3 -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'monica'

# Header.
cat <<-EOH
# This file is generated via https://github.com/monicahq/docker/blob/$(fileCommit "$self")/$self
Maintainers: Alexis Saettler <alexis@saettler.org> (@asbiin)
GitRepo: https://github.com/monicahq/docker.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

SEARCHFOR="Upgrade available - the latest version is "
latest="$(curl -fsSL 'https://api.github.com/repos/monicahq/monica/releases/latest' | jq -r '.tag_name')"

variants=( */ )
variants=( "${variants[@]%/}" )

for variant in "${variants[@]}"; do
	commit="$(dockerfileCommit "$variant")"
	fullversion="$(git show "$commit":"$variant/Dockerfile" | grep -iF "ENV MONICA_VERSION" | sed -E "s@ENV MONICA_VERSION v([0-9.]+)@\1@")"

	versionAliases=( "$fullversion" "${fullversion%.*}" "${fullversion%.*.*}" )
	if [ "$fullversion" = "$latest" ]; then
		versionAliases+=( "latest" )
	fi

	variantAliases=( "${versionAliases[@]/%/-$variant}" )
	variantAliases=( "${variantAliases[@]//latest-}" )

	if [ "$variant" = "$defaultVariant" ]; then
		variantAliases+=( "${versionAliases[@]}" )
	fi

	variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$variant/Dockerfile")"
	variantArches="${parentRepoToArches[$variantParent]}"

	cat <<-EOE

		Tags: $(join ', ' "${variantAliases[@]}")
		Architectures: $(join ', ' $variantArches)
		Directory: $variant
		GitCommit: $commit
	EOE
done
