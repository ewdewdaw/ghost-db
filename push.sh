#!/bin/bash
set -e
SRC="/home/server/ghost-mirror/ghost.db"
DST="/tmp/ghost-db"
WEBHOOKS="/home/server/ghost-mirror/webhooks.json"
if [ ! -f "$SRC" ]; then echo "no db"; exit 0; fi
sqlite3 "$SRC" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
mkdir -p "$DST"
# clean old generated txts but keep README/push.sh/.git
cd "$DST"
# remove old channel txts (keep README.md and push.sh)
find . -maxdepth 1 -name "*.txt" -delete 2>/dev/null || true
rm -f ghost.db ghost.sql.gz relay_log.json 2>/dev/null || true
# export per-channel txts + deleted.txt from db
python3 << 'PY'
import sqlite3, json, os, re
SRC="/home/server/ghost-mirror/ghost.db"
DST="/tmp/ghost-db"
WEBHOOKS="/home/server/ghost-mirror/webhooks.json"
con=sqlite3.connect(SRC)
cur=con.cursor()
# channels from webhooks
try:
    chans=list(json.load(open(WEBHOOKS)).keys())
except: chans=[]
# also distinct channels from relay_log
try:
    cur.execute("SELECT DISTINCT channel FROM relay_log")
    for (ch,) in cur.fetchall():
        if ch not in chans: chans.append(ch)
except: pass
# distinct from deleted_msgs channel names already covered
for ch in chans:
    cur.execute("SELECT timestamp,author,author_id,channel,content,deleted FROM relay_log WHERE channel=? ORDER BY timestamp", (ch,))
    rows=cur.fetchall()
    # also include deleted_msgs for this channel that may not be in relay_log? append
    try:
        cur2=con.cursor()
        cur2.execute("SELECT timestamp, user_id, channel, content FROM deleted_msgs WHERE channel=? ORDER BY timestamp", (ch,))
        for ts,uid,cc,content in cur2.fetchall():
            # check if already in rows by content/timestamp? just add if not duplicate
            # get author name via relay_log or unknown
            rows.append((ts, f"uid:{uid}", uid, cc, content, 1))
    except: pass
    if not rows:
        # create empty file to show channel exists even if no logs yet (after migration relay_log may be sparse)
        # we keep empty file with header
        rows=[]
    # sanitize filename: keep as is but ensure not containing /
    fname=ch.replace("/","_") + ".txt"
    path=os.path.join(DST, fname)
    with open(path,"w",encoding="utf-8") as f:
        f.write(f"# {ch} — {len(rows)} msgs (including deleted)\n")
        f.write(f"# exported {__import__('datetime').datetime.utcnow().isoformat()}Z\n")
        f.write("="*60+"\n")
        for ts,author,aid,cchan,content,deleted in sorted(rows, key=lambda x: x[0] or ""):
            prefix="[DELETED] " if deleted else ""
            author_str=author or aid or "?"
            ts_str=ts[:19] if ts else "?"
            cont=content or "*no content*"
            # truncate very long
            if len(cont)>2000: cont=cont[:2000]+"..."
            f.write(f"[{ts_str}] {prefix}{author_str} ({aid}): {cont}\n")
# deleted.txt - only deleted
cur.execute("SELECT timestamp,author,author_id,channel,content FROM relay_log WHERE deleted=1 ORDER BY timestamp")
drows=cur.fetchall()
# also from deleted_msgs
try:
    cur.execute("SELECT timestamp,user_id,channel,content FROM deleted_msgs ORDER BY timestamp")
    for ts,uid,ch,c in cur.fetchall():
        drows.append((ts, f"uid:{uid}", uid, ch, c))
except: pass
with open(os.path.join(DST,"deleted.txt"),"w",encoding="utf-8") as f:
    f.write(f"# deleted msgs — {len(drows)} total\n")
    f.write(f"# exported {__import__('datetime').datetime.utcnow().isoformat()}Z\n")
    f.write("="*60+"\n")
    for ts,author,aid,ch,content in sorted(drows, key=lambda x: x[0] or ""):
        ts_str=ts[:19] if ts else "?"
        author_str=author or aid or "?"
        cont=content or "*no content*"
        if len(cont)>2000: cont=cont[:2000]+"..."
        f.write(f"[{ts_str}] #{ch} {author_str} ({aid}): {cont}\n")
print(f"exported {len(chans)} channels -> txt, deleted {len(drows)}")
PY
# git add only txts + README + push.sh
cd "$DST"
git add -f README.md push.sh *.txt 2>/dev/null || true
# remove old db files from tracking if they exist in repo
git rm -f --cached ghost.db ghost.sql.gz relay_log.json 2>/dev/null || true
rm -f ghost.db ghost.sql.gz relay_log.json 2>/dev/null || true
if git diff --cached --quiet; then echo "no changes"; exit 0; fi
git -c user.name="ghost-sync" -c user.email="ghost@glacier" commit -m "sync $(date -u +%Y-%m-%dT%H:%M:%SZ) channels" >/dev/null
git push -q
echo "pushed $(date -u +%H:%M:%S) txts=$(ls -1 *.txt 2>/dev/null | wc -l)"
