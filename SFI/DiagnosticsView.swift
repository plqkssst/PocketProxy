import ApplicationLibrary
import Darwin
import Foundation
import Library
import NetworkExtension
import SwiftUI
import UIKit

enum DiagnosticsStatus {
    case ok
    case fail
    case info

    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .fail: return "xmark.octagon.fill"
        case .info: return "info.circle"
        }
    }

    var color: Color {
        switch self {
        case .ok: return .green
        case .fail: return .red
        case .info: return .secondary
        }
    }
}

struct DiagnosticsRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let status: DiagnosticsStatus
}

struct DiagnosticsSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [DiagnosticsRow]
}

/// Reads the running process' entitlements through the Security framework. The symbols are
/// resolved at runtime so this compiles regardless of whether SecTask is declared in the
/// public SDK headers, and degrades to "unavailable" instead of failing the build.
private enum EntitlementReader {
    private typealias CreateFromSelfFn = @convention(c) (UnsafeRawPointer?) -> UnsafeMutableRawPointer?
    private typealias CopyValueFn = @convention(c) (UnsafeMutableRawPointer, CFString, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

    private static let frameworkHandle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW)

    private static let createFromSelf: CreateFromSelfFn? = {
        guard let handle = frameworkHandle else { return nil }
        guard let symbol = dlsym(handle, "SecTaskCreateFromSelf") else { return nil }
        return unsafeBitCast(symbol, to: CreateFromSelfFn.self)
    }()

    private static let copyValue: CopyValueFn? = {
        guard let handle = frameworkHandle else { return nil }
        guard let symbol = dlsym(handle, "SecTaskCopyValueForEntitlement") else { return nil }
        return unsafeBitCast(symbol, to: CopyValueFn.self)
    }()

    static var isAvailable: Bool {
        return createFromSelf != nil && copyValue != nil
    }

    static func displayValue(for key: String) -> String? {
        guard let createFromSelf = createFromSelf else { return nil }
        guard let copyValue = copyValue else { return nil }
        guard let task = createFromSelf(nil) else { return nil }
        defer {
            _ = Unmanaged<AnyObject>.fromOpaque(task).takeRetainedValue()
        }
        guard let raw = copyValue(task, key as CFString, nil) else { return nil }

        let value = Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue()
        if let array = value as? [String] {
            return array.isEmpty ? "(empty)" : array.joined(separator: ", ")
        }
        if let boolean = value as? Bool {
            return boolean ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let string = value as? String {
            return string
        }
        return String(describing: value)
    }
}

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sections: [DiagnosticsSection] = []
    @State private var summary: String = ""
    @State private var summaryStatus: DiagnosticsStatus = .info
    @State private var isRunning = true

    private static let informationalKeys: Set<String> = ["get-task-allow"]

    private static let entitlementKeys = [
        "application-identifier",
        "com.apple.developer.team-identifier",
        "com.apple.developer.networking.networkextension",
        "com.apple.security.application-groups",
        "com.apple.developer.networking.wifi-info",
        "com.apple.developer.networking.multicast",
        "get-task-allow",
    ]

    var body: some View {
        SheetContent("Diagnostics") {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: summaryStatus.symbol)
                                .foregroundColor(summaryStatus.color)
                            Text(summary.isEmpty ? "Checking..." : summary)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 2)
                }
                ForEach(sections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.rows) { row in
                            rowView(row)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRunning)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isRunning && sections.isEmpty {
                    ProgressView()
                }
            }
        }
        .task {
            await refresh()
        }
    }

    @ViewBuilder
    private func rowView(_ row: DiagnosticsRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: row.status.symbol)
                    .foregroundColor(row.status.color)
                Text(row.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(row.value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func refresh() async {
        isRunning = true

        var collected: [DiagnosticsSection] = []
        collected.append(basicSection())
        collected.append(entitlementSection())
        let outcome = await tunnelSection()
        collected.append(outcome.section)

        sections = collected
        summaryStatus = outcome.status
        summary = outcome.summary
        isRunning = false
    }

    private func basicSection() -> DiagnosticsSection {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let rows: [DiagnosticsRow] = [
            DiagnosticsRow(label: "Bundle ID", value: bundle.bundleIdentifier ?? "(nil)", status: .info),
            DiagnosticsRow(label: "Version", value: "\(version) (\(build))", status: .info),
            DiagnosticsRow(label: "App Group ID", value: AppConfiguration.appGroupID, status: .info),
            DiagnosticsRow(label: "System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)", status: .info),
            DiagnosticsRow(label: "Device", value: DiagnosticsView.machineIdentifier(), status: .info),
        ]
        return DiagnosticsSection(title: "App", rows: rows)
    }

    private func entitlementSection() -> DiagnosticsSection {
        var rows: [DiagnosticsRow] = []

        let group = AppConfiguration.appGroupID
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            rows.append(DiagnosticsRow(label: "App Group container", value: container.path, status: .ok))
        } else {
            rows.append(DiagnosticsRow(
                label: "App Group container",
                value: "unavailable - the signature is missing com.apple.security.application-groups, so the app and the tunnel extension cannot share profiles and the VPN cannot work",
                status: .fail
            ))
        }

        if EntitlementReader.isAvailable {
            for key in DiagnosticsView.entitlementKeys {
                if let value = EntitlementReader.displayValue(for: key) {
                    let status: DiagnosticsStatus = DiagnosticsView.informationalKeys.contains(key) ? .info : .ok
                    rows.append(DiagnosticsRow(label: key, value: value, status: status))
                } else {
                    rows.append(DiagnosticsRow(label: key, value: "missing", status: .fail))
                }
            }
        } else {
            rows.append(DiagnosticsRow(
                label: "entitlements",
                value: "unreadable (the SecTask symbols are not available in the Security framework)",
                status: .info
            ))
        }

        return DiagnosticsSection(title: "Signature and entitlements", rows: rows)
    }

    private func tunnelSection() async -> TunnelOutcome {
        var rows: [DiagnosticsRow] = []
        var hasNetworkExtensionEntitlement = false
        var extensionMatches = false

        let expectedExtensionID = AppConfiguration.extensionBundleID
        let extensionURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("Extension.appex")
        if let extensionURL = extensionURL, FileManager.default.fileExists(atPath: extensionURL.path) {
            let actual = Bundle(url: extensionURL)?.bundleIdentifier ?? "(unreadable)"
            extensionMatches = actual == expectedExtensionID
            rows.append(DiagnosticsRow(
                label: "Embedded tunnel extension",
                value: actual,
                status: extensionMatches ? .ok : .fail
            ))
        } else {
            rows.append(DiagnosticsRow(
                label: "Embedded tunnel extension",
                value: "PlugIns/Extension.appex not found",
                status: .fail
            ))
        }
        rows.append(DiagnosticsRow(label: "Expected extension ID", value: expectedExtensionID, status: .info))

        if let raw = EntitlementReader.displayValue(for: "com.apple.developer.networking.networkextension") {
            hasNetworkExtensionEntitlement = raw.contains("packet-tunnel-provider")
        }
        rows.append(DiagnosticsRow(
            label: "packet-tunnel-provider",
            value: hasNetworkExtensionEntitlement ? "granted" : "not granted - VPN will fail to start",
            status: hasNetworkExtensionEntitlement ? .ok : .fail
        ))

        let result = await loadManagers()
        switch result {
        case .success(let managers):
            rows.append(DiagnosticsRow(label: "Saved VPN configurations", value: "\(managers.count)", status: .ok))
        case .failure(let error):
            rows.append(DiagnosticsRow(label: "Saved VPN configurations", value: "\(error)", status: .fail))
        }

        let status: DiagnosticsStatus
        let summary: String
        if !hasNetworkExtensionEntitlement {
            status = .fail
            summary = "The signature is missing the Network Extension entitlement. The VPN cannot start."
        } else if !extensionMatches {
            status = .fail
            summary = "The tunnel extension is missing or has an unexpected bundle ID."
        } else if FilePath.appGroupUnavailable {
            status = .fail
            summary = "The App Group container is unavailable. The VPN cannot start."
        } else {
            status = .ok
            summary = "Signature looks complete. The VPN should be able to start."
        }

        return TunnelOutcome(
            section: DiagnosticsSection(title: "Network Extension", rows: rows),
            summary: summary,
            status: status
        )
    }

    private func loadManagers() async -> Result<[NETunnelProviderManager], Error> {
        return await withCheckedContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(managers ?? []))
                }
            }
        }
    }

    private static func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}

private struct TunnelOutcome {
    let section: DiagnosticsSection
    let summary: String
    let status: DiagnosticsStatus
}
