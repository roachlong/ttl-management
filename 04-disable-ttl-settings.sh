#!/usr/bin/env bash
set -euo pipefail

# 2) Grab all user tables
tables=$(cockroach sql --url "${conn_str}" \
  --format=tsv \
  --set='show_times=false' \
  -e """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema NOT IN (
        'crdb_internal',
        'pg_catalog',
        'pg_extension',
        'information_schema'
      )
      AND table_catalog = '$1';
  """ \
  | tail -n +2   # drop the first (header) line
)

# 3) Iterate and ALTER each one
for tbl in $tables; do
  echo "Checking table: $tbl"

  # 1) Grab the DDL for this table
  ddl=$(cockroach sql --url "${conn_str}" \
    --format=tsv \
    --set='show_times=false' \
    -e "SHOW CREATE TABLE \"${tbl}\";" \
    | tail -n +2   # drop header row
  )

  # 2) Check for ttl = 'on' (case‐sensitive exact match)
  if printf '%s\n' "$ddl" | grep -q "ttl = 'on'"; then
    echo "  → TTL enabled; applying ALTER."
    cockroach sql --url "${conn_str}" -e """
      ALTER TABLE "${tbl}"
      RESET (ttl);
    """
  else
    echo "  → TTL not configured; skipping."
  fi
done

echo "Done."
