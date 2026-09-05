import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("FX") {
                    if let data = store.data {
                        HStack {
                            Text("USDNOK")
                            Spacer()
                            TextField("USDNOK", value: Binding(
                                get: { data.netWorth.usdNok },
                                set: { v in store.updateNetWorth { $0.usdNok = v } }
                            ), format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Holdings") {
                    Text("Edit holdings UI is a stub — seed loads from SeedData.json; persist edits via backup/export for now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Refresh delayed quotes") {
                        Task { await store.refreshQuotes() }
                    }
                }

                Section("Backup") {
                    Button("Export JSON backup") {
                        exportBackup()
                    }
                    if let message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Security") {
                    Button("Lock now") {
                        store.lock()
                    }
                    Button("Logout & clear PIN", role: .destructive) {
                        store.logoutAndClearPIN()
                    }
                }

                Section("About") {
                    Text("Personal Overview · iOS native")
                    Text("PWA still live at personal-overview-be9.pages.dev")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Quotes: Yahoo chart API (delayed). Offline falls back to last/GAV.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(url: exportURL)
                }
            }
        }
    }

    private func exportBackup() {
        guard let data = store.exportJSON() else {
            message = "Nothing to export"
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalOverview-backup.json")
        do {
            try data.write(to: url)
            exportURL = url
            showShare = true
            message = "Backup ready"
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
