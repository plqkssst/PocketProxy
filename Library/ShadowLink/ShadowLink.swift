import Foundation

public enum ShadowLinkError: Error, LocalizedError, Equatable {
    case missingScheme
    case unsupportedScheme(String)
    case protocolNotSupported(String)
    case malformedLink(String)
    case invalidPort(String)
    case missingCredentials
    case missingField(String)
    case unsupportedMethod(String)

    public var errorDescription: String? {
        switch self {
        case .missingScheme:
            return "The link has no URI scheme."
        case .unsupportedScheme(let scheme):
            return "Unsupported link scheme: \(scheme)"
        case .protocolNotSupported(let name):
            return "The sing-box core does not implement \(name), so this link cannot be imported."
        case .malformedLink(let detail):
            return "Malformed link: \(detail)"
        case .invalidPort(let value):
            return "Invalid port: \(value)"
        case .missingCredentials:
            return "The link has no credentials."
        case .missingField(let field):
            return "The link is missing the \(field) field."
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
    public var alpn: [String]
    public var fingerprint: String?
    public var realityPublicKey: String?
    public var realityShortID: String?

    public init(
        enabled: Bool = true,
        serverName: String? = nil,
        insecure: Bool = false,
        alpn: [String] = [],
        fingerprint: String? = nil,
        realityPublicKey: String? = nil,
        realityShortID: String? = nil
    ) {
        self.enabled = enabled
        self.serverName = serverName
        self.insecure = insecure
        self.alpn = alpn
        self.fingerprint = fingerprint
        self.realityPublicKey = realityPublicKey
        self.realityShortID = realityShortID
    }

    /// The `tls` object of a sing-box outbound.
    public func object() -> [String: Any] {
        var result: [String: Any] = ["enabled": enabled]
        if let serverName = serverName, !serverName.isEmpty {
            result["server_name"] = serverName
        }
        if insecure {
            result["insecure"] = true
        }
        if !alpn.isEmpty {
            result["alpn"] = alpn
        }
        if let fingerprint = fingerprint, !fingerprint.isEmpty {
            result["utls"] = [
                "enabled": true,
                "fingerprint": fingerprint,
            ]
        }
        if let publicKey = realityPublicKey, !publicKey.isEmpty {
            var reality: [String: Any] = [
                "enabled": true,
                "public_key": publicKey,
            ]
            if let shortID = realityShortID, !shortID.isEmpty {
                reality["short_id"] = shortID
            }
            result["reality"] = reality
        }
        return result
    }
}

/// The `transport` object shared by the V2Ray style outbounds.
public struct ShadowLinkTransport: Equatable {
    public enum Kind: String {
        case webSocket = "ws"
        case grpc = "grpc"
        case http = "http"
        case httpUpgrade = "httpupgrade"
        case quic = "quic"
    }

    public var kind: Kind
    public var path: String?
    public var host: String?
    public var serviceName: String?

    public init(kind: Kind, path: String? = nil, host: String? = nil, serviceName: String? = nil) {
        self.kind = kind
        self.path = path
        self.host = host
        self.serviceName = serviceName
    }

    public func object() -> [String: Any] {
        var result: [String: Any] = ["type": kind.rawValue]
        switch kind {
        case .webSocket:
            if let path = path, !path.isEmpty {
                result["path"] = path
            }
            if let host = host, !host.isEmpty {
                result["headers"] = ["Host": [host]]
            }
        case .grpc:
            if let serviceName = serviceName, !serviceName.isEmpty {
                result["service_name"] = serviceName
            }
        case .http:
            if let host = host, !host.isEmpty {
                result["host"] = [host]
            }
            if let path = path, !path.isEmpty {
                result["path"] = path
            }
        case .httpUpgrade:
            if let host = host, !host.isEmpty {
                result["host"] = host
            }
            if let path = path, !path.isEmpty {
                result["path"] = path
            }
        case .quic:
            break
        }
        return result
    }
}

public struct ShadowLinkNode: Equatable {
    public enum Kind: String {
        case shadowsocks
        case vmess
        case vless
        case trojan
        case hysteria2
        case tuic
        case socks
        case http
    }

    public var kind: Kind
    public var tag: String
    public var server: String
    public var port: Int
    public var password: String?
    public var method: String?
    public var uuid: String?
    public var alterId: Int?
    public var security: String?
    public var flow: String?
    public var username: String?
    public var plugin: String?
    public var pluginOptions: String?
    public var tls: ShadowLinkTLS?
    public var transport: ShadowLinkTransport?
    public var congestionControl: String?
    public var udpRelayMode: String?
    public var obfs: String?
    public var obfsPassword: String?
    public var upMbps: Int?
    public var downMbps: Int?
    public var socksVersion: String?

    public init(
        kind: Kind,
        tag: String,
        server: String,
        port: Int,
        password: String? = nil,
        method: String? = nil,
        uuid: String? = nil,
        alterId: Int? = nil,
        security: String? = nil,
        flow: String? = nil,
        username: String? = nil,
        plugin: String? = nil,
        pluginOptions: String? = nil,
        tls: ShadowLinkTLS? = nil,
        transport: ShadowLinkTransport? = nil,
        congestionControl: String? = nil,
        udpRelayMode: String? = nil,
        obfs: String? = nil,
        obfsPassword: String? = nil,
        upMbps: Int? = nil,
        downMbps: Int? = nil,
        socksVersion: String? = nil
    ) {
        self.kind = kind
        self.tag = tag
        self.server = server
        self.port = port
        self.password = password
        self.method = method
        self.uuid = uuid
        self.alterId = alterId
        self.security = security
        self.flow = flow
        self.username = username
        self.plugin = plugin
        self.pluginOptions = pluginOptions
        self.tls = tls
        self.transport = transport
        self.congestionControl = congestionControl
        self.udpRelayMode = udpRelayMode
        self.obfs = obfs
        self.obfsPassword = obfsPassword
        self.upMbps = upMbps
        self.downMbps = downMbps
        self.socksVersion = socksVersion
    }

    /// The sing-box outbound object for this node.
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
            result["password"] = password ?? ""
            if let plugin = plugin, !plugin.isEmpty {
                result["plugin"] = plugin
                if let pluginOptions = pluginOptions, !pluginOptions.isEmpty {
                    result["plugin_opts"] = pluginOptions
                }
            }
        case .vmess:
            result["uuid"] = uuid ?? ""
            result["security"] = security ?? "auto"
            if let alterId = alterId, alterId > 0 {
                result["alter_id"] = alterId
            }
        case .vless:
            result["uuid"] = uuid ?? ""
            if let flow = flow, !flow.isEmpty {
                result["flow"] = flow
            }
        case .trojan:
            result["password"] = password ?? ""
        case .hysteria2:
            result["password"] = password ?? ""
            if let obfs = obfs, !obfs.isEmpty {
                result["obfs"] = [
                    "type": obfs,
                    "password": obfsPassword ?? "",
                ]
            }
            if let upMbps = upMbps, upMbps > 0 {
                result["up_mbps"] = upMbps
            }
            if let downMbps = downMbps, downMbps > 0 {
                result["down_mbps"] = downMbps
            }
        case .tuic:
            result["uuid"] = uuid ?? ""
            result["password"] = password ?? ""
            if let congestionControl = congestionControl, !congestionControl.isEmpty {
                result["congestion_control"] = congestionControl
            }
            if let udpRelayMode = udpRelayMode, !udpRelayMode.isEmpty {
                result["udp_relay_mode"] = udpRelayMode
            }
        case .socks:
            result["version"] = socksVersion ?? "5"
            if let username = username, !username.isEmpty {
                result["username"] = username
            }
            if let password = password, !password.isEmpty {
                result["password"] = password
            }
        case .http:
            if let username = username, !username.isEmpty {
                result["username"] = username
            }
            if let password = password, !password.isEmpty {
                result["password"] = password
            }
        }
        if let tls = tls, kind != .socks {
            result["tls"] = tls.object()
        }
        if let transport = transport, kind == .vmess || kind == .vless || kind == .trojan {
            result["transport"] = transport.object()
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

    /// Splits one link, or a whole subscription body, into nodes. A body that carries no
    /// scheme is assumed to be the base64 blob that most subscription endpoints return.
    public static func parseAll(_ text: String) -> (nodes: [ShadowLinkNode], failures: [String]) {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.contains("://"), let decoded = decodeBase64(body) {
            body = decoded
        }
        var nodes: [ShadowLinkNode] = []
        var failures: [String] = []
        for rawLine in body.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            do {
                nodes.append(try parse(line))
            } catch {
                failures.append("\(line.prefix(56)): \(error.localizedDescription)")
            }
        }
        return (nodes, failures)
    }

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
        case "ssr":
            throw ShadowLinkError.protocolNotSupported("ShadowsocksR (ssr://)")
        case "vmess":
            return try parseVMess(remainder: remainder, tag: tag)
        case "vless":
            return try parseVLESS(remainder: remainder, query: query, tag: tag)
        case "trojan", "trojan-go":
            return try parseTrojan(remainder: remainder, query: query, tag: tag)
        case "hysteria2", "hy2":
            return try parseHysteria2(remainder: remainder, query: query, tag: tag)
        case "hysteria":
            throw ShadowLinkError.protocolNotSupported("Hysteria v1 (use hysteria2:// instead)")
        case "tuic":
            return try parseTUIC(remainder: remainder, query: query, tag: tag)
        case "socks", "socks5", "socks4":
            return try parseSOCKS(scheme: scheme, remainder: remainder, tag: tag)
        case "http", "https":
            return try parseHTTP(scheme: scheme, remainder: remainder, tag: tag)
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

    // MARK: - VMess

    private static func parseVMess(remainder: String, tag: String) throws -> ShadowLinkNode {
        guard let json = decodeBase64(remainder),
              let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        else {
            throw ShadowLinkError.malformedLink("vmess payload is not base64 encoded JSON")
        }

        func field(_ key: String) -> String? {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
            if let value = object[key] as? Int {
                return String(value)
            }
            if let value = object[key] as? Double {
                return String(Int(value))
            }
            return nil
        }

        guard let host = field("add") else {
            throw ShadowLinkError.missingField("add")
        }
        guard let portText = field("port"), let port = Int(portText) else {
            throw ShadowLinkError.invalidPort(field("port") ?? "")
        }
        guard let uuid = field("id") else {
            throw ShadowLinkError.missingField("id")
        }

        let remarks = field("ps") ?? ""
        let alterId = Int(field("aid") ?? "0") ?? 0
        let security = field("scy") ?? field("security") ?? "auto"
        let network = (field("net") ?? "tcp").lowercased()
        let headerHost = field("host")
        let path = field("path")
        let sni = field("sni")
        let alpn = field("alpn") ?? ""
        let fingerprint = field("fp")

        var tls: ShadowLinkTLS?
        if (field("tls") ?? "").lowercased() == "tls" {
            tls = ShadowLinkTLS(
                enabled: true,
                serverName: sni ?? headerHost,
                insecure: false,
                alpn: alpn.isEmpty ? [] : alpn.split(separator: ",").map(String.init),
                fingerprint: fingerprint
            )
        }

        return ShadowLinkNode(
            kind: .vmess,
            tag: tag.isEmpty ? (remarks.isEmpty ? "\(host):\(port)" : remarks) : tag,
            server: host,
            port: port,
            uuid: uuid,
            alterId: alterId,
            security: security,
            tls: tls,
            transport: try transport(type: network, path: path, host: headerHost, serviceName: path)
        )
    }

    // MARK: - VLESS

    private static func parseVLESS(
        remainder: String,
        query: [String: String],
        tag: String
    ) throws -> ShadowLinkNode {
        guard let at = remainder.lastIndex(of: "@") else {
            throw ShadowLinkError.missingCredentials
        }
        let uuid = decodePercent(String(remainder[..<at]))
        let (host, port) = try splitHostPort(String(remainder[remainder.index(after: at)...]))
        guard !uuid.isEmpty else {
            throw ShadowLinkError.missingField("id")
        }

        let security = (query["security"] ?? "none").lowercased()

        return ShadowLinkNode(
            kind: .vless,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            uuid: uuid,
            flow: query["flow"],
            tls: tlsOptions(security: security, query: query, defaultServerName: query["sni"] ?? query["host"]),
            transport: try transport(
                type: query["type"] ?? "tcp",
                path: query["path"],
                host: query["host"],
                serviceName: query["servicename"]
            )
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
        let password = decodePercent(String(remainder[..<at]))
        guard !password.isEmpty else {
            throw ShadowLinkError.missingCredentials
        }
        let (host, port) = try splitHostPort(String(remainder[remainder.index(after: at)...]))

        let security = (query["security"] ?? "tls").lowercased()

        return ShadowLinkNode(
            kind: .trojan,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            tls: tlsOptions(security: security, query: query, defaultServerName: query["sni"] ?? query["peer"]),
            transport: try transport(
                type: query["type"] ?? "tcp",
                path: query["path"],
                host: query["host"],
                serviceName: query["servicename"]
            )
        )
    }

    // MARK: - Hysteria2

    private static func parseHysteria2(
        remainder: String,
        query: [String: String],
        tag: String
    ) throws -> ShadowLinkNode {
        guard let at = remainder.lastIndex(of: "@") else {
            throw ShadowLinkError.missingCredentials
        }
        let password = decodePercent(String(remainder[..<at]))
        let (host, port) = try splitHostPort(String(remainder[remainder.index(after: at)...]))

        let tls = tlsOptions(security: "tls", query: query, defaultServerName: query["sni"]) ?? ShadowLinkTLS(enabled: true, serverName: query["sni"])

        return ShadowLinkNode(
            kind: .hysteria2,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            tls: tls,
            obfs: query["obfs"],
            obfsPassword: query["obfs-password"] ?? query["obfspassword"],
            upMbps: Int(query["upmbps"] ?? query["up"] ?? ""),
            downMbps: Int(query["downmbps"] ?? query["down"] ?? "")
        )
    }

    // MARK: - TUIC

    private static func parseTUIC(
        remainder: String,
        query: [String: String],
        tag: String
    ) throws -> ShadowLinkNode {
        guard let at = remainder.lastIndex(of: "@") else {
            throw ShadowLinkError.missingCredentials
        }
        let userinfo = decodePercent(String(remainder[..<at]))
        guard let colon = userinfo.firstIndex(of: ":") else {
            throw ShadowLinkError.malformedLink("tuic needs uuid:password in the userinfo")
        }
        let uuid = String(userinfo[..<colon])
        let password = String(userinfo[userinfo.index(after: colon)...])
        let (host, port) = try splitHostPort(String(remainder[remainder.index(after: at)...]))

        let tls = tlsOptions(security: "tls", query: query, defaultServerName: query["sni"])
            ?? ShadowLinkTLS(enabled: true, serverName: query["sni"], alpn: ["h3"])

        return ShadowLinkNode(
            kind: .tuic,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            uuid: uuid,
            tls: tls,
            congestionControl: query["congestion_control"] ?? query["congestioncontrol"],
            udpRelayMode: query["udp_relay_mode"] ?? query["udprelaymode"]
        )
    }

    // MARK: - SOCKS and HTTP

    private static func parseSOCKS(scheme: String, remainder: String, tag: String) throws -> ShadowLinkNode {
        let (username, password, hostPort) = try splitUserInfo(remainder)
        let (host, port) = try splitHostPort(hostPort)
        return ShadowLinkNode(
            kind: .socks,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            username: username,
            socksVersion: scheme == "socks4" ? "4" : "5"
        )
    }

    private static func parseHTTP(scheme: String, remainder: String, tag: String) throws -> ShadowLinkNode {
        let (username, password, hostPort) = try splitUserInfo(remainder)
        let (host, port) = try splitHostPort(hostPort)
        return ShadowLinkNode(
            kind: .http,
            tag: tag.isEmpty ? "\(host):\(port)" : tag,
            server: host,
            port: port,
            password: password,
            username: username,
            tls: scheme == "https" ? ShadowLinkTLS(enabled: true, serverName: host) : nil
        )
    }

    // MARK: - Shared helpers

    private static func splitUserInfo(_ value: String) throws -> (String?, String?, String) {
        guard let at = value.lastIndex(of: "@") else {
            return (nil, nil, value)
        }
        let userinfo = decodePercent(String(value[..<at]))
        let hostPort = String(value[value.index(after: at)...])
        guard let colon = userinfo.firstIndex(of: ":") else {
            return (userinfo, nil, hostPort)
        }
        return (String(userinfo[..<colon]), String(userinfo[userinfo.index(after: colon)...]), hostPort)
    }

    private static func tlsOptions(
        security: String,
        query: [String: String],
        defaultServerName: String?
    ) -> ShadowLinkTLS? {
        let insecure = isTruthy(query["allowinsecure"]) || isTruthy(query["insecure"]) || isTruthy(query["skip-cert-verify"])
        let alpnText = query["alpn"] ?? ""
        let alpn = alpnText.isEmpty ? [] : alpnText.split(separator: ",").map(String.init)
        let fingerprint = query["fp"]

        switch security {
        case "reality":
            return ShadowLinkTLS(
                enabled: true,
                serverName: defaultServerName,
                insecure: insecure,
                alpn: alpn,
                fingerprint: fingerprint,
                realityPublicKey: query["pbk"],
                realityShortID: query["sid"]
            )
        case "tls":
            return ShadowLinkTLS(
                enabled: true,
                serverName: defaultServerName,
                insecure: insecure,
                alpn: alpn,
                fingerprint: fingerprint
            )
        default:
            return nil
        }
    }

    private static func transport(
        type: String,
        path: String?,
        host: String?,
        serviceName: String?
    ) throws -> ShadowLinkTransport? {
        switch type.lowercased() {
        case "", "tcp", "raw":
            return nil
        case "ws", "websocket":
            return ShadowLinkTransport(kind: .webSocket, path: path, host: host)
        case "grpc":
            return ShadowLinkTransport(kind: .grpc, serviceName: serviceName ?? path)
        case "h2", "http":
            return ShadowLinkTransport(kind: .http, path: path, host: host)
        case "httpupgrade":
            return ShadowLinkTransport(kind: .httpUpgrade, path: path, host: host)
        case "quic":
            return ShadowLinkTransport(kind: .quic)
        case "kcp", "mkcp":
            throw ShadowLinkError.protocolNotSupported("mKCP transport")
        default:
            throw ShadowLinkError.malformedLink("unknown transport type \(type)")
        }
    }

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
                    "auto_route": true,
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
