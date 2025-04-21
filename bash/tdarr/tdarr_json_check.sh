#!/bin/bash

DB_PATH="${1:-/opt/Tdarr/server/Tdarr/DB2/SQL/database.db}"
DELETE_BAD_ROWS=false

if [[ "$2" == "--delete" ]]; then
  DELETE_BAD_ROWS=true
fi

if [[ ! -f "$DB_PATH" ]]; then
  echo "❌ Database not found at: $DB_PATH"
  exit 1
fi

echo "📂 Checking database: $DB_PATH"

# Use a temporary file to store delete commands if needed
DELETE_SQL=$(mktemp)

sqlite3 "$DB_PATH" "SELECT rowid, json_data FROM stagedjsondb;" | while IFS='|' read -r rowid json; do
  echo "$json" | jq empty >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "❌ Malformed JSON in rowid: $rowid"
    if $DELETE_BAD_ROWS; then
      echo "DELETE FROM stagedjsondb WHERE rowid=$rowid;" >>"$DELETE_SQL"
    fi
  fi
done

if $DELETE_BAD_ROWS && [[ -s "$DELETE_SQL" ]]; then
  echo "⚠️ Deleting malformed rows..."
  sqlite3 "$DB_PATH" <"$DELETE_SQL"
  echo "✅ Cleanup complete."
else
  echo "✅ Scan complete. No deletions performed."
fi

rm -f "$DELETE_SQL"
