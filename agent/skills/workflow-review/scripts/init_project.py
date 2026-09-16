#!/usr/bin/env python3
"""Copy a standalone review project without overwriting existing work."""
import argparse
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    dest = args.destination.expanduser().absolute()
    if dest.exists() or dest.is_symlink():
        parser.error(f"Destination already exists; choose a new directory: {dest}")
    skill = Path(__file__).resolve().parents[1]
    starter = skill / "assets/starter"
    picker = skill / "assets/element-feedback"
    if not (starter / "public/index.html").is_file() or not (picker / "element-feedback.js").is_file():
        parser.error("Skill assets are incomplete")
    shutil.copytree(starter, dest, ignore=shutil.ignore_patterns(".data", "node_modules", ".wrangler", "__pycache__"))
    shutil.copytree(picker, dest / "public/element-feedback", ignore=shutil.ignore_patterns("node_modules", "__pycache__"))
    print(f"Created: {dest}")
    print("Run from that directory: node local/server.mjs")
    print("Local URL: http://127.0.0.1:4173/")
    print("No cloud resources were created or deployed.")


if __name__ == "__main__":
    main()
