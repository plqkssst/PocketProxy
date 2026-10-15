import Foundation

// Standalone harness for ShadowLink. The CI compiles this together with
// Library/ShadowLink/ShadowLink.swift using swiftc, so the parser is actually executed
// rather than only type-checked by the Xcode build.
//
//   swiftc -o /tmp/shadowlink-tests Library/ShadowLink/ShadowLink.swift Tools/ShadowLinkTests/main.swift
//   /tmp/shadowlink-tests

var checks = 0
var failures = 0

func check(_ condition: Bool, _ label: String, _ detail: String = "") {
    checks += 1
    if condition {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label)\(detail.isEmpty ? "" : " -- \(detail)")")
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    check(actual == expected, label, "expected \(expected), got \(actual)")
}

@discardableResult
func parseOk(_ link: String, _ label: String) -> ShadowLinkNode? {
    do {
        return try ShadowLink.parse(link)
    } catch {
        check(false, label, "unexpected error: \(error)")
        return nil
    }
}

func expectError(_ link: String, _ expected: ShadowLinkError, _ label: String) {
    checks += 1
    do {
        let node = try ShadowLink.parse(link)
        failures += 1
        print("  FAIL \(label) -- expected \(expected), but parsed \(node)")
    } catch let error as ShadowLinkError {
        if error == expected {
            print("  ok   \(label)")
        } else {
            failures += 1
            print("  FAIL \(label) -- expected \(expected), got \(error)")
        }
    } catch {
        failures += 1
        print("  FAIL \(label) -- unexpected error type \(error)")
    }
}

print("SIP002 shadowsocks")
if let node = parseOk("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Tokyo", "SIP002 padded") {
    checkEqual(node.kind, .shadowsocks, "kind")
    checkEqual(node.method, "aes-256-gcm", "method")
    checkEqual(node.password, "secret", "password")
    checkEqual(node.server, "1.2.3.4", "server")
    checkEqual(node.port, 8388, "port")
    checkEqual(node.tag, "Tokyo", "tag")
    checkEqual(node.plugin, nil, "plugin is nil")
}

print("SIP002 with the URL-safe alphabet and no padding")
if let node = parseOk("ss://YWVzLTI1Ni1nY206Pz4_Pj8-@example.com:443", "url-safe unpadded") {
    checkEqual(node.method, "aes-256-gcm", "method")
    checkEqual(node.password, "?>?>?>", "password")
    checkEqual(node.server, "example.com", "server")
    checkEqual(node.port, 443, "port")
    checkEqual(node.tag, "example.com:443", "tag falls back to host:port")
}

print("legacy fully-encoded form")
if let node = parseOk("ss://YWVzLTI1Ni1nY206c2VjcmV0QDEuMi4zLjQ6ODM4OA==#Legacy", "legacy") {
    checkEqual(node.method, "aes-256-gcm", "method")
    checkEqual(node.password, "secret", "password")
    checkEqual(node.server, "1.2.3.4", "server")
    checkEqual(node.port, 8388, "port")
    checkEqual(node.tag, "Legacy", "tag")
}

print("unencoded userinfo")
if let node = parseOk("ss://aes-256-gcm:secret@1.2.3.4:8388", "plain userinfo") {
    checkEqual(node.method, "aes-256-gcm", "method")
    checkEqual(node.password, "secret", "password")
}

print("IPv6 literal")
if let node = parseOk("ss://YWVzLTI1Ni1nY206c2VjcmV0@[2001:db8::1]:8388", "ipv6") {
    checkEqual(node.server, "2001:db8::1", "server")
    checkEqual(node.port, 8388, "port")
}

print("plugin options")
if let node = parseOk(
    "ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dwww.bing.com",
    "plugin"
) {
    checkEqual(node.plugin, "obfs-local", "plugin name")
    checkEqual(node.pluginOptions, "obfs=http;obfs-host=www.bing.com", "plugin options")
    let outbound = node.outbound()
    checkEqual(outbound["plugin"] as? String, "obfs-local", "outbound plugin")
    checkEqual(outbound["plugin_opts"] as? String, "obfs=http;obfs-host=www.bing.com", "outbound plugin_opts")
}

print("password containing a colon")
if let node = parseOk("ss://MjAyMi1ibGFrZTMtYWVzLTI1Ni1nY206cEBzczp3b3Jk@1.2.3.4:8388", "colon password") {
    checkEqual(node.method, "2022-blake3-aes-256-gcm", "method")
    checkEqual(node.password, "p@ss:word", "password")
}

print("percent-encoded tag")
if let node = parseOk("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#%E6%97%A5%E6%9C%AC", "tag decoding") {
    checkEqual(node.tag, "日本", "tag")
}

print("cipher alias")
if let node = parseOk("ss://Y2hhY2hhMjAtcG9seTEzMDU6cHc=@1.2.3.4:8388", "alias") {
    checkEqual(node.method, "chacha20-ietf-poly1305", "chacha20-poly1305 is aliased")
}

print("trojan")
if let node = parseOk("trojan://p%40ss@example.com:443?sni=example.com&allowInsecure=1#T1", "trojan") {
    checkEqual(node.kind, .trojan, "kind")
    checkEqual(node.password, "p@ss", "password")
    checkEqual(node.server, "example.com", "server")
    checkEqual(node.port, 443, "port")
    checkEqual(node.tag, "T1", "tag")
    checkEqual(node.tls?.enabled, true, "tls enabled")
    checkEqual(node.tls?.serverName, "example.com", "sni")
    checkEqual(node.tls?.insecure, true, "insecure")
    let outbound = node.outbound()
    checkEqual(outbound["type"] as? String, "trojan", "outbound type")
    let tls = outbound["tls"] as? [String: Any]
    checkEqual(tls?["enabled"] as? Bool, true, "outbound tls enabled")
}

print("trojan with security=none")
if let node = parseOk("trojan://pw@example.com:443?security=none", "trojan plaintext") {
    check(node.tls == nil, "no tls object when security=none")
}

print("outbound JSON round-trips")
do {
    let node = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Tokyo")
    let json = try node.outboundJSON()
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    checkEqual(object?["type"] as? String, "shadowsocks", "type")
    checkEqual(object?["server_port"] as? Int, 8388, "server_port")
} catch {
    check(false, "outbound JSON", "\(error)")
}

print("generated profile is a complete sing-box config")
do {
    let node = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Tokyo")
    let config = try JSONSerialization.jsonObject(with: Data(node.profileConfig().utf8)) as? [String: Any]

    let inbounds = config?["inbounds"] as? [[String: Any]]
    checkEqual(inbounds?.count, 1, "one inbound")
    let tun = inbounds?.first
    checkEqual(tun?["type"] as? String, "tun", "inbound is tun")
    checkEqual(tun?["auto_route"] as? Bool, true, "auto_route is on")
    check(tun?["stack"] == nil, "stack is left to the platform default (sing-box marks it deprecated)")
    check(tun?["mtu"] == nil, "mtu is left to the platform default (4064 inside a Network Extension)")
    checkEqual((tun?["address"] as? [String])?.first, "172.19.0.1/30", "tun address")

    let outbounds = config?["outbounds"] as? [[String: Any]]
    checkEqual(outbounds?.count, 2, "node plus direct")
    checkEqual(outbounds?.last?["type"] as? String, "direct", "direct outbound present")

    let route = config?["route"] as? [String: Any]
    checkEqual(route?["final"] as? String, "Tokyo", "route final is the node")
    checkEqual(route?["auto_detect_interface"] as? Bool, true, "auto_detect_interface")
    checkEqual((route?["rules"] as? [[String: Any]])?.count, 1, "one route rule")
} catch {
    check(false, "single-node config", "\(error)")
}

print("multiple nodes become a selector")
do {
    let first = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Tokyo")
    let second = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@5.6.7.8:8388#Osaka")
    let config = try JSONSerialization.jsonObject(
        with: Data(ShadowLink.profileConfig(nodes: [first, second]).utf8)
    ) as? [String: Any]

    let outbounds = config?["outbounds"] as? [[String: Any]]
    checkEqual(outbounds?.count, 4, "selector, two nodes, direct")
    let selector = outbounds?.first
    checkEqual(selector?["type"] as? String, "selector", "first outbound is a selector")
    checkEqual(selector?["outbounds"] as? [String], ["Tokyo", "Osaka"], "selector members")
    checkEqual(selector?["default"] as? String, "Tokyo", "selector default")
    checkEqual((config?["route"] as? [String: Any])?["final"] as? String, "proxy", "route final is the selector")
} catch {
    check(false, "multi-node config", "\(error)")
}

print("duplicate tags are disambiguated")
do {
    let a = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Same")
    let b = try ShadowLink.parse("ss://YWVzLTI1Ni1nY206c2VjcmV0@5.6.7.8:8388#Same")
    let config = try JSONSerialization.jsonObject(
        with: Data(ShadowLink.profileConfig(nodes: [a, b]).utf8)
    ) as? [String: Any]
    let selector = (config?["outbounds"] as? [[String: Any]])?.first
    checkEqual(selector?["outbounds"] as? [String], ["Same", "Same 2"], "second tag got a suffix")
} catch {
    check(false, "duplicate tags", "\(error)")
}

print("vmess base64 JSON")
if let node = parseOk(
    "vmess://eyJ2IjoiMiIsInBzIjoiVG9reW8gVk1lc3MiLCJhZGQiOiJ2bWVzcy5leGFtcGxlLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6ImI4MzEzODFkLTYzMjQtNGQ1My1hZDRmLThjZGE0OGIzMDgxMSIsImFpZCI6IjAiLCJzY3kiOiJhdXRvIiwibmV0Ijoid3MiLCJ0eXBlIjoibm9uZSIsImhvc3QiOiJjZG4uZXhhbXBsZS5jb20iLCJwYXRoIjoiL3dzIiwidGxzIjoidGxzIiwic25pIjoiY2RuLmV4YW1wbGUuY29tIiwiYWxwbiI6ImgyLGh0dHAvMS4xIiwiZnAiOiJjaHJvbWUifQ==",
    "vmess"
) {
    checkEqual(node.kind, .vmess, "kind")
    checkEqual(node.tag, "Tokyo VMess", "tag from ps")
    checkEqual(node.server, "vmess.example.com", "server")
    checkEqual(node.port, 443, "port")
    checkEqual(node.uuid, "b831381d-6324-4d53-ad4f-8cda48b30811", "uuid")
    checkEqual(node.security, "auto", "security")
    checkEqual(node.alterId, 0, "alter id")
    check(node.tls?.enabled == true, "tls enabled")
    checkEqual(node.tls?.serverName, "cdn.example.com", "server name")
    checkEqual(node.tls?.alpn, ["h2", "http/1.1"], "alpn")
    checkEqual(node.tls?.fingerprint, "chrome", "utls fingerprint")
    check(node.transport?.kind == .webSocket, "websocket transport")
    checkEqual(node.transport?.path, "/ws", "ws path")
    checkEqual(node.transport?.host, "cdn.example.com", "ws host")

    let outbound = node.outbound()
    checkEqual(outbound["type"] as? String, "vmess", "outbound type")
    check(outbound["alter_id"] == nil, "alter_id omitted when zero")
    let tls = outbound["tls"] as? [String: Any]
    checkEqual((tls?["utls"] as? [String: Any])?["fingerprint"] as? String, "chrome", "outbound utls")
    let transport = outbound["transport"] as? [String: Any]
    checkEqual(transport?["type"] as? String, "ws", "outbound transport type")
    let headers = transport?["headers"] as? [String: Any]
    checkEqual(headers?["Host"] as? [String], ["cdn.example.com"], "outbound ws Host header")
}

print("vless with reality and grpc")
if let node = parseOk(
    "vless://b831381d-6324-4d53-ad4f-8cda48b30811@vless.example.com:443?encryption=none&security=reality&sni=www.example.com&fp=chrome&pbk=PUBKEY123&sid=ab12&type=grpc&serviceName=grpcsvc&flow=xtls-rprx-vision#VLESS",
    "vless"
) {
    checkEqual(node.kind, .vless, "kind")
    checkEqual(node.tag, "VLESS", "tag")
    checkEqual(node.uuid, "b831381d-6324-4d53-ad4f-8cda48b30811", "uuid")
    checkEqual(node.flow, "xtls-rprx-vision", "flow")
    check(node.tls?.enabled == true, "tls enabled")
    checkEqual(node.tls?.serverName, "www.example.com", "sni")
    checkEqual(node.tls?.realityPublicKey, "PUBKEY123", "reality public key")
    checkEqual(node.tls?.realityShortID, "ab12", "reality short id")
    check(node.transport?.kind == .grpc, "grpc transport")
    checkEqual(node.transport?.serviceName, "grpcsvc", "grpc service name")

    let tls = node.outbound()["tls"] as? [String: Any]
    let reality = tls?["reality"] as? [String: Any]
    checkEqual(reality?["public_key"] as? String, "PUBKEY123", "outbound reality")
    let transport = node.outbound()["transport"] as? [String: Any]
    checkEqual(transport?["service_name"] as? String, "grpcsvc", "outbound service_name")
}

print("hysteria2 with salamander obfs")
if let node = parseOk(
    "hysteria2://letmein@hy2.example.com:8443?sni=hy2.example.com&insecure=1&obfs=salamander&obfs-password=obfspw&up=100&down=500#HY2",
    "hysteria2"
) {
    checkEqual(node.kind, .hysteria2, "kind")
    checkEqual(node.password, "letmein", "password")
    checkEqual(node.tls?.serverName, "hy2.example.com", "sni")
    check(node.tls?.insecure == true, "insecure")
    checkEqual(node.obfs, "salamander", "obfs")
    checkEqual(node.obfsPassword, "obfspw", "obfs password")
    checkEqual(node.upMbps, 100, "up")
    checkEqual(node.downMbps, 500, "down")

    let obfs = node.outbound()["obfs"] as? [String: Any]
    checkEqual(obfs?["type"] as? String, "salamander", "outbound obfs type")
    checkEqual(obfs?["password"] as? String, "obfspw", "outbound obfs password")
}

print("tuic")
if let node = parseOk(
    "tuic://b831381d-6324-4d53-ad4f-8cda48b30811:tuicpass@tuic.example.com:443?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=tuic.example.com#TUIC",
    "tuic"
) {
    checkEqual(node.kind, .tuic, "kind")
    checkEqual(node.uuid, "b831381d-6324-4d53-ad4f-8cda48b30811", "uuid")
    checkEqual(node.password, "tuicpass", "password")
    checkEqual(node.congestionControl, "bbr", "congestion control")
    checkEqual(node.udpRelayMode, "native", "udp relay mode")
    checkEqual(node.tls?.alpn, ["h3"], "alpn")
    let outbound = node.outbound()
    checkEqual(outbound["congestion_control"] as? String, "bbr", "outbound congestion_control")
    checkEqual(outbound["udp_relay_mode"] as? String, "native", "outbound udp_relay_mode")
}

print("socks and http")
if let node = parseOk("socks5://suser:spass@socks.example.com:1080#SOCKS", "socks5") {
    checkEqual(node.kind, .socks, "kind")
    checkEqual(node.username, "suser", "username")
    checkEqual(node.password, "spass", "password")
    checkEqual(node.socksVersion, "5", "version")
    let outbound = node.outbound()
    checkEqual(outbound["version"] as? String, "5", "outbound version")
    checkEqual(outbound["username"] as? String, "suser", "outbound username")
    check(outbound["tls"] == nil, "socks carries no tls")
}
if let node = parseOk("http://huser:hpass@proxy.example.com:8080#HTTP", "http") {
    checkEqual(node.kind, .http, "kind")
    checkEqual(node.username, "huser", "username")
    checkEqual(node.port, 8080, "port")
    check(node.tls == nil, "plain http has no tls")
}
if let node = parseOk("https://proxy.example.com:8443#HTTPS", "https") {
    check(node.tls?.enabled == true, "https enables tls")
    checkEqual(node.tls?.serverName, "proxy.example.com", "sni defaults to the host")
}

print("subscription bodies")
let subscriptionLinks = [
    "ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Node-A",
    "trojan://tpass@trojan.example.com:443?sni=trojan.example.com#Node-B",
]
let plainBody = subscriptionLinks.joined(separator: "\n")
let base64Body = "c3M6Ly9ZV1Z6TFRJMU5pMW5ZMjA2YzJWamNtVjBAMS4yLjMuNDo4Mzg4I05vZGUtQQp0cm9qYW46Ly90cGFzc0B0cm9qYW4uZXhhbXBsZS5jb206NDQzP3NuaT10cm9qYW4uZXhhbXBsZS5jb20jTm9kZS1C"

for (label, body) in [("plain text body", plainBody), ("base64 body", base64Body)] {
    let result = ShadowLink.parseAll(body)
    checkEqual(result.nodes.count, 2, "\(label): node count")
    checkEqual(result.failures.count, 0, "\(label): no failures")
    checkEqual(result.nodes.first?.tag, "Node-A", "\(label): first tag")
    checkEqual(result.nodes.last?.tag, "Node-B", "\(label): second tag")
}

let mixed = ShadowLink.parseAll("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:8388#Good\nnot-a-link\nssr://c29tZXRoaW5n")
checkEqual(mixed.nodes.count, 1, "mixed body keeps only the usable link")
checkEqual(mixed.failures.count, 2, "mixed body reports the other two")

print("rejections")
expectError("aes-256-gcm:secret@1.2.3.4:8388", .missingScheme, "no scheme")
expectError("wireguard://c29tZXRoaW5n", .unsupportedScheme("wireguard"), "unsupported scheme")
expectError("ssr://c29tZXRoaW5n", .protocolNotSupported("ShadowsocksR (ssr://)"), "ssr is not implemented by sing-box")
expectError("hysteria://pw@example.com:443", .protocolNotSupported("Hysteria v1 (use hysteria2:// instead)"), "hysteria v1")
expectError("vless://uuid@example.com:443?type=kcp", .protocolNotSupported("mKCP transport"), "mkcp transport")
expectError("ss://YWVzLTI1Ni1jZmI6c2VjcmV0@1.2.3.4:8388", .unsupportedMethod("aes-256-cfb"), "legacy cipher")
expectError("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:notaport", .invalidPort("notaport"), "bad port")
expectError("ss://!!!not-base64!!!", .malformedLink("cannot recover credentials from the legacy form"), "garbage")
expectError("ss://YWVzLTI1Ni1nY206c2VjcmV0", .malformedLink("cannot recover credentials from the legacy form"), "no host at all")
expectError("vmess://bm90LWpzb24=", .malformedLink("vmess payload is not base64 encoded JSON"), "vmess without JSON")

print("")
print("\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("FAILED: \(failures) failure(s)")
    exit(1)
}
print("ALL PASSED")
exit(0)
