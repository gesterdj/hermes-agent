#!/bin/sh
set -eu

# Build the current checkout as a local Hermes image.
# Usage: ./build-hermes-local.sh [image-tag]
# Optional: PLATFORM=linux/amd64 NO_CACHE=1 ./build-hermes-local.sh hermes-agent:interrupt-fix

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image_tag=${1:-hermes-agent:local}
git_sha=$(git -C "$repo_dir" rev-parse HEAD)

set -- build \
    --file "$repo_dir/Dockerfile" \
    --tag "$image_tag" \
    --build-arg "HERMES_GIT_SHA=$git_sha"

if [ -n "${PLATFORM:-}" ]; then
    set -- "$@" --platform "$PLATFORM"
fi

if [ "${NO_CACHE:-0}" = "1" ]; then
    set -- "$@" --no-cache
fi

if docker buildx version >/dev/null 2>&1; then
    docker buildx "$@" --load "$repo_dir"
else
    # `docker build` accepts the same options used above for a native build.
    docker "$@" "$repo_dir"
fi

printf '\nBuilt %s from %s\n' "$image_tag" "$git_sha"
printf 'Inspect: docker image inspect %s --format %s\n' \
    "$image_tag" "'{{.Id}}'"
