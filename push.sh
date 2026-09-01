#!/bin/bash
set -e
SRC="/home/server/ghost-mirror/ghost.db"
DST="/tmp/ghost-db"
if [ ! -f "$SRC" ]; then echo "no db"; exit 0; fi
# checkpoint WAL so ghost.db is consistent
sqlite3 "$SRC" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
cp -f "$SRC" "$DST/ghost.db"
# also export readable dumps
sqlite3 "$SRC" ".dump" | gzip -c > "$DST/ghost.sql.gz" 2>/dev/null || true
sqlite3 "$SRC" "SELECT json_group_array(json_object('source_msg_id',source_msg_id,'webhook_msg_id',webhook_msg_id,'channel',channel,'author',author,'content',content,'timestamp',timestamp,'deleted',deleted)) FROM relay_log;" 2>/dev/null | python3 -m json.tool > "$DST/relay_log.json" 2>/dev/null || true
cd "$DST"
git add -f ghost.db ghost.sql.gz relay_log.json 2>/dev/null || git add -f ghost.db
if git diff --cached --quiet; then echo "no changes"; exit 0; fi
git -c user.name="ghost-sync" -c user.email="ghost@glacier" commit -m "sync ghost.db $(date -u +%Y-%m-%dT%H:%M:%SZ) $(sqlite3 /home/server/ghost-mirror/ghost.db 'select count(*) from relay_log' 2>/dev/null) relays" >/dev/null
git push -q
echo "pushed $(date -u +%H:%M:%S) size=$(du -h ghost.db | cut -f1)"
