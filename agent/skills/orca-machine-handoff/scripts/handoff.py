#!/usr/bin/env python3
"""Create and restore reviewable Git handoff packets; optionally transfer over a tailnet."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import http.server
import ipaddress
import json
import os
from pathlib import Path, PurePosixPath
import secrets
import shutil
import socketserver
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile


SCHEMA = 1
MAX_PACKET_BYTES = 2 * 1024 * 1024 * 1024


class HandoffError(Exception):
    pass


def git(repo: Path, *args: str, input_data: bytes | None = None) -> bytes:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args], input=input_data, capture_output=True
    )
    if proc.returncode:
        raise HandoffError(f"git {' '.join(args)} failed: {proc.stderr.decode(errors='replace').strip()}")
    return proc.stdout


def oid(repo: Path, ref: str) -> str:
    return git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}").decode().strip()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_path(name: str) -> Path:
    path = PurePosixPath(name)
    if not name or path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise HandoffError(f"unsafe packet path: {name!r}")
    return Path(*path.parts)


def sensitive(name: str) -> bool:
    parts = [part.lower() for part in PurePosixPath(name).parts]
    exact = {".ssh", ".aws", ".gnupg", "credentials", "secrets", "id_rsa", "id_ed25519"}
    suffixes = (".pem", ".key", ".p12", ".p8", ".kdbx")
    return any(
        part in exact or part.startswith(".env") or part.endswith(suffixes)
        or part in {"credentials.json", "service-account.json"}
        for part in parts
    )


def safe_link_target(repo: Path, name: str, link: str) -> None:
    if Path(link).is_absolute() or not ((repo / safe_path(name)).parent / link).resolve().is_relative_to(repo):
        raise HandoffError(f"symlink points outside repository: {name}")


def status_paths(repo: Path) -> list[str]:
    raw = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--ignore-submodules=none")
    records = raw.split(b"\0")
    paths: list[str] = []
    index = 0
    while index < len(records) and records[index]:
        record = records[index]
        if len(record) < 4 or record[2:3] != b" ":
            raise HandoffError("could not parse git status")
        paths.append(record[3:].decode("utf-8"))
        if b"R" in record[:2] or b"C" in record[:2]:
            index += 1
            paths.append(records[index].decode("utf-8"))
        index += 1
    return paths


def ensure_repo(path: str) -> Path:
    repo = Path(path).expanduser().resolve()
    root = Path(git(repo, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if root != repo:
        raise HandoffError(f"use the repository root: {root}")
    return repo


def untracked_paths(repo: Path) -> list[str]:
    raw = git(repo, "ls-files", "--others", "--exclude-standard", "-z")
    return sorted(item.decode("utf-8") for item in raw.split(b"\0") if item)


def pack(args: argparse.Namespace) -> None:
    repo = ensure_repo(args.repo)
    output_arg = Path(args.out).expanduser()
    if output_arg.is_symlink():
        raise HandoffError(f"packet output is a symlink: {output_arg}")
    output = output_arg.resolve()
    note = Path(args.note).expanduser().resolve()
    if output.exists() or output.is_symlink():
        raise HandoffError(f"packet already exists: {output}")
    if not note.is_file():
        raise HandoffError(f"note not found: {note}")
    head = oid(repo, "HEAD")
    base = oid(repo, args.base_ref)
    base = git(repo, "merge-base", head, base).decode().strip()
    changed = status_paths(repo)
    for name in changed:
        safe_path(name)
    history_paths = [
        name.decode("utf-8") for name in
        git(repo, "log", "--format=", "--name-only", "--no-renames", "-m", "-z", f"{base}..HEAD").split(b"\0")
        if name
    ]
    blocked = sorted({name for name in changed + history_paths if sensitive(name)})
    if blocked:
        raise HandoffError("sensitive paths need separate handling: " + ", ".join(blocked))
    staged_entries = git(repo, "ls-files", "--stage", "-z").split(b"\0")
    submodules = {
        entry.split(b"\t", 1)[1].decode("utf-8")
        for entry in staged_entries if entry.startswith(b"160000 ")
    }
    if submodules:
        raise HandoffError("repositories with submodules need separate handling: " + ", ".join(sorted(submodules)))
    untracked = untracked_paths(repo)
    if output.is_relative_to(repo):
        raise HandoffError("packet must be outside the repository")
    staged = git(repo, "diff", "--cached", "--binary", "--full-index", "HEAD")
    unstaged = git(repo, "diff", "--binary", "--full-index")
    note_data = note.read_bytes()
    manifest: dict = {
        "schema": SCHEMA,
        "head": head,
        "base": base,
        "branch": git(repo, "branch", "--show-current").decode().strip(),
        "changedPaths": sorted(set(changed)),
        "historyPaths": sorted(set(history_paths)),
        "stagedSha256": sha256(staged),
        "unstagedSha256": sha256(unstaged),
        "noteSha256": sha256(note_data),
        "untracked": [],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="handoff-pack-") as temp_dir:
        temp = Path(temp_dir)
        bundle = temp / "commits.bundle"
        if head != base:
            git(repo, "bundle", "create", str(bundle), f"{base}..HEAD")
            manifest["bundleSha256"] = file_hash(bundle)
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".handoff-", suffix=".zip", delete=False) as partial:
            partial_path = Path(partial.name)
        try:
            with zipfile.ZipFile(partial_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                archive.writestr("staged.patch", staged)
                archive.writestr("unstaged.patch", unstaged)
                archive.writestr("note.md", note_data)
                if bundle.exists():
                    archive.write(bundle, "commits.bundle")
                for index, name in enumerate(untracked):
                    relative = safe_path(name)
                    source = repo / relative
                    info = source.lstat()
                    if stat.S_IMODE(info.st_mode) & ~0o777:
                        raise HandoffError(f"unsupported special permission bits: {name}")
                    entry = f"untracked/{index}"
                    if stat.S_ISREG(info.st_mode):
                        archive.write(source, entry)
                        digest = file_hash(source)
                        kind = "file"
                    elif stat.S_ISLNK(info.st_mode):
                        target = os.readlink(source)
                        safe_link_target(repo, name, target)
                        archive.writestr(entry, target.encode())
                        digest = sha256(target.encode())
                        kind = "symlink"
                    else:
                        raise HandoffError(f"unsupported untracked file type: {name}")
                    manifest["untracked"].append({
                        "path": name, "entry": entry, "kind": kind,
                        "mode": stat.S_IMODE(info.st_mode), "sha256": digest,
                    })
                archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2).encode())
            if oid(repo, "HEAD") != head or status_paths(repo) != changed:
                raise HandoffError("source changed while packing; retry from a stable worktree")
            if sha256(git(repo, "diff", "--cached", "--binary", "--full-index", "HEAD")) != manifest["stagedSha256"]:
                raise HandoffError("staged files changed while packing")
            if sha256(git(repo, "diff", "--binary", "--full-index")) != manifest["unstagedSha256"]:
                raise HandoffError("unstaged files changed while packing")
            if untracked_paths(repo) != untracked or note.read_bytes() != note_data:
                raise HandoffError("untracked files or note changed while packing")
            for item in manifest["untracked"]:
                source = repo / safe_path(item["path"])
                digest = file_hash(source) if item["kind"] == "file" else sha256(os.readlink(source).encode())
                if digest != item["sha256"]:
                    raise HandoffError(f"untracked file changed while packing: {item['path']}")
            if partial_path.stat().st_size > MAX_PACKET_BYTES:
                raise HandoffError("packet exceeds 2 GiB limit")
            os.replace(partial_path, output)
        finally:
            partial_path.unlink(missing_ok=True)
    print(json.dumps({"packet": str(output), "sha256": file_hash(output), "head": head,
                      "base": base, "changedPaths": len(changed), "untracked": len(untracked)}, ensure_ascii=False))


@contextmanager
def read_packet(path: Path):
    if path.stat().st_size > MAX_PACKET_BYTES:
        raise HandoffError("packet exceeds 2 GiB limit")
    with zipfile.ZipFile(path) as archive:
        if len(set(archive.namelist())) != len(archive.namelist()):
            raise HandoffError("duplicate packet entry")
        if sum(entry.file_size for entry in archive.infolist()) > MAX_PACKET_BYTES:
            raise HandoffError("expanded packet exceeds 2 GiB limit")
        manifest = json.loads(archive.read("manifest.json"))
        if manifest.get("schema") != SCHEMA:
            raise HandoffError("unsupported packet schema")
        expected = {"manifest.json", "staged.patch", "unstaged.patch", "note.md"}
        if "bundleSha256" in manifest:
            expected.add("commits.bundle")
        seen_paths: set[str] = set()
        for index, item in enumerate(manifest["untracked"]):
            safe_path(item["path"])
            if item["path"] in seen_paths or item["entry"] != f"untracked/{index}":
                raise HandoffError("duplicate or invalid untracked manifest entry")
            seen_paths.add(item["path"])
            if item["kind"] not in ("file", "symlink") or not isinstance(item["mode"], int) or item["mode"] & ~0o777:
                raise HandoffError("invalid untracked file metadata")
            expected.add(item["entry"])
        if set(archive.namelist()) != expected:
            raise HandoffError("unexpected packet entries")
        for entry, digest in (("staged.patch", manifest["stagedSha256"]),
                              ("unstaged.patch", manifest["unstagedSha256"]),
                              ("note.md", manifest["noteSha256"])):
            if sha256(archive.read(entry)) != digest:
                raise HandoffError(f"checksum mismatch: {entry}")
        for item in manifest["untracked"]:
            if sha256(archive.read(item["entry"])) != item["sha256"]:
                raise HandoffError(f"checksum mismatch: {item['path']}")
        if "bundleSha256" in manifest and sha256(archive.read("commits.bundle")) != manifest["bundleSha256"]:
            raise HandoffError("bundle checksum mismatch")
        yield archive, manifest


def inspect(args: argparse.Namespace) -> None:
    packet = Path(args.packet).expanduser().resolve()
    with read_packet(packet) as (_, manifest):
        print(json.dumps({"packet": str(packet), "sha256": file_hash(packet), **manifest}, ensure_ascii=False, indent=2))


def verify_output(repo: Path, archive: zipfile.ZipFile, manifest: dict) -> None:
    if oid(repo, "HEAD") != manifest["head"]:
        raise HandoffError("HEAD differs after restore")
    if sha256(git(repo, "diff", "--cached", "--binary", "--full-index", "HEAD")) != manifest["stagedSha256"]:
        raise HandoffError("staged diff differs after restore")
    if sha256(git(repo, "diff", "--binary", "--full-index")) != manifest["unstagedSha256"]:
        raise HandoffError("unstaged diff differs after restore")
    if untracked_paths(repo) != sorted(item["path"] for item in manifest["untracked"]):
        raise HandoffError("untracked path list differs after restore")
    for item in manifest["untracked"]:
        target = repo / safe_path(item["path"])
        if item["kind"] == "file":
            digest = file_hash(target)
        else:
            digest = sha256(os.readlink(target).encode())
        if digest != item["sha256"]:
            raise HandoffError(f"untracked file differs after restore: {item['path']}")


def restore(args: argparse.Namespace) -> None:
    repo = ensure_repo(args.repo)
    note_arg = Path(args.note_out).expanduser()
    if note_arg.is_symlink():
        raise HandoffError("note output is a symlink")
    note_out = note_arg.resolve()
    if note_out.exists() or note_out.is_relative_to(repo):
        raise HandoffError("note output must be a new path outside the repository")
    if not (repo / ".git").is_file():
        raise HandoffError("restore requires a new linked worktree, not the main checkout")
    if git(repo, "status", "--porcelain=v1", "--untracked-files=all").strip():
        raise HandoffError("restore target must be clean")
    packet = Path(args.packet).expanduser().resolve()
    with read_packet(packet) as (archive, manifest):
        try:
            git(repo, "cat-file", "-e", f"{manifest['base']}^{{commit}}")
        except HandoffError as exc:
            raise HandoffError("target repository lacks packet base commit; fetch the source base first") from exc
        try:
            git(repo, "cat-file", "-e", f"{manifest['head']}^{{commit}}")
        except HandoffError:
            if "bundleSha256" not in manifest:
                raise HandoffError("target repository lacks packet HEAD and no bundle is present")
            with tempfile.NamedTemporaryFile(suffix=".bundle") as bundle:
                bundle.write(archive.read("commits.bundle"))
                bundle.flush()
                if file_hash(Path(bundle.name)) != manifest["bundleSha256"]:
                    raise HandoffError("bundle checksum mismatch")
                git(repo, "bundle", "verify", bundle.name)
                git(repo, "fetch", "--no-tags", bundle.name, manifest["head"])
        git(repo, "switch", "--detach", "--no-overwrite-ignore", manifest["head"])
        staged = archive.read("staged.patch")
        unstaged = archive.read("unstaged.patch")
        if staged:
            git(repo, "apply", "--index", "--binary", "-", input_data=staged)
        if unstaged:
            git(repo, "apply", "--binary", "-", input_data=unstaged)
        for item in manifest["untracked"]:
            target = repo / safe_path(item["path"])
            parent = target.parent
            for ancestor in (parent, *parent.parents):
                if ancestor == repo.parent:
                    break
                if ancestor.is_symlink():
                    raise HandoffError(f"untracked parent is a symlink: {item['path']}")
            if target.exists() or target.is_symlink():
                raise HandoffError(f"untracked target exists: {item['path']}")
            parent.mkdir(parents=True, exist_ok=True)
            data = archive.read(item["entry"])
            if item["kind"] == "file":
                target.write_bytes(data)
                target.chmod(item["mode"])
            elif item["kind"] == "symlink":
                link = data.decode()
                safe_link_target(repo, item["path"], link)
                target.symlink_to(link)
            else:
                raise HandoffError(f"unsupported packet entry type: {item['kind']}")
        verify_output(repo, archive, manifest)
        note_out.parent.mkdir(parents=True, exist_ok=True)
        note_out.write_bytes(archive.read("note.md"))
        print(json.dumps({"restored": str(repo), "head": manifest["head"],
                          "notePath": str(note_out), "noteSha256": manifest["noteSha256"],
                          "status": git(repo, "status", "--short", "--untracked-files=all").decode()}, ensure_ascii=False))


def serve(args: argparse.Namespace) -> None:
    address = ipaddress.ip_address(args.bind)
    if not (address.is_loopback or address in ipaddress.ip_network("100.64.0.0/10")):
        raise HandoffError("serve must bind to a loopback or Tailscale IPv4 address")
    packet = Path(args.packet).expanduser().resolve()
    digest = file_hash(packet)
    token = secrets.token_urlsafe(32)
    deadline = time.monotonic() + args.timeout

    class Handler(http.server.BaseHTTPRequestHandler):
        served = False

        def setup(self) -> None:
            self.request.settimeout(10)
            super().setup()

        def do_GET(self) -> None:
            if self.path != f"/handoff/{token}":
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(packet.stat().st_size))
            self.send_header("X-Content-SHA256", digest)
            self.end_headers()
            try:
                with packet.open("rb") as source:
                    shutil.copyfileobj(source, self.wfile)
                Handler.served = True
            except BrokenPipeError:
                pass

        def log_message(self, _format: str, *_args: object) -> None:
            pass

    with socketserver.TCPServer((args.bind, args.port), Handler) as server:
        server.timeout = 1
        print(json.dumps({"url": f"http://{args.bind}:{server.server_address[1]}/handoff/{token}",
                          "sha256": digest, "expiresInSeconds": args.timeout}), flush=True)
        while not Handler.served and time.monotonic() < deadline:
            server.handle_request()
        if not Handler.served:
            raise HandoffError("transfer timed out without a completed download")


def fetch(args: argparse.Namespace) -> None:
    output_arg = Path(args.out).expanduser()
    if output_arg.is_symlink():
        raise HandoffError(f"output is a symlink: {output_arg}")
    output = output_arg.resolve()
    if output.exists():
        raise HandoffError(f"output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".handoff-fetch-", delete=False) as partial:
        partial_path = Path(partial.name)
        digest = hashlib.sha256()
        size = 0
        try:
            with urllib.request.urlopen(args.url, timeout=30) as response:
                while block := response.read(1024 * 1024):
                    size += len(block)
                    if size > MAX_PACKET_BYTES:
                        raise HandoffError("packet exceeds 2 GiB limit")
                    digest.update(block)
                    partial.write(block)
            if digest.hexdigest() != args.sha256:
                raise HandoffError("download checksum mismatch")
            os.replace(partial_path, output)
        finally:
            partial_path.unlink(missing_ok=True)
    print(json.dumps({"packet": str(output), "sha256": args.sha256, "bytes": size}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("pack")
    p.add_argument("--repo", required=True)
    p.add_argument("--base-ref", required=True)
    p.add_argument("--note", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=pack)
    p = sub.add_parser("inspect")
    p.add_argument("--packet", required=True)
    p.set_defaults(func=inspect)
    p = sub.add_parser("restore")
    p.add_argument("--packet", required=True)
    p.add_argument("--repo", required=True)
    p.add_argument("--note-out", required=True)
    p.set_defaults(func=restore)
    p = sub.add_parser("serve")
    p.add_argument("--packet", required=True)
    p.add_argument("--bind", required=True)
    p.add_argument("--port", type=int, default=0)
    p.add_argument("--timeout", type=int, default=600)
    p.set_defaults(func=serve)
    p = sub.add_parser("fetch")
    p.add_argument("--url", required=True)
    p.add_argument("--sha256", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=fetch)
    args = parser.parse_args()
    try:
        args.func(args)
    except (HandoffError, OSError, KeyError, TypeError, ValueError, zipfile.BadZipFile) as exc:
        print(f"handoff: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
