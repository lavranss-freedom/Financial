import SwiftUI

struct CandidatesView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        NavigationStack {
            Group {
                if let data = store.data {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            section(title: "Core / Fortress / Growth board", board: .core, candidates: data.candidates)
                            section(title: "Moonshots board", board: .moonshot, candidates: data.candidates)
                        }
                        .padding()
                    }
                } else {
                    ProgressView().tint(AppTheme.gold)
                }
            }
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Candidates")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func section(title: String, board: CandidateBoard, candidates: [Candidate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.gold)
            let items = candidates.filter { $0.board == board }
            if items.isEmpty {
                Text("No candidates").foregroundStyle(AppTheme.textSecondary).appCard()
            }
            ForEach(items) { c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(c.name).font(.headline).foregroundStyle(AppTheme.textPrimary)
                        if let s = c.symbol {
                            Text(s).font(.caption).foregroundStyle(AppTheme.gold)
                        }
                        Spacer()
                        Text(c.status.rawValue.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(statusColor(c.status))
                    }
                    Text(c.thesis).font(.footnote).foregroundStyle(AppTheme.textSecondary)
                    Text("Beats hold: \(c.beatsHold)").font(.caption).foregroundStyle(AppTheme.textSecondary)
                    Text("Kill: \(c.killCriteria)").font(.caption).foregroundStyle(AppTheme.textSecondary)
                    Text("Size: \(c.proposedSize)").font(.caption).foregroundStyle(AppTheme.gold)
                    HStack {
                        stubButton("Watch") { store.setCandidateStatus(id: c.id, status: .watch) }
                        stubButton("Promote") { store.setCandidateStatus(id: c.id, status: .promoted) }
                        stubButton("Reject") { store.setCandidateStatus(id: c.id, status: .rejected) }
                    }
                }
                .appCard()
            }
        }
    }

    private func stubButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.navyElevated)
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statusColor(_ s: CandidateStatus) -> Color {
        switch s {
        case .watch: return AppTheme.gold
        case .promoted: return AppTheme.positive
        case .rejected: return AppTheme.negative
        }
    }
}
