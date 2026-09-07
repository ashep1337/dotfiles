#!/usr/bin/env python3
"""Import Signal Desktop's local history into the Quickshell Signal service.

signal-cli only ever sees messages that arrive while it is running, and Signal's
servers keep nothing, so the shell's transcript starts empty. Signal Desktop,
though, has been keeping its own SQLCipher database all along — this reads it
once and seeds ~/.local/state/quickshell/signal-history.json with it.

This is a snapshot, not a sync. Run it again later and it merges rather than
duplicates, but between runs the two stores drift apart.

Attachments are imported as names only: Signal Desktop encrypts attachment
files at rest under its own per-file keys, so the bytes are not readable from
here even though the metadata is.

Usage:
    tools/import-desktop-history.py [--limit N] [--dry-run] [--force]

    --limit N   messages kept per conversation, newest first (default 300)
    --dry-run   report what would be imported, write nothing
    --force     run even though a Quickshell instance is up
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
SIGNAL_DIR = os.path.join(HOME, ".config", "Signal")
CONFIG = os.path.join(SIGNAL_DIR, "config.json")
DB = os.path.join(SIGNAL_DIR, "sql", "db.sqlite")
STORE = os.path.join(HOME, ".local", "state", "quickshell", "signal-history.json")

# Signal Desktop's own message types; the rest are call logs and group
# housekeeping, which have no place in a transcript.
KEEP_TYPES = ("incoming", "outgoing")


def fail(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def read_key():
    if not os.path.exists(CONFIG):
        fail(f"no Signal Desktop config at {CONFIG}")
    with open(CONFIG) as fh:
        cfg = json.load(fh)
    key = cfg.get("key")
    if not key:
        # Newer builds can wrap the key with the OS keyring instead.
        if "encryptedKey" in cfg:
            fail("this Signal Desktop stores its key in the OS keyring, "
                 "which this script cannot read")
        fail("no key in Signal Desktop's config.json")
    return key


def decrypt_to_plaintext(key, workdir):
    """Copy the database and export a decrypted copy sqlite3 can open."""
    for suffix in ("", "-wal", "-shm"):
        src = DB + suffix
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(workdir, "db.sqlite" + suffix))

    plain = os.path.join(workdir, "plain.db")
    sql = (f'PRAGMA key = "x\'{key}\'";\n'
           f"ATTACH DATABASE '{plain}' AS plaintext KEY '';\n"
           "SELECT sqlcipher_export('plaintext');\n"
           "DETACH DATABASE plaintext;\n")
    # The key goes in on stdin rather than argv, which any process can read.
    proc = subprocess.run(["sqlcipher", "-batch", os.path.join(workdir, "db.sqlite")],
                          input=sql, capture_output=True, text=True)
    if proc.returncode != 0 or not os.path.exists(plain):
        fail(f"sqlcipher failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return plain


def read_self_number():
    """The registered number, taken from signal-cli's own account store."""
    path = os.path.join(HOME, ".local", "share", "signal-cli", "data", "accounts.json")
    try:
        with open(path) as fh:
            for account in json.load(fh).get("accounts", []):
                # A half-finished registration has no uuid.
                if account.get("uuid"):
                    return account.get("number", "")
    except (OSError, ValueError):
        pass
    return ""


def shell_running():
    # Matched on the process name, not the command line: anything merely
    # mentioning the config path (this script's own shell, an editor) would
    # otherwise look like a running shell.
    for name in ("quickshell", "qs"):
        if subprocess.run(["pgrep", "-x", name],
                          capture_output=True).returncode == 0:
            return True
    return False


def conv_name(row):
    for key in ("name", "profileFullName"):
        if row[key]:
            return row[key]
    parts = [row["profileName"] or "", row["profileFamilyName"] or ""]
    joined = " ".join(p for p in parts if p).strip()
    return joined or row["e164"] or "Unknown"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=300,
                    help="messages per conversation, newest first")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if shell_running() and not args.force and not args.dry_run:
        fail("Quickshell is running and would overwrite this import on its next "
             "save. Quit it first, or pass --force.")

    import sqlite3

    key = read_key()
    workdir = tempfile.mkdtemp(prefix="signal-import-")
    try:
        plain = decrypt_to_plaintext(key, workdir)
        db = sqlite3.connect(plain)
        db.row_factory = sqlite3.Row

        # ── Who is who ────────────────────────────────────────────────
        # Desktop keys everything by its own conversation uuid, so both that
        # and the ACI need to resolve to a name and a phone number.
        by_conv_id, by_service_id = {}, {}
        self_number = read_self_number()
        for row in db.execute("""SELECT id, type, e164, serviceId, groupId, name,
                                        profileName, profileFamilyName, profileFullName
                                 FROM conversations"""):
            rec = {
                "convUuid": row["id"], "kind": "group" if row["type"] == "group" else "dm",
                "number": row["e164"] or "", "groupId": row["groupId"] or "",
                "serviceId": row["serviceId"] or "", "name": conv_name(row),
            }
            by_conv_id[row["id"]] = rec
            if rec["serviceId"]:
                by_service_id[rec["serviceId"]] = rec

        def name_for_service(aci):
            rec = by_service_id.get(aci)
            return rec["name"] if rec else ""

        def number_for_service(aci):
            rec = by_service_id.get(aci)
            return rec["number"] if rec else ""

        # ── Attachments, by message ───────────────────────────────────
        atts_by_msg = {}
        for row in db.execute("""SELECT messageId, contentType, fileName
                                 FROM message_attachments ORDER BY orderInMessage"""):
            atts_by_msg.setdefault(row["messageId"], []).append({
                # Deliberately empty: the file on disk is encrypted with a
                # per-attachment key this script has no way to apply.
                "path": "",
                # Desktop leaves this null for most attachments; the shell
                # falls back to a label derived from the content type.
                "name": row["fileName"] or "",
                "type": row["contentType"] or "",
            })

        # ── Messages ──────────────────────────────────────────────────
        threads, metas, skipped = {}, {}, 0
        placeholders = ",".join("?" for _ in KEEP_TYPES)
        rows = db.execute(f"""
            SELECT m.id, m.conversationId, m.sent_at, m.type, m.body,
                   m.sourceServiceId, m.json, m.hasAttachments
            FROM messages m
            WHERE m.type IN ({placeholders}) AND m.sent_at IS NOT NULL
            ORDER BY m.sent_at ASC""", KEEP_TYPES)

        for row in rows:
            conv = by_conv_id.get(row["conversationId"])
            if not conv:
                skipped += 1
                continue
            # A DM with no phone number cannot be addressed by signal-cli, so
            # importing it would produce a thread that can never be replied to.
            if conv["kind"] == "dm" and not conv["number"]:
                skipped += 1
                continue

            body = row["body"] or ""
            atts = atts_by_msg.get(row["id"], [])
            if not body and not atts:
                continue

            outgoing = row["type"] == "outgoing"
            extra = json.loads(row["json"]) if row["json"] else {}

            # Outgoing state is per recipient; the strongest one reached wins.
            delivered = read = False
            if outgoing:
                for state in (extra.get("sendStateByConversationId") or {}).values():
                    status = state.get("status")
                    if status == "Read":
                        delivered = read = True
                    elif status in ("Delivered", "Viewed"):
                        delivered = True

            reactions = []
            for reaction in extra.get("reactions") or []:
                who = by_conv_id.get(reaction.get("fromId"), {})
                reactions.append({
                    "from": who.get("number", ""),
                    "name": who.get("name", ""),
                    "emoji": reaction.get("emoji", ""),
                })

            quote = extra.get("quote") or {}
            sender = self_number if outgoing else number_for_service(row["sourceServiceId"])

            msg = {
                "ts": row["sent_at"],
                "sender": sender or "",
                "senderName": "You" if outgoing else (
                    name_for_service(row["sourceServiceId"]) or conv["name"]),
                "outgoing": outgoing,
                "text": body,
                "atts": atts,
                "reactions": reactions,
                "quoteAuthor": name_for_service(quote.get("authorAci", "")) if quote else "",
                "quoteText": quote.get("text", "") if quote else "",
                "pending": False, "failed": False,
                "delivered": delivered,
                # Everything imported is history; none of it should light up
                # the unread badge.
                "read": True if not outgoing else read,
            }

            conv_id = (f"g:{conv['groupId']}" if conv["kind"] == "group"
                       else f"d:{conv['number']}")
            threads.setdefault(conv_id, []).append(msg)
            metas[conv_id] = conv

        # ── Trim, then shape into the store's format ──────────────────
        convs = []
        for conv_id, msgs in threads.items():
            msgs.sort(key=lambda m: m["ts"])
            if args.limit > 0 and len(msgs) > args.limit:
                threads[conv_id] = msgs = msgs[-args.limit:]
            meta = metas[conv_id]
            last = msgs[-1]
            convs.append({
                "id": conv_id, "kind": meta["kind"], "number": meta["number"],
                "groupId": meta["groupId"], "name": meta["name"],
                "lastTs": last["ts"],
                "lastText": last["text"] or ("\U000f0214 Attachment" if last["atts"] else ""),
                "unread": 0, "typing": False,
            })

        total = sum(len(v) for v in threads.values())
        print(f"conversations: {len(convs)}   messages: {total}"
              f"   (skipped {skipped} unaddressable)")
        for conv in sorted(convs, key=lambda c: -c["lastTs"])[:10]:
            print(f"  {len(threads[conv['id']]):>5}  {conv['kind']:<5}  {conv['name']}")
        if len(convs) > 10:
            print(f"  ... and {len(convs) - 10} more")

        if args.dry_run:
            print("\ndry run: nothing written")
            return

        # ── Merge with whatever the shell already has ─────────────────
        existing = {"version": 1, "convs": [], "threads": {}}
        if os.path.exists(STORE):
            shutil.copy2(STORE, STORE + ".bak")
            print(f"\nbacked up existing store to {STORE}.bak")
            try:
                with open(STORE) as fh:
                    existing = json.load(fh)
            except (OSError, ValueError):
                print("warning: existing store unreadable, starting fresh")

        merged_threads = dict(threads)
        for conv_id, live in (existing.get("threads") or {}).items():
            imported = merged_threads.setdefault(conv_id, [])
            # A live message and its imported twin share a send timestamp; the
            # live one has receipts the database copy may not.
            seen = {(m["ts"], m["outgoing"]) for m in live}
            kept = [m for m in imported if (m["ts"], m["outgoing"]) not in seen]
            merged = kept + live
            merged.sort(key=lambda m: m["ts"])
            merged_threads[conv_id] = merged

        by_id = {c["id"]: c for c in convs}
        for conv in existing.get("convs") or []:
            if conv["id"] in by_id:
                # Keep the live record: its unread count and last message are
                # newer than anything the database snapshot knows.
                by_id[conv["id"]] = conv
            else:
                by_id[conv["id"]] = conv
        for conv_id, msgs in merged_threads.items():
            if conv_id in by_id and msgs:
                last = msgs[-1]
                if last["ts"] > by_id[conv_id].get("lastTs", 0):
                    by_id[conv_id]["lastTs"] = last["ts"]
                    by_id[conv_id]["lastText"] = last["text"] or (
                        "\U000f0214 Attachment" if last["atts"] else "")

        out = {
            "version": 1,
            "convs": sorted(by_id.values(), key=lambda c: -c.get("lastTs", 0)),
            "threads": merged_threads,
        }
        os.makedirs(os.path.dirname(STORE), exist_ok=True)
        tmp = STORE + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(out, fh)
        os.replace(tmp, STORE)
        size = os.path.getsize(STORE) / 1024 / 1024
        print(f"wrote {STORE} ({size:.1f} MB, "
              f"{sum(len(v) for v in merged_threads.values())} messages)")
    finally:
        # The decrypted copy must not outlive the run.
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
