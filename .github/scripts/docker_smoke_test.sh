#!/usr/bin/env bash
# Boots the release image against a real Postgres: runs migrations, starts
# the server and checks a few pages. Usage:
#   DATABASE_URL=ecto://postgres:postgres@localhost/smoke .github/scripts/docker_smoke_test.sh IMAGE
# Set DOCKER_CONTEXT to pick a Docker engine, as with the docker CLI.
set -euo pipefail

image="${1:?usage: $0 IMAGE}"
port="${PORT:-4100}"
: "${DATABASE_URL:?DATABASE_URL is required}"

env_args=(
  -e DATABASE_URL -e PORT="$port" -e PHX_HOST=localhost
  -e SECRET_KEY_BASE="$(head -c 64 /dev/urandom | base64 -w0)"
  -e API_TOKEN=smoke-test-token
  -e CLOUDINARY_API_KEY=smoke -e CLOUDINARY_SECRET=smoke -e CLOUDINARY_CLOUD_NAME=smoke
  -e SENDGRID_API_KEY=smoke -e MAIL_FROM=smoke@example.com
)

echo "--- migrations"
timeout 120 docker run --rm --network host "${env_args[@]}" "$image" /app/bin/migrate

echo "--- server"
container="$(docker run -d --network host "${env_args[@]}" "$image")"
trap 'echo "--- container log"; docker logs "$container" 2>&1 | tail -40; docker rm -f "$container" >/dev/null' EXIT

for _ in $(seq 1 30); do
  curl -fsS -o /dev/null -m 2 "http://localhost:$port/" && break
  sleep 1
done

status=0
check() {
  local expected="$1" method="$2" path="$3" actual
  actual="$(curl -s -o /dev/null -m 5 -X "$method" -w '%{http_code}' "http://localhost:$port$path")"
  echo "$actual $method $path"
  [ "$actual" = "$expected" ] || { echo "expected $expected"; status=1; }
}

check 200 GET /
check 200 GET /users/log_in
check 200 GET /api/posts
check 302 GET /admin
check 401 POST /api/tags

asset="$(curl -s -m 5 "http://localhost:$port/" | grep -oE '/assets/app-[a-f0-9]+\.css' | head -1)"
if [ -n "$asset" ]; then check 200 GET "$asset"; else echo "no digested CSS link on /"; status=1; fi

exit "$status"
