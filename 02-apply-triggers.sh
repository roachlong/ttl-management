#!/usr/bin/env bash
for tbl in customers products orders; do
  cockroach sql --url "${conn_str}" <<EOF
DROP TRIGGER IF EXISTS trg_${tbl}_updated_at ON ${tbl};
CREATE TRIGGER trg_${tbl}_updated_at
  BEFORE UPDATE ON ${tbl}
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
EOF
done
