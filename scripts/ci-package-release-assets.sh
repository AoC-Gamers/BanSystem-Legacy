#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
SOURCEMOD_ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"
RELEASE_VERSION="${RELEASE_VERSION:-latest}"
RELEASE_NAME="bansystem-${RELEASE_VERSION}.zip"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

if [[ ! -d "$SOURCEMOD_ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $SOURCEMOD_ARTIFACT_DIR" >&2
  exit 1
fi

python3 - "$SOURCEMOD_ARTIFACT_DIR" "$RELEASE_DIR/$RELEASE_NAME" "$ROOT_DIR" <<'PY'
import os
import sys
import zipfile

src_dir, out_file, repo_dir = sys.argv[1], sys.argv[2], sys.argv[3]

with zipfile.ZipFile(out_file, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(src_dir):
        dirs.sort()
        files.sort()
        rel_root = os.path.relpath(root, src_dir)
        if rel_root != "." and not dirs and not files:
            zf.writestr(rel_root.rstrip("/") + "/", "")
        for name in files:
            path = os.path.join(root, name)
            arcname = os.path.relpath(path, src_dir)
            if arcname == "compile.log":
                continue
            zf.write(path, arcname)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        zf.write(os.path.join(repo_dir, name), name)
PY

echo "Release assets generated in $RELEASE_DIR"
