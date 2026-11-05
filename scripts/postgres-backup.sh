#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BACKUP_ROOT="/mnt/tank/backups/databases"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must run as root." >&2
    exit 1
fi

if [[ "$(stat -c '%u:%g:%a' "$BACKUP_ROOT")" != "0:0:700" ]]; then
    echo "ERROR: Backup root has incorrect permissions." >&2
    exit 1
fi

# Prevent simultaneous backup runs.
exec 9>"/mnt/tank/backups/.postgres-backup.lock"

if ! flock -n 9; then
    echo "ERROR: Another backup is running." >&2
    exit 1
fi

cleanup_partial() {
    local directory="$1"

    rm -f -- \
        "$directory/database.dump" \
        "$directory/globals.sql" \
        "$directory/SHA256SUMS"

    rmdir -- "$directory"
}

backup_database() {
    local app="$1"
    local container="$2"

    local directory="$BACKUP_ROOT/$app"
    local destination="$directory/$TIMESTAMP"
    local temporary

    echo "=== $app ==="

    if [[ ! -d "$directory" || -L "$directory" ]]; then
        echo "ERROR: Invalid directory: $directory" >&2
        return 1
    fi

    if [[ "$(stat -c '%u:%g:%a' "$directory")" != "0:0:700" ]]; then
        echo "ERROR: Incorrect directory permissions." >&2
        return 1
    fi

    if [[ -e "$destination" ]]; then
        echo "ERROR: Backup already exists: $destination" >&2
        return 1
    fi

    temporary="$(mktemp -d "$directory/.partial-XXXXXXXX")"

    # Consistent online database export.
    if ! docker exec "$container" sh -c \
        'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump \
        -h 127.0.0.1 \
        -p "${PGPORT:-5432}" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        -Fc' > "$temporary/database.dump"; then

        echo "ERROR: Database export failed." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    # Export PostgreSQL roles and other global objects.
    if ! docker exec "$container" sh -c \
        'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dumpall \
        -h 127.0.0.1 \
        -p "${PGPORT:-5432}" \
        -U "$POSTGRES_USER" \
        --globals-only' > "$temporary/globals.sql"; then

        echo "ERROR: Global objects export failed." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    # Validate the database archive without restoring it.
    if ! docker exec -i "$container" \
        pg_restore -f /dev/null \
        < "$temporary/database.dump"; then

        echo "ERROR: Database archive validation failed." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    if [[ ! -s "$temporary/database.dump" ||
          ! -s "$temporary/globals.sql" ]]; then

        echo "ERROR: Missing or empty backup component." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    # Generate and verify checksums.
    if ! (
        cd "$temporary"
        sha256sum database.dump globals.sql > SHA256SUMS
        sha256sum -c SHA256SUMS >/dev/null
    ); then

        echo "ERROR: Checksum verification failed." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    # Publish all components together.
    if ! mv -- "$temporary" "$destination"; then
        echo "ERROR: Failed to publish backup." >&2
        cleanup_partial "$temporary"
        return 1
    fi

    echo "SUCCESS: $destination"
}

services=(
    "nextcloud ix-nextcloud-postgres-1"
    "immich ix-immich-pgvecto-1"
    "vaultwarden ix-vaultwarden-postgres-1"
    "joplin ix-joplin-postgres-1"
    "lubelogger ix-lubelogger-postgres-1"
)

failures=0

for service in "${services[@]}"; do
    read -r app container <<< "$service"

    if ! backup_database "$app" "$container"; then
        failures=$((failures + 1))
    fi
done

if (( failures > 0 )); then
    echo "FAILED: $failures backup(s)." >&2
    exit 1
fi

echo "SUCCESS: All PostgreSQL backups completed."