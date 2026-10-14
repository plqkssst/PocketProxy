import Libbox
import Library
import SwiftUI

@MainActor
public struct ImportShareLinkView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var alert: AlertState?
    @State private var isSaving = false

    public init() {}

    public var body: some View {
        FormView {
            Section {
                TextEditor(text: $input)
                    .frame(minHeight: 160)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Share Links")
            } footer: {
                Text("Paste one ss:// or trojan:// link per line. Multiple links become a single profile with a selector.")
            }

            Section {
                FormButton("Import") {
                    Task {
                        await performImport()
                    }
                }
                .disabled(isSaving || trimmedLines.isEmpty)
            }
        }
        .navigationTitle("Import from Share Link")
        .alert($alert)
    }

    private var trimmedLines: [String] {
        input
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func performImport() async {
        let lines = trimmedLines
        guard !lines.isEmpty else { return }

        var nodes: [ShadowLinkNode] = []
        var failures: [String] = []
        for line in lines {
            do {
                nodes.append(try ShadowLink.parse(line))
            } catch {
                failures.append("\(line.prefix(48)): \(error.localizedDescription)")
            }
        }

        guard !nodes.isEmpty else {
            alert = AlertState(errorMessage: failures.prefix(3).joined(separator: "\n"))
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let config = try ShadowLink.profileConfig(nodes: nodes)
            var error: NSError?
            LibboxCheckConfig(config, &error)
            if let error = error {
                throw error
            }

            let name = nodes.count == 1 ? nodes[0].tag : "\(nodes.count) nodes"
            let profile = try await createProfile(name: name, config: config)
            await SharedPreferences.selectedProfileID.set(profile.mustID)
            environments.profileUpdate.send()

            if failures.isEmpty {
                dismiss()
            } else {
                alert = AlertState(
                    title: String(localized: "Import Profile"),
                    message: "Imported \(nodes.count) node(s), skipped \(failures.count):\n"
                        + failures.prefix(3).joined(separator: "\n"),
                    primaryButton: .default("OK") {
                        dismiss()
                    }
                )
            }
        } catch {
            alert = AlertState(action: "import share link", error: error)
        }
    }

    private func createProfile(name: String, config: String) async throws -> Profile {
        let nextProfileID = try await ProfileManager.nextID()
        let directory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
        let configURL = directory.appendingPathComponent("config_\(nextProfileID).json")
        let relativePath = "configs/config_\(nextProfileID).json"

        try await BlockingIO.run {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        }

        let uniqueName = try await ProfileManager.uniqueName(name)
        let profile = Profile(
            name: uniqueName,
            type: .local,
            path: relativePath
        )
        try await ProfileManager.create(profile)
        return profile
    }
}
