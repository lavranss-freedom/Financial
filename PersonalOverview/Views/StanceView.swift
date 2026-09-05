import SwiftUI

struct StanceView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        NavigationStack {
            Group {
                if let data = store.data {
                    let nw = PortfolioCalc.computeNetWorth(data)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Net worth · NOK")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.gold)
                                Text(Formatters.nok(nw.netWorth))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Assets \(Formatters.nok(nw.assets)) − Liabilities \(Formatters.nok(nw.liabilities))")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("NW = 50% houses − mortgage half + listed + crypto(USD→NOK) + cash + other assets − other debts. Leased car OFF.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .appCard()

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                metric("Houses equity", Formatters.nok(nw.equity), note: "\(Formatters.num(data.netWorth.houseEquityPct, digits: 0))% of values", gold: true)
                                metric("Mortgage (half)", "−\(Formatters.nok(nw.mortgage))", note: "@\(Formatters.num(data.netWorth.mortgageRatePct, digits: 1))%", neg: true)
                                metric("Listed", Formatters.nok(nw.listed), note: "excl. Fisker / dead")
                                metric("Crypto", Formatters.nok(nw.cryptoNok), note: "\(Formatters.usd(nw.cryptoUsd)) · USDNOK \(Formatters.num(data.netWorth.usdNok, digits: 2))")
                                metric("Cash", Formatters.nok(nw.cash), note: "Editable")
                                metric("Other assets", Formatters.nok(nw.otherAssetsNok), note: "\(data.otherAssets.count) items")
                            }

                            Text("Edit inputs")
                                .font(.headline)
                                .foregroundStyle(AppTheme.gold)

                            VStack(spacing: 10) {
                                numberField("House A (NOK)", value: data.netWorth.house1Value) { v in
                                    store.updateNetWorth { $0.house1Value = v }
                                }
                                numberField("House B (NOK)", value: data.netWorth.house2Value) { v in
                                    store.updateNetWorth { $0.house2Value = v }
                                }
                                numberField("Ownership %", value: data.netWorth.houseEquityPct) { v in
                                    store.updateNetWorth { $0.houseEquityPct = v }
                                }
                                numberField("Mortgage half (NOK)", value: data.netWorth.mortgageHalf) { v in
                                    store.updateNetWorth { $0.mortgageHalf = v }
                                }
                                numberField("Cash NOK", value: data.netWorth.cashNok) { v in
                                    store.updateNetWorth { $0.cashNok = v }
                                }
                                Toggle(isOn: Binding(
                                    get: { data.netWorth.leasedCar },
                                    set: { v in store.updateNetWorth { $0.leasedCar = v } }
                                )) {
                                    Text("Leased car (off-balance)")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                .tint(AppTheme.gold)
                            }
                            .appCard()

                            HStack {
                                Text("Other assets")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.gold)
                                Spacer()
                                Button("+ Add") { store.addOtherAsset() }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.gold)
                            }

                            ForEach(data.otherAssets) { asset in
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Name", text: Binding(
                                        get: { asset.name },
                                        set: { store.updateOtherAsset(id: asset.id, name: $0) }
                                    ))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    TextField("Value NOK", value: Binding(
                                        get: { asset.valueNok },
                                        set: { store.updateOtherAsset(id: asset.id, valueNok: $0) }
                                    ), format: .number)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    if let note = asset.note {
                                        Text(note).font(.caption).foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Button("Remove", role: .destructive) {
                                        store.removeOtherAsset(id: asset.id)
                                    }
                                    .font(.caption)
                                }
                                .appCard()
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView().tint(AppTheme.gold)
                }
            }
            .background(AppTheme.navy.ignoresSafeArea())
            .navigationTitle("Stance")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func metric(_ label: String, _ value: String, note: String, gold: Bool = false, neg: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gold ? AppTheme.gold : (neg ? AppTheme.negative : AppTheme.textPrimary))
            Text(note).font(.caption2).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func numberField(_ title: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title).foregroundStyle(AppTheme.textSecondary).font(.caption)
            Spacer()
            TextField("", value: Binding(
                get: { value },
                set: { onChange($0) }
            ), format: .number)
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 140)
        }
    }
}
