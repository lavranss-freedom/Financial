import Foundation

enum PortfolioCalc {
    static func holdingValueNative(_ h: Holding) -> Double {
        if h.dead == true || h.excluded == true { return 0 }
        let px = h.last ?? h.gav
        return h.qty * px
    }

    static func holdingValueNok(_ h: Holding, usdNok: Double) -> Double {
        let native = holdingValueNative(h)
        switch h.currency {
        case .nok: return native
        case .usd, .eur: return native * usdNok
        }
    }

    static func holdingCostNok(_ h: Holding, usdNok: Double) -> Double {
        if h.dead == true || h.excluded == true { return 0 }
        let cost = h.qty * h.gav
        return h.currency == .nok ? cost : cost * usdNok
    }

    static func holdingReturnPct(_ h: Holding) -> Double? {
        if h.dead == true || h.excluded == true || h.gav == 0 { return nil }
        let px = h.last ?? h.gav
        return ((px - h.gav) / h.gav) * 100
    }

    static func listedActiveTotalNok(_ holdings: [Holding], usdNok: Double) -> Double {
        holdings
            .filter { $0.excluded != true && $0.dead != true }
            .reduce(0) { $0 + holdingValueNok($1, usdNok: usdNok) }
    }

    static func cryptoTotalUsd(_ crypto: [CryptoHolding]) -> Double {
        crypto.filter { $0.dead != true }.reduce(0) { $0 + $1.valueUsd }
    }

    static func cryptoTotalNok(_ crypto: [CryptoHolding], usdNok: Double) -> Double {
        cryptoTotalUsd(crypto) * usdNok
    }

    static func otherAssetsTotalNok(_ assets: [OtherAsset]) -> Double {
        assets.reduce(0) { $0 + $1.valueNok }
    }

    static func houseEquity(_ nw: NetWorthInputs) -> Double {
        (nw.house1Value + nw.house2Value) * (nw.houseEquityPct / 100)
    }

    static func computeNetWorth(_ data: AppData) -> NetWorthBreakdown {
        let nw = data.netWorth
        let equity = houseEquity(nw)
        let listed = listedActiveTotalNok(data.holdings, usdNok: nw.usdNok)
        let cryptoUsd = cryptoTotalUsd(data.crypto)
        let cryptoNok = cryptoUsd * nw.usdNok
        let cash = nw.cashNok
        let mortgage = nw.mortgageHalf
        let other = nw.otherDebts
        let legacyDucati = nw.ducatiValue ?? 0
        let otherAssetsNok = otherAssetsTotalNok(data.otherAssets)
        let assets = equity + listed + cryptoNok + cash + legacyDucati + otherAssetsNok
        let liabilities = mortgage + other
        return NetWorthBreakdown(
            equity: equity,
            listed: listed,
            cryptoNok: cryptoNok,
            cryptoUsd: cryptoUsd,
            cash: cash,
            mortgage: mortgage,
            other: other,
            otherAssetsNok: otherAssetsNok,
            assets: assets,
            liabilities: liabilities,
            netWorth: assets - liabilities
        )
    }

    static func holdingWeight(_ h: Holding, holdings: [Holding], usdNok: Double) -> Double? {
        if h.excluded == true || h.dead == true { return nil }
        let total = listedActiveTotalNok(holdings, usdNok: usdNok)
        guard total > 0 else { return nil }
        return (holdingValueNok(h, usdNok: usdNok) / total) * 100
    }

    static func moonshotWeightPct(_ holdings: [Holding], usdNok: Double) -> Double {
        let total = listedActiveTotalNok(holdings, usdNok: usdNok)
        guard total > 0 else { return 0 }
        let moon = holdings
            .filter { $0.sleeve == .moonshot && $0.excluded != true && $0.dead != true }
            .reduce(0) { $0 + holdingValueNok($1, usdNok: usdNok) }
        return (moon / total) * 100
    }
}
