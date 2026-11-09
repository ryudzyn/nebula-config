#!/usr/bin/env python3
"""local.py: run arena phases on a local model instead of Claude sub-agents.

    python3 local.py run <spawn|attack|defend> [--parallel 4] [--effort medium]
    python3 local.py check                  # is the local server up?

Run `bracket.py prompts <phase>` first: local.py reads the same briefs, so every
competitor still gets the task byte for byte the same. The local model has no tools,
so the files a brief points to (solutions, attacks, the baseline) are pasted under it,
and the model replies with the file content instead of writing the file. Judges are
never run here: they stay on Claude.

Server: llama-server's OpenAI API (crew/claude/local-llm.sh, `local-llm start`).
Python 3.8+, standard library only.
"""
import argparse
import concurrent.futures
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bracket  # noqa: E402

URL = os.environ.get("ARENA_LOCAL_URL", "http://127.0.0.1:8090")
LOCAL_PHASES = ("spawn", "attack", "defend")
DEF_MARK, SOL_MARK = "=====DEFENSE=====", "=====SOLUTION====="
MAX_FILE = 60000  # chars per pasted file, so one huge solution can't eat the context

NOTE_ONE = """
=== LOCAL MODE ===
You have no tools: you cannot read or write files. The files named above are pasted
below. Do not write the reply line the brief asks for (DONE/ATTACKED). Reply with
exactly the content that belongs in the output file, and nothing else.
"""
NOTE_DEFEND = """
=== LOCAL MODE ===
You have no tools: you cannot read or write files. The files named above are pasted
below. Do not write the DEFENDED reply line. Reply in exactly this shape and nothing else:
%s
<your point-by-point defense>
%s
<your complete revised solution>
""" % (DEF_MARK, SOL_MARK)


def server_up():
    try:
        with urllib.request.urlopen(URL + "/health", timeout=3) as r:
            return r.status == 200
    except (urllib.error.URLError, OSError):
        return False


def pasted_files(prompt, outputs, root):
    """Every existing file under the run folder that the brief names, except its own outputs."""
    seen, parts = set(), []
    for path in re.findall(r"(/[^\s'\"`)]+)", prompt):
        path = path.rstrip(".,:;")
        if path in seen or path in outputs or not path.startswith(root) or not os.path.isfile(path):
            continue
        seen.add(path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            body = fh.read()
        if len(body) > MAX_FILE:
            body = body[:MAX_FILE] + "\n[... cut: file longer than %d characters]" % MAX_FILE
        parts.append("=== FILE %s ===\n%s\n=== END OF FILE ===" % (path, body.strip()))
    return "\n\n".join(parts) if parts else "(no files to paste)"


def ask(messages, effort, max_tokens):
    body = json.dumps({
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 1.0,
        "chat_template_kwargs": {"reasoning_effort": effort},
    }).encode()
    req = urllib.request.Request(URL + "/v1/chat/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=1800) as r:
        data = json.load(r)
    return (data["choices"][0]["message"].get("content") or "").strip()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text.rstrip() + "\n")
    os.replace(tmp, path)


def run_job(job, root, effort, max_tokens):
    with open(job["prompt"], encoding="utf-8") as fh:
        prompt = fh.read()
    defend = job["kind"] == "defender"
    full = "%s\n%s\n%s" % (prompt, NOTE_DEFEND if defend else NOTE_ONE,
                            pasted_files(prompt, job["outputs"], root))
    for attempt in (1, 2):
        try:
            out = ask([{"role": "user", "content": full}], effort, max_tokens)
        except (urllib.error.URLError, OSError, KeyError, ValueError) as e:
            err = str(e)
            continue
        if not out:
            err = "empty reply"
            continue
        if not defend:
            write(job["outputs"][0], out)
            return job["id"], "ok", len(out.split())
        if DEF_MARK in out and SOL_MARK in out:
            defense, solution = out.split(SOL_MARK, 1)
            defense = defense.split(DEF_MARK, 1)[1]
            if defense.strip() and solution.strip():
                write(job["outputs"][0], defense)
                write(job["outputs"][1], solution)
                return job["id"], "ok", len(solution.split())
        err = "reply without the %s / %s markers" % (DEF_MARK, SOL_MARK)
    return job["id"], "FAILED: " + err, 0


def cmd_run(args):
    if args.phase not in LOCAL_PHASES:
        sys.exit("local.py runs only %s; judges stay on Claude" % ", ".join(LOCAL_PHASES))
    if not server_up():
        sys.exit("local model is not running at %s. Start it: local-llm start" % URL)
    state = bracket.load_state(args)
    root = state["dir"]
    jobs = bracket.missing_jobs(bracket.phase_jobs(state, args.phase))
    missing_prompts = [j["id"] for j in jobs if not os.path.isfile(j["prompt"])]
    if missing_prompts:
        sys.exit("no briefs yet. Run: python3 bracket.py prompts %s" % args.phase)
    if not jobs:
        print("nothing to run: every %s output is already there" % args.phase)
        return
    print("%s: %d jobs on the local model, %d at a time" % (args.phase, len(jobs), args.parallel), flush=True)
    t0, failed = time.time(), []
    with concurrent.futures.ThreadPoolExecutor(args.parallel) as pool:
        futs = [pool.submit(run_job, j, root, args.effort, args.max_tokens) for j in jobs]
        for n, f in enumerate(concurrent.futures.as_completed(futs), 1):
            jid, status, words = f.result()
            if status != "ok":
                failed.append(jid)
            print("[%d/%d] %s %s%s" % (n, len(jobs), jid, status, " (%d words)" % words if words else ""),
                  flush=True)
    print("done in %.0f s, %d failed%s" % (time.time() - t0, len(failed),
                                           ": " + " ".join(failed) if failed else ""))


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="run one phase's missing jobs on the local model")
    r.add_argument("phase")
    r.add_argument("--dir")
    r.add_argument("--parallel", type=int, default=4, help="must not exceed the server's --parallel")
    r.add_argument("--effort", default="medium", choices=("low", "medium", "high"))
    r.add_argument("--max-tokens", type=int, default=8000)
    r.set_defaults(func=cmd_run)
    c = sub.add_parser("check", help="is the local model up?")
    c.set_defaults(func=lambda a: print("up at " + URL if server_up() else "not running at " + URL))
    args = p.parse_args()
    try:
        args.func(args)
    except bracket.ArenaError as e:
        sys.exit("arena: %s" % e)


if __name__ == "__main__":
    main()
