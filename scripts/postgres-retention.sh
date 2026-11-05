#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="/mnt/tank/backups/databases"
MODE="${1:---dry-run}"
KEEP_DAYS=30
KEEP_MIN=3

apps=(nextcloud immich vaultwarden joplin lubelogger)

if (( $# > 1 )) ||
   [[ "$MODE" != "--dry-run" && "$MODE" != "--delete" ]]; then
    echo "Usage: $0 [--dry-run|--delete]" >&2
    exit 2
fi

if (( EUID != 0 )); then
    echo "ERROR: Must run as root." >&2
    exit 1
fi

if [[ ! -d "$ROOT" || -L "$ROOT" ]] ||
   [[ "$(stat -c '%u:%g:%a' "$ROOT")" != "0:0:700" ]]; then
    echo "ERROR: Invalid backup root or permissions." >&2
    exit 1
fi

# Use the same lock as the backup script.
exec 9>"/mnt/tank/backups/.postgres-backup.lock"
flock -n 9 || {
    echo "ERROR: Backup or cleanup already running." >&2
    exit 1
}

complete_set() {
    local dir="$1"

    [[ -d "$dir" && ! -L "$dir" ]] || return 1

    local file
    for file in database.dump globals.sql SHA256SUMS; do
        [[ -f "$dir/$file" &&
           -s "$dir/$file" &&
           ! -L "$dir/$file" ]] || return 1
    done

    # Refuse directories containing unexpected files.
    [[ "$(find "$dir" -mindepth 1 -maxdepth 1 -printf x)" == "xxx" ]]
}

now="$(date -u +%s)"
cutoff=$((now - KEEP_DAYS * 86400))
eligible=0

for app in "${apps[@]}"; do
    app_dir="$ROOT/$app"

    if [[ ! -d "$app_dir" || -L "$app_dir" ]] ||
       [[ "$(stat -c '%u:%g:%a' "$app_dir")" != "0:0:700" ]]; then
        echo "ERROR: Invalid application directory: $app_dir" >&2
        exit 1
    fi

    sets=()

    for dir in "$app_dir"/*; do
        [[ -d "$dir" && ! -L "$dir" ]] || continue

        name="${dir##*/}"
        [[ "$name" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || continue

        if complete_set "$dir"; then
            sets+=("$dir")
        else
            echo "SKIPPED incomplete/unexpected set: $dir" >&2
        fi
    done

    (( ${#sets[@]} > KEEP_MIN )) || continue

    # Timestamp names sort in chronological order.
    mapfile -t ordered < <(
        printf '%s\n' "${sets[@]}" | LC_ALL=C sort -r
    )

    for ((i = KEEP_MIN; i < ${#ordered[@]}; i++)); do
        dir="${ordered[$i]}"
        name="${dir##*/}"

        formatted="${name:0:4}-${name:4:2}-${name:6:2} ${name:9:2}:${name:11:2}:${name:13:2} UTC"

        if ! created="$(date -u -d "$formatted" +%s)"; then
            echo "ERROR: Invalid timestamp: $name" >&2
            exit 1
        fi

        if [[ "$(date -u -d "@$created" +%Y%m%dT%H%M%SZ)" != "$name" ]]; then
            echo "ERROR: Timestamp mismatch: $name" >&2
            exit 1
        fi

        (( created < cutoff )) || continue

        eligible=$((eligible + 1))

        if [[ "$MODE" == "--dry-run" ]]; then
            echo "WOULD DELETE: $dir"
        else
            complete_set "$dir" || {
                echo "ERROR: Backup contents changed: $dir" >&2
                exit 1
            }

            rm -- \
                "$dir/database.dump" \
                "$dir/globals.sql" \
                "$dir/SHA256SUMS"

            rmdir -- "$dir"
            echo "DELETED: $dir"
        fi
    done
done

echo "Finished: $MODE; eligible backup sets: $eligible"