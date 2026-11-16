#!/usr/bin/env python3
"""Reopen Claude Code sessions that were killed by the last shutdown/reboot.

Every Claude process flushes its transcript as it dies, so the sessions that
were still open when the machine went down are the transcripts written between
the shutdown and the next boot. Each one is resumed in its own tmux
window, grouped into a tmux session named after the directory it was started in.

With --since, instead revive every non-live session whose transcript was written
at or after the given time (e.g. "14:30", "2026-11-09 18:00", "2h", "1d").

Usage: revive-sessions.py [--dry-run] [--window MINUTES | --since TIME]
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import time

PROJECTS = os.path.expanduser("~/.claude/projects")
REGISTRY = os.path.expanduser("~/.claude/sessions")


def boot_time():
    out = subprocess.run(["sysctl", "-n", "kern.boottime"], capture_output=True, text=True).stdout
    return int(re.search(r"sec = (\d+)", out).group(1))


def shutdown_time(boot):
    """Last recorded shutdown before this boot (minute precision), or None after a crash."""
    out = subprocess.run(["last", "reboot", "shutdown"], capture_output=True, text=True).stdout
    match = re.search(r"shutdown time\s+(\w{3} \w{3}\s+\d+ \d\d:\d\d)", out)
    if not match:
        return None
    # `last` omits the year; take the most recent one that lands before boot.
    year = time.localtime(boot).tm_year
    for y in (year, year - 1):
        t = time.mktime(time.strptime(f"{match.group(1)} {y}", "%a %b %d %H:%M %Y"))
        if t <= boot:
            return t
    return None


def live_session_ids():
    ids = set()
    for f in glob.glob(f"{REGISTRY}/*.json"):
        try:
            entry = json.load(open(f))
            os.kill(entry["pid"], 0)
            ids.add(entry["sessionId"])
        except (OSError, ValueError, KeyError):
            pass
    return ids


def launch_cwd(transcript):
    for line in open(transcript, errors="ignore"):
        if '"cwd"' in line:
            try:
                return json.loads(line)["cwd"]
            except (ValueError, KeyError):
                continue
    return None


def parse_since(value):
    """Epoch seconds for an absolute time ("HH:MM", ISO date/datetime) or a relative one ("90m", "2h", "1d")."""
    rel = re.fullmatch(r"(\d+(?:\.\d+)?)\s*([smhd])", value.strip())
    if rel:
        unit = {"s": 1, "m": 60, "h": 3600, "d": 86400}[rel.group(2)]
        return time.time() - float(rel.group(1)) * unit
    try:
        clock = datetime.datetime.strptime(value.strip(), "%H:%M").time()
    except ValueError:
        pass
    else:
        t = datetime.datetime.combine(datetime.date.today(), clock)
        if t > datetime.datetime.now():  # a clock time later than now means yesterday
            t -= datetime.timedelta(days=1)
        return t.timestamp()
    try:
        return datetime.datetime.fromisoformat(value.strip()).timestamp()
    except ValueError:
        raise argparse.ArgumentTypeError(f"unrecognised time: {value!r}")


def transcripts():
    # Top level only: */subagents/* transcripts belong to their parent session.
    return [(os.path.getmtime(f), f) for f in glob.glob(f"{PROJECTS}/*/*.jsonl")]


def resumable(candidates):
    live = live_session_ids()
    sessions = []
    for _, f in candidates:
        sid = os.path.basename(f)[: -len(".jsonl")]
        cwd = launch_cwd(f)
        if sid not in live and cwd and os.path.isdir(cwd):
            sessions.append((os.path.basename(cwd).replace(".", "_").replace(":", "_"), cwd, sid))
    return sorted(sessions)


def killed_sessions(window_minutes):
    boot = boot_time()
    before_boot = [(m, f) for m, f in transcripts() if m < boot]
    if not before_boot:
        return []
    # Sessions reopened since boot have newer transcripts, so reruns skip them.
    # Without a shutdown record (crash/panic), anchor on the last pre-boot write.
    anchor = shutdown_time(boot) or max(m for m, _ in before_boot)
    return resumable([(m, f) for m, f in before_boot if m >= anchor - window_minutes * 60])


def sessions_since(since):
    return resumable([(m, f) for m, f in transcripts() if m >= since])


def tmux(*args):
    return subprocess.run(["tmux", *args], capture_output=True, text=True)


def reopen(name, cwd, sid):
    if tmux("has-session", "-t", f"={name}").returncode == 0:
        res = tmux("new-window", "-d", "-P", "-F", "#{pane_id}", "-t", f"={name}:", "-c", cwd)
    else:
        res = tmux("new-session", "-d", "-P", "-F", "#{pane_id}", "-s", name, "-c", cwd)
    if res.returncode != 0:
        raise SystemExit(f"tmux failed for {sid}: {res.stderr.strip()}")
    tmux("send-keys", "-t", res.stdout.strip(), f"claude --resume {sid}", "Enter")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="list sessions without opening them")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--window", type=float, default=3, help="minutes before the shutdown to include (default 3)")
    mode.add_argument("--since", type=parse_since, metavar="TIME",
                      help='revive every session written at/after TIME: "14:30", "2026-11-09 18:00", "2h", "1d"')
    args = parser.parse_args()

    if args.since is not None:
        print(f"Sessions since {time.strftime('%Y-%m-%d %H:%M', time.localtime(args.since))}:")
        sessions = sessions_since(args.since)
    else:
        sessions = killed_sessions(args.window)
    if not sessions:
        print("No killed sessions found.")
        return
    for name, cwd, sid in sessions:
        print(f"{name:32} {sid}  {cwd}")
        if not args.dry_run:
            reopen(name, cwd, sid)
    print(f"{'Would reopen' if args.dry_run else 'Reopened'} {len(sessions)} session(s).")


if __name__ == "__main__":
    main()
