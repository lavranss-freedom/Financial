import SwiftUI

struct BookView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selected: Holding?

    var body: some View {
        NavigationStack {
            Group {
                if let data = store.data {
                    let usdNok = data.netWorth.usdNok
                    let listed = PortfolioCalc.listedActiveTotalNok(data.holdings, usdNok: usdNok)
                    let moon = PortfolioCalc.moonshotWeightPct(data.holdings, usdNok: usdNok)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Listed book")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.gold)
                                    Text(Formatters.nok(listed))
                                        .font(.title2.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Moonshots")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text(String(format: "%.1f%% / 3%%", moon))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(moon > 3 ? AppTheme.negative : AppTheme.gold)
                                }
                            }
                            .appCard()

                            HStack {
                                Text(store.quoteStatus)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Button {
                                    Task { await store.refreshQuotes() }
                                } label: {
                                    if store.isRefreshingQuotes {
                                        ProgressView().tint(AppTheme.gold)
                                    } else {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.gold)
                                    }
                                }
                            }

                            Text("Mandate: 20%+ goal · whole shares · no leverage · moonshots ≤3%. Fisker IGNORE/0.")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)

                            ForEach(data.holdings.filter { $0.sleeve != .ignore || $0.dead == true }) { h in
                                Button {
                                    selected = h
                                } label: {
                                    holdingRow(h, holdings: data.holdings, usdNok: usdNok)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Crypto · \(Formatters.usd(PortfolioCalc.cryptoTotalUsd(data.crypto)))")
                                .font(.headline)
                                .foregroundStyle(AppTheme.gold)
                                .padding(.top, 8)

                            ForEach(data.crypto.filter { $0.dead != true }) { c in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(c.symbol).foregroundStyle(AppTheme.textPrimary).font(.subheadline.weight(.semibold))
                                        Text(c.name).font(.caption).foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(Formatters.usd(c.valueUsd))
                                        .foregroundStyle(AppTheme.gold)
                                }
                                .appCard()
                            }
                        }
                        .padding()
                    }
                    .navigationDestination(item: $selected) { h in
                        HoldingDetailView(holding: h)
                    }
                } else {
                    ProgressView().tint(AppTheme.gold)
                }
            }
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Book")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func holdingRow(_ h: Holding, holdings: [Holding], usdNok: Double) -> some View {
        let value = PortfolioCalc.holdingValueNok(h, usdNok: usdNok)
        let ret = PortfolioCalc.holdingReturnPct(h)
        let weight = PortfolioCalc.holdingWeight(h, holdings: holdings, usdNok: usdNok)
        let px = h.last ?? h.gav
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(h.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(h.sleeve.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.navyElevated)
                    .foregroundStyle(AppTheme.gold)
                    .clipShape(Capsule())
                if h.dead == true || h.excluded == true {
                    Text("IGNORE")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.negative)
                }
                Spacer()
                Text(Formatters.nok(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text(h.name).font(.caption).foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 10) {
                Text("qty \(Formatters.num(h.qty, digits: 0))")
                Text("GAV \(Formatters.num(h.gav, digits: 2))")
                Text("last \(Formatters.num(px, digits: 2))")
                Text(Formatters.pct(ret))
                    .foregroundStyle((ret ?? 0) >= 0 ? AppTheme.positive : AppTheme.negative)
                if let d = h.dayChangePercent {
                    Text("d \(Formatters.pct(d))")
                }
                if let ah = h.afterHoursChangePercent {
                    Text("AH \(Formatters.pct(ah))")
                }
                if let w = weight {
                    Text("w \(Formatters.num(w, digits: 1))%")
                }
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .appCard()
        .opacity((h.dead == true || h.excluded == true) ? 0.45 : 1)
    }
}
