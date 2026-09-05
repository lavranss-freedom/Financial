import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        NavigationStack {
            Group {
                if let data = store.data {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Moves / alerts")
                                .font(.headline)
                                .foregroundStyle(AppTheme.gold)

                            ForEach(data.alerts) { alert in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(alert.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Text(alert.severity.rawValue.uppercased())
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.gold)
                                    }
                                    Text(alert.body)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text(alert.createdAt)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    if !alert.read {
                                        Button("Mark read") { store.markAlertRead(id: alert.id) }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.gold)
                                    }
                                }
                                .appCard()
                                .opacity(alert.read ? 0.55 : 1)
                            }

                            Text("Action log")
                                .font(.headline)
                                .foregroundStyle(AppTheme.gold)
                                .padding(.top, 8)

                            ForEach(data.actionLog) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.action)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    if let detail = entry.detail {
                                        Text(detail).font(.caption).foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Text(entry.at).font(.caption2).foregroundStyle(AppTheme.textSecondary)
                                }
                                .appCard()
                            }

                            Text("Placeholder: price-move alerts will wire to delayed quote deltas.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding()
                    }
                } else {
                    ProgressView().tint(AppTheme.gold)
                }
            }
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Alerts")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
