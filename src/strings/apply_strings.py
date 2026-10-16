# Writes translations.py into the REDkit project string database.
# Run with REDkit closed:  python -I src\strings\apply_strings.py
# Then in REDkit: Publish > Cook Mod Strings, then Save and publish.
import os
import shutil
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from translations import KEYS, TEXT  # noqa: E402

DB = os.path.join(HERE, "..", "..", "LocalEditorStringDataBaseW3_UTF8_mod.db")
shutil.copyfile(DB, DB + ".bak")

con = sqlite3.connect(DB)
lang_ids = {name: lid for lid, name in con.execute("SELECT ID, LANG FROM LANGUAGES")}
next_id = con.execute("SELECT MAX(STRING_ID) FROM STRING_INFO").fetchone()[0] + 1
changed = 0
for i, key in enumerate(KEYS):
    row = con.execute("SELECT STRING_ID FROM STRING_INFO WHERE STRING_KEY = ?", (key,)).fetchone()
    if row:
        sid = row[0]
    else:
        sid = next_id
        next_id += 1
        category = "Item" if key.startswith("item_") else "All"
        con.execute("INSERT INTO STRING_INFO (STRING_ID, RESOURCE, PROPERTY_NAME, VOICEOVER_NAME, STRING_KEY)"
                    " VALUES (?, 'CUSTOM', ?, NULL, ?)", (sid, category, key))
    for lang, rows in TEXT.items():
        lid = lang_ids[lang]
        text = rows[i]
        latest = con.execute("SELECT TEXT FROM STRINGS WHERE STRING_ID = ? AND LANG = ? ORDER BY VERSION DESC LIMIT 1",
                             (sid, lid)).fetchone()
        if latest and latest[0] == text:
            continue
        # A version number is unique per string across all languages; the newest one wins.
        version = con.execute("SELECT COALESCE(MAX(VERSION), 0) + 1 FROM STRINGS WHERE STRING_ID = ?", (sid,)).fetchone()[0]
        con.execute("INSERT INTO STRINGS (STRING_ID, LANG, VERSION, TEXT) VALUES (?, ?, ?, ?)", (sid, lid, version, text))
        changed += 1
con.execute("UPDATE sqlite_sequence SET seq = (SELECT MAX(STRING_ID) FROM STRING_INFO) WHERE name = 'STRING_INFO'")
con.commit()
print(f"{changed} strings written across {len(TEXT)} languages; backup at {DB}.bak")
