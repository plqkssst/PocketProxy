import Foundation

public enum FilePath {
    public static let packageName = AppConfiguration.packageName
    public static let groupName = AppConfiguration.appGroupID

    private static let defaultSharedDirectory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName)

    /// The App Group is the only channel the app and the tunnel extension share profiles
    /// through, so this being unavailable means the VPN cannot work: the signature is
    /// missing `com.apple.security.application-groups`.
    public static let appGroupUnavailable = defaultSharedDirectory == nil

    /// Keeps the app launchable when the container is gone instead of trapping, so the
    /// diagnostics screen can explain what the signature is missing.
    private static let fallbackDirectory: URL = {
        let url = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("NoAppGroup", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    #if os(iOS)
        public static let sharedDirectory = defaultSharedDirectory ?? fallbackDirectory
    #elseif os(tvOS)
        public static let sharedDirectory = (defaultSharedDirectory ?? fallbackDirectory)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    #elseif os(macOS)
        public static var sharedDirectory: URL! = defaultSharedDirectory
    #endif

    #if os(iOS)
        public static let cacheDirectory = sharedDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    #elseif os(tvOS)
        public static let cacheDirectory = sharedDirectory
    #elseif os(macOS)
        public static var cacheDirectory: URL {
            sharedDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Caches", isDirectory: true)
        }
    #endif

    #if os(macOS)
        public static var workingDirectory: URL {
            cacheDirectory.appendingPathComponent("Working", isDirectory: true)
        }
    #else
        public static let workingDirectory = cacheDirectory.appendingPathComponent("Working", isDirectory: true)

    #endif

    public static var iCloudDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true) ?? URL(string: "stub")!
}

public extension URL {
    var fileName: String {
        var path = relativePath
        if let index = path.lastIndex(of: "/") {
            path = String(path[path.index(index, offsetBy: 1)...])
        }
        return path
    }
}
