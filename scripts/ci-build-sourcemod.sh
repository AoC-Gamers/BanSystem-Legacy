#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
ARTIFACT_DIR="$DIST_DIR/artifact"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

PROJECT_INCLUDE_FILES=(
  "bansystem_core.inc"
  "bansystem_access.inc"
  "bansystem_comm.inc"
  "bansystem_sprays.inc"
  "bansystem_adminsync.inc"
  "bansystem_shared.inc"
)

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
SOURCEMOD_INCLUDE_DIR="$SOURCEMOD_DIR/addons/sourcemod/scripting/include"
LOCAL_INCLUDE_DIR="$ROOT_DIR/addons/sourcemod/scripting/include"
PACKAGE_SM_DIR="$ARTIFACT_DIR/addons/sourcemod"
PACKAGE_PLUGIN_DIR="$PACKAGE_SM_DIR/plugins/bansystem"
COMPILE_LOG="$ARTIFACT_DIR/compile.log"

mkdir -p "$PACKAGE_PLUGIN_DIR"
: > "$COMPILE_LOG"

compile_plugin() {
  local source_file="$1"
  local output_file="$2"

  echo "Compiling $(basename "$source_file")..."
  "$SPCOMP_BIN" \
    "$source_file" \
    -i"$LOCAL_INCLUDE_DIR" \
    -i"$SOURCEMOD_INCLUDE_DIR" \
    -o"$output_file" \
    2>&1 | tee -a "$COMPILE_LOG"
}

compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_core.sp" "$PACKAGE_PLUGIN_DIR/bansystem_core.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_access.sp" "$PACKAGE_PLUGIN_DIR/bansystem_access.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_comm.sp" "$PACKAGE_PLUGIN_DIR/bansystem_comm.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_sprays.sp" "$PACKAGE_PLUGIN_DIR/bansystem_sprays.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_sprays_view.sp" "$PACKAGE_PLUGIN_DIR/bansystem_sprays_view.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_adminsync.sp" "$PACKAGE_PLUGIN_DIR/bansystem_adminsync.smx"
compile_plugin "$ROOT_DIR/addons/sourcemod/scripting/bansystem_adminmenu.sp" "$PACKAGE_PLUGIN_DIR/bansystem_adminmenu.smx"

for plugin in \
  bansystem_core.smx \
  bansystem_access.smx \
  bansystem_comm.smx \
  bansystem_sprays.smx \
  bansystem_sprays_view.smx \
  bansystem_adminsync.smx \
  bansystem_adminmenu.smx
do
  if [[ ! -f "$PACKAGE_PLUGIN_DIR/$plugin" ]]; then
    echo "Compiled plugin was not generated: $plugin" >&2
    exit 1
  fi
done

PACKAGE_SCRIPTING_DIR="$PACKAGE_SM_DIR/scripting"
PACKAGE_INCLUDE_DIR="$PACKAGE_SCRIPTING_DIR/include"
PACKAGE_TRANSLATIONS_DIR="$PACKAGE_SM_DIR/translations"

mkdir -p "$PACKAGE_SCRIPTING_DIR" "$PACKAGE_INCLUDE_DIR" "$PACKAGE_TRANSLATIONS_DIR" "$PACKAGE_SM_DIR/configs"

cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_core.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_access.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_comm.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_sprays.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_sprays_view.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_adminsync.sp" "$PACKAGE_SCRIPTING_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/bansystem_adminmenu.sp" "$PACKAGE_SCRIPTING_DIR/"

cp -R "$ROOT_DIR/addons/sourcemod/scripting/bansystem_core" "$PACKAGE_SCRIPTING_DIR/"
cp -R "$ROOT_DIR/addons/sourcemod/scripting/bansystem_access" "$PACKAGE_SCRIPTING_DIR/"
cp -R "$ROOT_DIR/addons/sourcemod/scripting/bansystem_comm" "$PACKAGE_SCRIPTING_DIR/"
cp -R "$ROOT_DIR/addons/sourcemod/scripting/bansystem_sprays" "$PACKAGE_SCRIPTING_DIR/"
cp -R "$ROOT_DIR/addons/sourcemod/scripting/bansystem_adminsync" "$PACKAGE_SCRIPTING_DIR/"

for include_file in "${PROJECT_INCLUDE_FILES[@]}"
do
  cp "$ROOT_DIR/addons/sourcemod/scripting/include/$include_file" "$PACKAGE_INCLUDE_DIR/"
done

cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_core.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_access.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_comm.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_sprays.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_sprays_view.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_adminsync.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"
cp "$ROOT_DIR/addons/sourcemod/translations/bansystem_adminmenu.phrases.txt" "$PACKAGE_TRANSLATIONS_DIR/"

mkdir -p "$PACKAGE_SM_DIR/configs/sql-init-bansystem"
cp -R "$ROOT_DIR/addons/sourcemod/configs/sql-init-bansystem/mysql" "$PACKAGE_SM_DIR/configs/sql-init-bansystem/"

for packaged_include in "$PACKAGE_INCLUDE_DIR"/*.inc
do
  packaged_name="$(basename "$packaged_include")"
  is_allowed="false"
  for allowed_include in "${PROJECT_INCLUDE_FILES[@]}"
  do
    if [[ "$packaged_name" == "$allowed_include" ]]; then
      is_allowed="true"
      break
    fi
  done

  if [[ "$is_allowed" != "true" ]]; then
    echo "Unexpected external include in packaged artifact: $packaged_name" >&2
    exit 1
  fi
done

echo "SourceMod artifacts generated in $ARTIFACT_DIR"
