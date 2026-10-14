#!/bin/bash
set -euo pipefail

BASE="${1:?usage: make-entitlements.sh <base-package-identifier> <output-dir>}"
OUT="${2:?usage: make-entitlements.sh <base-package-identifier> <output-dir>}"
TEAM_ID="${TEAM_ID:-P8XK3KHB48}"
APP_GROUP="group.$BASE"

mkdir -p "$OUT"

header() {
	cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
EOF
}

footer() {
	cat <<'EOF'
	<key>get-task-allow</key>
	<false/>
</dict>
</plist>
EOF
}

identity() {
	cat <<EOF
	<key>application-identifier</key>
	<string>$TEAM_ID.$1</string>
	<key>com.apple.developer.team-identifier</key>
	<string>$TEAM_ID</string>
EOF
}

network_extension() {
	cat <<'EOF'
	<key>com.apple.developer.networking.networkextension</key>
	<array>
		<string>packet-tunnel-provider</string>
	</array>
EOF
}

app_groups() {
	cat <<EOF
	<key>com.apple.security.application-groups</key>
	<array>
		<string>$APP_GROUP</string>
	</array>
EOF
}

{
	header
	identity "$BASE"
	network_extension
	app_groups
	footer
} >"$OUT/App.plist"

{
	header
	identity "$BASE.extension"
	network_extension
	cat <<'EOF'
	<key>com.apple.developer.networking.wifi-info</key>
	<true/>
	<key>com.apple.developer.networking.multicast</key>
	<true/>
EOF
	app_groups
	footer
} >"$OUT/Extension.plist"

for suffix in fileprovider intents share widget; do
	{
		header
		identity "$BASE.$suffix"
		app_groups
		footer
	} >"$OUT/$suffix.plist"
done

echo "generated entitlements for $BASE (team $TEAM_ID) in $OUT"
ls -1 "$OUT"
