#!/usr/bin/env bash
# ==============================================================================
# [ID-PLATFORM] Product Modules Pipeline Runner (Bash)
# ==============================================================================

set -euo pipefail

TARGET="${1:-local}"
ACTION="${2:-install}"
WITH_SEED="${3:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$CLOUD_DIR"

echo "===================================================================="
echo " [ID-PLATFORM] Product Modules Runner (Action: $ACTION, Target: $TARGET)"
echo " Working Directory: $CLOUD_DIR"
echo "===================================================================="

DB_CONTAINER=$(docker ps --filter "name=supabase_db" --format "{{.Names}}" | head -n 1 || true)

apply_file() {
    local file_path="$1"
    if [ "$TARGET" = "local" ] && [ -n "$DB_CONTAINER" ]; then
        docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$file_path"
    else
        supabase db query "--$TARGET" -f "$file_path"
    fi
}

if [ "$ACTION" = "uninstall" ]; then
    MODULES=("store" "dispatch" "licensing" "vault")
else
    MODULES=("vault" "licensing" "dispatch" "store")
fi

for mod in "${MODULES[@]}"; do
    SQL_FILE="supabase/plugins/$mod/$ACTION.sql"
    if [ ! -f "$SQL_FILE" ]; then
        echo "[-] Module action file not found, skipping: $SQL_FILE"
        continue
    fi

    echo -e "\n--> [$ACTION] Module: $mod..."
    apply_file "$SQL_FILE"
    echo "    [OK] Module $mod applied successfully."

    if [ "$ACTION" = "install" ] && [ "$WITH_SEED" = "true" ]; then
        SEED_FILE="supabase/plugins/$mod/seed.sql"
        if [ -f "$SEED_FILE" ]; then
            echo "    --> Applying sample data: $SEED_FILE"
            apply_file "$SEED_FILE"
            echo "    [OK] Sample data applied for $mod"
        fi
    fi
done

echo -e "\n[SUCCESS] Product modules pipeline completed successfully!"
