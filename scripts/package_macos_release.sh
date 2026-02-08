#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${1:-mochi}"
APP_BUNDLE_NAME="Mochi"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/mochi.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
STAGING_PATH="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/Mochi.dmg"
EXPORT_OPTIONS_PLIST="$ROOT_DIR/ExportOptions.plist"
ARCHIVE_APP_PATH="$ARCHIVE_PATH/Products/Applications/mochi.app"
ARCHIVE_BACKEND_PATH="$ARCHIVE_APP_PATH/Contents/Resources/backend"
BACKEND_SOURCE_PATH="$ROOT_DIR/backend"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
	echo "Missing $EXPORT_OPTIONS_PLIST"
	exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
	echo "Missing create-dmg. Install it first (e.g. brew install create-dmg)."
	exit 1
fi

echo "Cleaning old build artifacts..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$STAGING_PATH"
rm -f "$BUILD_DIR"/*.dmg

echo "Archiving app..."
xcodebuild \
	-scheme "$SCHEME" \
	-configuration Release \
	-archivePath "$ARCHIVE_PATH" \
	archive

if [[ ! -d "$ARCHIVE_APP_PATH" ]]; then
	echo "Archive succeeded but app was not found at $ARCHIVE_APP_PATH"
	exit 1
fi

echo "Embedding backend into archive..."
mkdir -p "$ARCHIVE_BACKEND_PATH"
rsync -a --delete \
	--exclude "__pycache__" \
	--exclude ".pytest_cache" \
	--exclude ".mypy_cache" \
	--exclude "*.pyc" \
	--exclude ".DS_Store" \
	"$BACKEND_SOURCE_PATH/" \
	"$ARCHIVE_BACKEND_PATH/"

VENV_BIN_PATH="$ARCHIVE_BACKEND_PATH/.venv/bin"
if [[ -L "$VENV_BIN_PATH/python" ]]; then
	PYTHON_LINK_TARGET="$(readlink "$VENV_BIN_PATH/python")"
	if [[ "$PYTHON_LINK_TARGET" = /* && -x "$PYTHON_LINK_TARGET" ]]; then
		rm "$VENV_BIN_PATH/python"
		cp "$PYTHON_LINK_TARGET" "$VENV_BIN_PATH/python"
		chmod +x "$VENV_BIN_PATH/python"
		ln -sf python "$VENV_BIN_PATH/python3"
		ln -sf python "$VENV_BIN_PATH/python3.11"
	fi
fi

if [[ ! -x "$ARCHIVE_BACKEND_PATH/.venv/bin/python3" && ! -x "$ARCHIVE_BACKEND_PATH/.venv/bin/python" ]]; then
	echo "Warning: backend/.venv python runtime was not found in the archive."
	echo "The installed app may fail to auto-start backend dependencies."
fi

APP_SOURCE_PATH=""
echo "Exporting signed app..."
if xcodebuild \
	-exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS_PLIST"; then
	EXPORTED_APP_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -type d -name '*.app' | head -n 1)"
	if [[ -z "${EXPORTED_APP_PATH}" ]]; then
		echo "No exported .app found in $EXPORT_PATH"
		exit 1
	fi
	APP_SOURCE_PATH="$EXPORTED_APP_PATH"
else
	echo "Warning: exportArchive failed. Falling back to archive app with ad-hoc signing."
	codesign --force --deep --sign - --timestamp=none "$ARCHIVE_APP_PATH"
	APP_SOURCE_PATH="$ARCHIVE_APP_PATH"
fi

echo "Preparing DMG staging..."
mkdir -p "$STAGING_PATH"
cp -R "$APP_SOURCE_PATH" "$STAGING_PATH/$APP_BUNDLE_NAME.app"

echo "Creating DMG at $DMG_PATH ..."
create-dmg \
	--volname "Mochi Installer" \
	--volicon "$ROOT_DIR/mochi/mochi.icns" \
	--window-pos 200 120 \
	--window-size 800 400 \
	--icon-size 100 \
	--icon "$APP_BUNDLE_NAME.app" 200 185 \
	--app-drop-link 600 185 \
	"$DMG_PATH" \
	"$STAGING_PATH/$APP_BUNDLE_NAME.app"

echo "Done: $DMG_PATH"
