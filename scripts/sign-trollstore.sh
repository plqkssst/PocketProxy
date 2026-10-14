#!/bin/bash
set -euo pipefail

APP="${1:?usage: sign-trollstore.sh <path-to-.app> <entitlements-dir>}"
ENT="${2:?usage: sign-trollstore.sh <path-to-.app> <entitlements-dir>}"

command -v ldid >/dev/null 2>&1 || {
	echo "error: ldid not found (brew install ldid)" >&2
	exit 1
}

MAIN="sing-box"

SIGN_TABLE="\
PlugIns/Extension.appex/Extension|Extension.plist
PlugIns/FileProviderExtension.appex/FileProviderExtension|fileprovider.plist
PlugIns/WidgetExtension.appex/WidgetExtension|widget.plist
PlugIns/ShareExtension.appex/ShareExtension|share.plist
Extensions/IntentsExtension.appex/IntentsExtension|intents.plist"

rm -rf "$APP/_CodeSignature" "$APP/SC_Info" "$APP/embedded.mobileprovision"

is_entitled() {
	[[ "$1" == "$APP/$MAIN" ]] && return 0
	local rel
	while IFS='|' read -r rel _; do
		[[ -n "$rel" && "$1" == "$APP/$rel" ]] && return 0
	done <<<"$SIGN_TABLE"
	return 1
}

while IFS= read -r macho; do
	is_entitled "$macho" && continue
	ldid -S "$macho"
done < <(find "$APP" -type f -perm +111 -exec sh -c 'file -b "$1" | grep -q "Mach-O" && echo "$1"' _ {} \;)

while IFS='|' read -r rel ent; do
	[[ -z "$rel" ]] && continue
	if [[ -f "$APP/$rel" ]]; then
		ldid -S"$ENT/$ent" "$APP/$rel"
	else
		echo "skip $rel (not built)"
	fi
done <<<"$SIGN_TABLE"

ldid -S"$ENT/App.plist" "$APP/$MAIN"

echo "signed with ldid:"
ldid -e "$APP/$MAIN" | head -20
