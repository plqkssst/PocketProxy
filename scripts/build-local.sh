#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SING_BOX_TAG="${SING_BOX_TAG:-v1.14.3}"
RUNESTONE_COMMIT="${RUNESTONE_COMMIT:-baeb3cbf8332d26b4f7b4c175a01f288ebbf3e7f}"
BASE_PACKAGE_IDENTIFIER="${BASE_PACKAGE_IDENTIFIER:-io.github.plqkssst.pocketproxy}"
APP_PRODUCT="sing-box"
WORK="${WORK:-$REPO_ROOT/build/work}"

command -v xcodebuild >/dev/null 2>&1 || {
	echo "error: xcodebuild not found - iOS builds require macOS with Xcode" >&2
	exit 1
}

mkdir -p "$WORK"

if [ ! -d "$WORK/sing-box" ]; then
	git clone --depth 1 --branch "$SING_BOX_TAG" \
		https://github.com/SagerNet/sing-box.git "$WORK/sing-box"
fi

if [ ! -f "$REPO_ROOT/Frameworks/Runestone/Package.swift" ]; then
	rm -rf "$REPO_ROOT/Frameworks/Runestone"
	git clone https://github.com/nekohasekai/Runestone.git "$REPO_ROOT/Frameworks/Runestone"
	git -C "$REPO_ROOT/Frameworks/Runestone" checkout "$RUNESTONE_COMMIT"
fi

if [ ! -d "$REPO_ROOT/Libbox.xcframework" ]; then
	echo "==> building Libbox.xcframework"
	(
		cd "$WORK/sing-box"
		make lib_install
		export PATH="$PATH:$(go env GOPATH)/bin"
		GOTOOLCHAIN=local go run ./cmd/internal/build_libbox -target apple -platform ios
		rm -rf "$REPO_ROOT/Libbox.xcframework"
		cp -R Libbox.xcframework "$REPO_ROOT/"
	)
fi

echo "==> building SFI"
xcodebuild build \
	-project sing-box.xcodeproj \
	-scheme SFI \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-derivedDataPath "$WORK/dd" \
	-skipPackagePluginValidation \
	-skipMacroValidation \
	BASE_PACKAGE_IDENTIFIER="$BASE_PACKAGE_IDENTIFIER" \
	IPHONEOS_DEPLOYMENT_TARGET=16.0 \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGN_IDENTITY="" \
	ENABLE_BITCODE=NO
