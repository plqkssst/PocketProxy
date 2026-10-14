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
    checkEqual(node.tls?.enabled, false, "tls disabled")
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
    checkEqual(tun?["stack"] as? String, "gvisor", "stack")
    checkEqual(tun?["mtu"] as? Int, 9000, "mtu")
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

print("rejections")
expectError("aes-256-gcm:secret@1.2.3.4:8388", .missingScheme, "no scheme")
expectError("vmess://c29tZXRoaW5n", .unsupportedScheme("vmess"), "unsupported scheme")
expectError("ss://YWVzLTI1Ni1jZmI6c2VjcmV0@1.2.3.4:8388", .unsupportedMethod("aes-256-cfb"), "legacy cipher")
expectError("ss://YWVzLTI1Ni1nY206c2VjcmV0@1.2.3.4:notaport", .invalidPort("notaport"), "bad port")
expectError("ss://!!!not-base64!!!", .malformedLink("cannot recover credentials from the legacy form"), "garbage")
expectError("ss://YWVzLTI1Ni1nY206c2VjcmV0", .malformedLink("cannot recover credentials from the legacy form"), "no host at all")

print("")
print("\(checks - failures)/\(checks) checks passed")
if failures > 0 {
    print("FAILED: \(failures) failure(s)")
    exit(1)
}
print("ALL PASSED")
exit(0)
