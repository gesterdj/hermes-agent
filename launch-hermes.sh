#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${HERMES_IMAGE:-nousresearch/hermes-agent:latest}"
CONTAINER="${HERMES_CONTAINER:-hermes}"
HERMES_DATA="${HERMES_DATA:-$HOME/.hermes}"
ENV_FILE="${HERMES_ENV_FILE:-$HERMES_DATA/docker.env}"
DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed or not in PATH." >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Error: image is not available locally: $IMAGE" >&2
    echo "Wait for the background pull to finish." >&2
    exit 1
fi

mkdir -p "$HERMES_DATA"
chmod 700 "$HERMES_DATA"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: missing environment file: $ENV_FILE" >&2
    exit 1
fi

chmod 600 "$ENV_FILE"

echo "Image:"
docker image inspect "$IMAGE" \
    --format '  ID: {{.Id}}{{println}}{{range .RepoDigests}}  Digest: {{.}}{{println}}{{end}}'

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "Removing existing container: $CONTAINER"
    docker rm -f "$CONTAINER"
fi

echo "Starting $CONTAINER..."

docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    --add-host=host.docker.internal:host-gateway \
    -p "127.0.0.1:${DASHBOARD_PORT}:9119" \
    -v "$HERMES_DATA:/opt/data" \
    --env-file "$ENV_FILE" \
    -e "HERMES_UID=$(id -u)" \
    -e "HERMES_GID=$(id -g)" \
    -e "HERMES_DASHBOARD=1" \
    -e "HERMES_DASHBOARD_HOST=0.0.0.0" \
    -e "HERMES_TUI_DIR=/opt/hermes/ui-tui" \
    "$IMAGE" \
    gateway run

echo "Waiting for dashboard..."

for attempt in {1..30}; do
    if curl --silent --show-error --fail \
        "http://127.0.0.1:${DASHBOARD_PORT}/api/status" \
        >/dev/null 2>&1; then
        echo
        echo "Hermes is ready:"
        echo "  Dashboard: http://127.0.0.1:${DASHBOARD_PORT}/chat"
        echo "  Logs:      docker logs -f $CONTAINER"
        exit 0
    fi

    if ! docker container inspect \
        --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null |
        grep -qx true; then
        echo
        echo "Error: container exited during startup." >&2
        docker logs --tail 100 "$CONTAINER" >&2
        exit 1
    fi

    printf '.'
    sleep 2
done

echo
echo "Dashboard did not become ready within 60 seconds." >&2
docker logs --tail 100 "$CONTAINER" >&2
exit 1
