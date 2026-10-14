import Foundation

public enum ShadowLinkError: Error, LocalizedError, Equatable {
    case missingScheme
    case unsupportedScheme(String)
    case malformedLink(String)
    case missingHost
    case invalidPort(String)
    case missingCredentials
    case unsupportedMethod(String)

    public var errorDescription: String? {
        switch self {
        case .missingScheme:
            return "The link has no URI scheme."
        case .unsupportedScheme(let scheme):
            return "Unsupported link scheme: \(scheme)"
        case .malformedLink(let detail):
            return "Malformed link: \(detail)"
        case .missingHost:
            return "The link has no server address."
        case .invalidPort(let value):
            return "Invalid port: \(value)"
        case .missingCredentials:
            return "The link has no credentials."
        case .unsupportedMethod(let method):
            return "The sing-box core does not support the cipher \(method). Supported ciphers are: "
                + ShadowLink.supportedMethods.sorted().joined(separator: ", ")
        }
    }
}

public struct ShadowLinkTLS: Equatable {
    public var enabled: Bool
    public var serverName: String?
    public var insecure: Bool

    public init(enabled: Bool = true, serverName: String? = nil, insecure: Bool = false) {
        self.enabled = enabled
        self.serverName = serverName
        self.insecure = insecure
    }
}

public struct ShadowLinkNode: Equatable {
    public enum Kind: String {
        case shadowsocks
        case trojan
    }

    public var kind: Kind
    public var tag: String
    public var server: String
    public var port: Int
    public var password: String
    public var method: String?
    public var plugin: String?
    public var pluginOptions: String?
    public var tls: ShadowLinkTLS?

    public init(
        kind: Kind,
        tag: String,
        server: String,
        port: Int,
        password: String,
        method: String? = nil,
        plugin: String? = nil,
        pluginOptions: String? = nil,
        tls: ShadowLinkTLS? = nil
    ) {
        self.kind = kind
        self.tag = tag
        self.server = server
        self.port = port
        self.password = password
        self.method = method
        self.plugin = plugin
        self.pluginOptions = pluginOptions
        self.tls = tls
    }

    /// The sing-box outbound object for this node, ready to be dropped into a config.
    public func outbound() -> [String: Any] {
        var result: [String: Any] = [
            "type": kind.rawValue,
            "tag": tag,
            "server": server,
            "server_port": port,
        ]
        switch kind {
        case .shadowsocks:
            result["method"] = method ?? ""
            result["password"] = password
            if let plugin = plugin, !plugin.isEmpty {
                result["plugin"] = plugin
                if let pluginOptions = pluginOptions, !pluginOptions.isEmpty {
                    result["plugin_opts"] = pluginOptions
                }
            }
        case .trojan:
            result["password"] = password
            if let tls = tls {
                var tlsObject: [String: Any] = ["enabled": tls.enabled]
                if let serverName = tls.serverName, !serverName.isEmpty {
                    tlsObject["server_name"] = serverName
                }
                if tls.insecure {
                    tlsObject["insecure"] = true
                }
                result["tls"] = tlsObject
            }
        }
        return result
    }

    public func outboundJSON() throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: outbound(),
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw ShadowLinkError.malformedLink("outbound is not valid UTF-8")
        }
        return string
    }
}

public enum ShadowLink {
    /// Ciphers the sing-box shadowsocks inbound/outbound actually implements. The legacy
    /// stream ciphers that older ss:// links use (aes-256-cfb, rc4-md5, ...) were dropped.
    public static let supportedMethods: Set<String> = [
        "none",
        "aes-128-gcm",
        "aes-192-gcm",
        "aes-256-gcm",
        "chacha20-ietf-poly1305",
        "xchacha20-ietf-poly1305",
        "2022-blake3-aes-128-gcm",
        "2022-blake3-aes-256-gcm",
        "2022-blake3-chacha20-poly1305",
    ]

    private static let methodAliases: [String: String] = [
        "chacha20-poly1305": "chacha20-ietf-poly1305",
        "chacha20-ietf": "chacha20-ietf-poly1305",
        "xchacha20-poly1305": "xchacha20-ietf-poly1305",
    ]

    public static func parse(_ link: String) throws -> ShadowLinkNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.range(of: "://") else {
            throw ShadowLinkError.missingScheme
        }
        let scheme = trimmed[trimmed.startIndex..<separator.lowerBound].lowercased()
        var remainder = String(trimmed[separator.upperBound...])

        var fragment = ""
        if let hash = remainder.firstIndex(of: "#") {
            fragment = String(remainder[remainder.index(after: hash)...])
            remainder = String(remainder[..<hash])
        }
        let tag = decodePercent(fragment)

        var query: [String: String] = [:]
        if let question = remainder.firstIndex(of: "?") {
            query = parseQuery(String(remainder[remainder.index(after: question)...]))
            remainder = String(remainder[..<question])
        }
        while remainder.hasSuffix("/") {
            remainder.removeLast()
        }

        switch scheme {
        case "ss":
            return try parseShadowsocks(remainder: remainder, query: query, tag: tag)
        case "trojan", "trojan-go":
            return try parseTrojan(remainder: remainder, query: query, tag: tag)
        default:
            throw ShadowLinkError.unsupportedScheme(scheme)
        }
    }

    // MARK: - Shadowsocks

    private static func parseShadowsocks(
        remainder: String,
        query: [String: String],
        tag: String
    ) throws -> ShadowLinkNode {
        var credentials: String
        var hostPort: String

        if let at = remainder.lastIndex(of: "@") {
            // SIP002: ss://base64(method:password)@host:port
            let userinfo = String(remainder[..<at])
            hostPort = String(remainder[remainder.index(after: at)...])
            if let decoded = decodeBase64(userinfo), decoded.contains(":") {
                credentials = decoded
            } else if userinfo.contains(":") {
                // Some producers skip the base64 step entirely.
                credentials = userinfo
            } else {
                throw ShadowLinkError.missingCredentials
            }
        } else {
            // Legacy: ss://base64(method:password@host:port)
            guard let decoded = decodeBase64(remainder), let at = decoded.lastIndex(of: "@") else {
                throw ShadowLinkError.malformedLink("cannot recover credentials from the legacy form")
            }
            credentials = String(decoded[..<at])
            hostPort = String(decoded[decoded.index(after: at)...])
        }

        guard let colon = credentials.firstIndex(of: ":") else {
            throw ShadowLinkError.missingCredentials
        }
        let rawMethod = String(credentials[..<colon]).lowercased()
        let password = String(credentials[credentials.index(after: colon)...])
        let method = methodAliases[rawMethod] ?? rawMethod
        guard supportedMethods.contains(method) else {
            throw ShadowLinkError.unsupportedMethod(rawMethod)
        }

        let (host, port) = try splitHostPort(hostPort)

        var plugin: String?
        var pluginOptions: String?
        if let rawPlugin = query["plugin"], !rawPlugin.isEmpty {
            let parts = rawPlugin.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            plugin = String(parts[0])
            if parts.count > 1 {
                pluginOptions = String(parts[1])
            }
        }

        return ShadowLinkNode(
            kind: .shadowsocks,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            method: method,
            plugin: plugin,
            pluginOptions: pluginOptions
        )
    }

    // MARK: - Trojan

    private static func parseTrojan(
        remainder: String,
        query: [String: String],
        tag: String
    ) throws -> ShadowLinkNode {
        guard let at = remainder.lastIndex(of: "@") else {
            throw ShadowLinkError.missingCredentials
        }
        let userinfo = String(remainder[..<at])
        let hostPort = String(remainder[remainder.index(after: at)...])
        let password = decodePercent(userinfo)
        guard !password.isEmpty else {
            throw ShadowLinkError.missingCredentials
        }

        let (host, port) = try splitHostPort(hostPort)

        var tls = ShadowLinkTLS(
            enabled: true,
            serverName: query["sni"] ?? query["peer"],
            insecure: isTruthy(query["allowinsecure"]) || isTruthy(query["insecure"])
        )
        if let security = query["security"], security.lowercased() == "none" {
            tls.enabled = false
        }
        if let serverName = tls.serverName, serverName.isEmpty {
            tls.serverName = nil
        }

        return ShadowLinkNode(
            kind: .trojan,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            tls: tls
        )
    }

    // MARK: - Helpers

    private static func isTruthy(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "1" || value == "true" || value == "yes"
    }

    private static func decodePercent(_ value: String) -> String {
        return value.removingPercentEncoding ?? value
    }

    /// Accepts both the standard and the URL-safe alphabet, with or without padding.
    static func decodeBase64(_ value: String) -> String? {
        var normalized = decodePercent(value)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: normalized) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func splitHostPort(_ value: String) throws -> (String, Int) {
        if value.hasPrefix("[") {
            guard let close = value.firstIndex(of: "]") else {
                throw ShadowLinkError.malformedLink("unterminated IPv6 literal")
            }
            let host = String(value[value.index(after: value.startIndex)..<close])
            let rest = value[value.index(after: close)...]
            guard rest.hasPrefix(":") else {
                throw ShadowLinkError.invalidPort(String(rest))
            }
            guard let port = Int(rest.dropFirst()) else {
                throw ShadowLinkError.invalidPort(String(rest.dropFirst()))
            }
            return (host, port)
        }
        guard let colon = value.lastIndex(of: ":") else {
            throw ShadowLinkError.invalidPort(value)
        }
        let host = String(value[..<colon])
        let portText = String(value[value.index(after: colon)...])
        guard let port = Int(portText) else {
            throw ShadowLinkError.invalidPort(portText)
        }
        return (host, port)
    }

    static func parseQuery(_ value: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in value.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = parts.first, !key.isEmpty else { continue }
            let raw = parts.count > 1 ? String(parts[1]) : ""
            result[String(key).lowercased()] = decodePercent(raw)
        }
        return result
    }
}

public extension ShadowLinkNode {
    /// A complete single-node sing-box config.
    func profileConfig() throws -> String {
        return try ShadowLink.profileConfig(nodes: [self])
    }
}

public extension ShadowLink {
    /// Builds a full sing-box config. The app hands the profile file straight to the tunnel
    /// core without injecting anything, so the config has to carry its own tun inbound or the
    /// tunnel would come up with no routes at all.
    static func profileConfig(nodes: [ShadowLinkNode]) throws -> String {
        guard !nodes.isEmpty else {
            throw ShadowLinkError.malformedLink("no nodes to build a config from")
        }

        var usedTags: Set<String> = []
        var outbounds: [[String: Any]] = []
        for node in nodes {
            var outbound = node.outbound()
            var tag = node.tag
            var suffix = 2
            while usedTags.contains(tag) {
                tag = "\(node.tag) \(suffix)"
                suffix += 1
            }
            usedTags.insert(tag)
            outbound["tag"] = tag
            outbounds.append(outbound)
        }
        outbounds.append(["type": "direct", "tag": "direct"])

        let finalTag: String
        if outbounds.count > 2 {
            let tags = outbounds.dropLast().compactMap { $0["tag"] as? String }
            outbounds.insert(
                [
                    "type": "selector",
                    "tag": "proxy",
                    "outbounds": tags,
                    "default": tags[0],
                ],
                at: 0
            )
            finalTag = "proxy"
        } else {
            finalTag = (outbounds[0]["tag"] as? String) ?? "proxy"
        }

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": false,
                    "stack": "gvisor",
                ],
            ],
            "outbounds": outbounds,
            "route": [
                "rules": [
                    ["ip_is_private": true, "outbound": "direct"],
                ],
                "final": finalTag,
                "auto_detect_interface": true,
            ],
        ]

        let data = try JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw ShadowLinkError.malformedLink("config is not valid UTF-8")
        }
        return string
    }
}
