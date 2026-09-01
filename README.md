# ghost-db — public mirror log

Auto-pushed every 3 mins from `ghost-mirror/ghost.db` (WAL sqlite).

Files:
- `ghost.db` — sqlite with tables `last_ids`, `msg_map`, `relay_log`, `deleted_msgs`, `kv` — survives restarts
- `ghost.sql.gz` — gzipped SQL dump
- `relay_log.json` — JSON export of relay_log

**Warning: public — contains all relayed Glacier messages (including deleted).**

Source: https://github.com/ewdewdaw/ghost-mirror
