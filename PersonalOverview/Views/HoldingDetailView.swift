import SwiftUI

struct HoldingDetailView: View {
    @EnvironmentObject var store: AppDataStore
    let holding: Holding

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(holding.symbol)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.gold)
                    Text(holding.name)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(holding.sleeve.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .appCard()

                if let data = store.data {
                    let moon = PortfolioCalc.moonshotWeightPct(data.holdings, usdNok: data.netWorth.usdNok)
                    let brief = AnalyzeBrief.generate(for: currentHolding(in: data), moonshotPct: moon)
                    Text(brief)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard()
                }
            }
            .padding()
        }
        .background(AppTheme.navy.ignoresSafeArea())
        .navigationTitle("Analyze")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func currentHolding(in data: AppData) -> Holding {
        data.holdings.first(where: { $0.id == holding.id }) ?? holding
    }
}
