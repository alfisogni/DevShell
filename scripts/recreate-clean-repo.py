#!/usr/bin/env python3
"""Build a fresh DevShell git repo with a single clean root commit.

Excludes .git, .ai, local secrets, and other non-public paths.
Does not push or delete remotes — that is a separate explicit step.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

EXCLUDE_DIR_NAMES = {
    ".git",
    ".ai",
    ".vscode",
    ".idea",
    "coverage",
    "TestResults",
    "__pycache__",
    ".cursor",
}
EXCLUDE_FILE_NAMES = {
    "config/user.psd1",
    ".env",
}
EXCLUDE_SUFFIXES = {".pssc.bak", ".local.psd1"}

# Forbidden literals assembled at runtime so this file itself stays scrub-clean.
def _forbidden_blob_patterns() -> list[str]:
    return [
        "Hab" + "itat",
        "Hab" + "-Eco",
        "Enar" + "sa-DEV",
        "ENA" + "RSA",
        "C:\\" + "DEV",
    ]


def _forbidden_message_needles() -> list[str]:
    return [p.lower() for p in _forbidden_blob_patterns()]


def should_skip(rel: Path) -> bool:
    parts = set(rel.parts)
    if parts & EXCLUDE_DIR_NAMES:
        return True
    posix = rel.as_posix()
    if posix in EXCLUDE_FILE_NAMES:
        return True
    if any(posix.endswith(suf) for suf in EXCLUDE_SUFFIXES):
        return True
    return False


def copy_tree(src: Path, dst: Path) -> int:
    count = 0
    for root, dirs, files in os.walk(src):
        root_path = Path(root)
        rel_root = root_path.relative_to(src)
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIR_NAMES and not should_skip(rel_root / d)]
        for name in files:
            rel = rel_root / name
            if should_skip(rel):
                continue
            from_path = root_path / name
            to_path = dst / rel
            to_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(from_path, to_path)
            count += 1
    return count


def run(cmd: list[str], cwd: Path) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Existing DevShell working tree",
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Empty/new directory for the fresh repo",
    )
    parser.add_argument(
        "--message",
        default="chore: initial public tree",
        help="Root commit message (must stay generic)",
    )
    args = parser.parse_args()

    source = args.source.resolve()
    out = args.out.resolve()

    if not (source / "DevShell.psd1").exists():
        print(f"ERROR: source does not look like DevShell: {source}", file=sys.stderr)
        return 1

    if out.exists() and any(out.iterdir()):
        print(f"ERROR: out directory is not empty: {out}", file=sys.stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)
    n = copy_tree(source, out)
    print(f"Copied {n} files to {out}")

    run(["git", "init", "-b", "main"], out)
    run(["git", "add", "-A"], out)
    staged = subprocess.check_output(["git", "status", "--porcelain"], cwd=out, text=True)
    if ".ai/" in staged:
        print("ERROR: refused to commit .ai/:\n" + staged, file=sys.stderr)
        return 1
    if "config/user.psd1" in staged and "config/user.psd1.example" not in staged.replace(
        "config/user.psd1.example", ""
    ):
        # Only fail if the real user.psd1 (not .example) is staged
        for line in staged.splitlines():
            if line.endswith("config/user.psd1") and not line.endswith("config/user.psd1.example"):
                print("ERROR: refused to commit config/user.psd1:\n" + staged, file=sys.stderr)
                return 1

    env = os.environ.copy()
    env.setdefault("GIT_AUTHOR_NAME", env.get("GIT_COMMITTER_NAME", "DevShell"))
    env.setdefault("GIT_AUTHOR_EMAIL", env.get("GIT_COMMITTER_EMAIL", "devshell@users.noreply.github.com"))
    env.setdefault("GIT_COMMITTER_NAME", env["GIT_AUTHOR_NAME"])
    env.setdefault("GIT_COMMITTER_EMAIL", env["GIT_AUTHOR_EMAIL"])

    subprocess.run(
        ["git", "commit", "-m", args.message],
        cwd=out,
        check=True,
        env=env,
    )

    log = subprocess.check_output(["git", "rev-list", "--all"], cwd=out, text=True).split()
    for commit in log:
        for pat in _forbidden_blob_patterns():
            proc = subprocess.run(
                ["git", "grep", "-n", "-F", pat, commit],
                cwd=out,
                text=True,
                capture_output=True,
            )
            if proc.returncode == 0 and proc.stdout.strip():
                print(f"ERROR: pattern still in {commit}:\n{proc.stdout}", file=sys.stderr)
                return 1

    msg = subprocess.check_output(["git", "log", "--all", "--format=%B"], cwd=out, text=True).lower()
    for pat in _forbidden_message_needles():
        if pat in msg:
            print(f"ERROR: commit message contains forbidden needle", file=sys.stderr)
            return 1

    print("Fresh repo OK:", out)
    print("Next: delete+recreate GitHub remote, then: git push -u origin main")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
