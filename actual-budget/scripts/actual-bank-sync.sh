#!/bin/sh
set -eu

docker run --rm \
  --network host \
  --env-file /mnt/tank/appdata/actual-budget/actual-bank-sync.env \
  -e ACTUAL_PASSWORD_FILE=/run/secrets/actual-password \
  -v /mnt/tank/appdata/actual-budget/actual-password:/run/secrets/actual-password:ro \
  node:22-alpine \
sh -c 'npx -y @actual-app/cli server bank-sync'