import Foundation
import SwiftUI

@MainActor
final class AppDataStore: ObservableObject {
    @Published var data: AppData?
    @Published var isUnlocked = false
    @Published var needsPINSetup: Bool
    @Published var quoteStatus: String = "Quotes delayed · tap refresh"
    @Published var isRefreshingQuotes = false
    @Published var lastError: String?

    private let defaultsKey = "personalOverview.appData.v1"

    init() {
        needsPINSetup = !KeychainHelper.hasPIN()
    }

    func setupPIN(_ pin: String) -> Bool {
        guard pin.count >= 4, pin.count <= 6, pin.allSatisfy(\.isNumber) else { return false }
        guard KeychainHelper.savePIN(pin) else { return false }
        needsPINSetup = false
        loadSeedIfNeeded()
        isUnlocked = true
        return true
    }

    func unlock(with pin: String) -> Bool {
        guard KeychainHelper.verifyPIN(pin) else { return false }
        loadSeedIfNeeded()
        isUnlocked = true
        return true
    }

    func lock() {
        isUnlocked = false
    }

    func logoutAndClearPIN() {
        KeychainHelper.deletePIN()
        data = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        needsPINSetup = true
        isUnlocked = false
    }

    private func loadSeedIfNeeded() {
        if let saved = loadPersisted() {
            data = saved
            return
        }
        do {
            var seed = try SeedLoader.loadBundled()
            let now = ISO8601DateFormatter().string(from: Date())
            seed.alerts = seed.alerts.map { a in
                var copy = a
                if copy.createdAt.isEmpty { copy.createdAt = now }
                return copy
            }
            seed.actionLog = seed.actionLog.map { e in
                var copy = e
                if copy.at.isEmpty { copy.at = now }
                return copy
            }
            data = seed
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func persist() {
        guard let data else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    private func loadPersisted() -> AppData? {
        guard let raw = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: raw)
    }

    func updateNetWorth(_ mutate: (inout NetWorthInputs) -> Void) {
        guard var d = data else { return }
        mutate(&d.netWorth)
        data = d
        persist()
    }

    func updateOtherAsset(id: String, name: String? = nil, valueNok: Double? = nil) {
        guard var d = data else { return }
        guard let idx = d.otherAssets.firstIndex(where: { $0.id == id }) else { return }
        if let name { d.otherAssets[idx].name = name }
        if let valueNok { d.otherAssets[idx].valueNok = valueNok }
        data = d
        persist()
    }

    func addOtherAsset() {
        guard var d = data else { return }
        d.otherAssets.append(OtherAsset(
            id: "oa-\(UUID().uuidString.prefix(8))",
            name: "New asset",
            valueNok: 0,
            note: nil
        ))
        data = d
        persist()
    }

    func removeOtherAsset(id: String) {
        guard var d = data else { return }
        d.otherAssets.removeAll { $0.id == id }
        data = d
        persist()
    }

    func setCandidateStatus(id: String, status: CandidateStatus) {
        guard var d = data else { return }
        guard let idx = d.candidates.firstIndex(where: { $0.id == id }) else { return }
        d.candidates[idx].status = status
        let name = d.candidates[idx].name
        d.actionLog.insert(ActionLogEntry(
            id: "log-\(UUID().uuidString.prefix(8))",
            at: ISO8601DateFormatter().string(from: Date()),
            action: "Candidate \(status.rawValue)",
            detail: name
        ), at: 0)
        data = d
        persist()
    }

    func markAlertRead(id: String) {
        guard var d = data else { return }
        guard let idx = d.alerts.firstIndex(where: { $0.id == id }) else { return }
        d.alerts[idx].read = true
        data = d
        persist()
    }

    func exportJSON() -> Data? {
        guard let data else { return nil }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(data)
    }

    func refreshQuotes() async {
        guard var d = data else { return }
        isRefreshingQuotes = true
        quoteStatus = "Refreshing delayed quotes…"
        let symbols = d.holdings.filter { $0.dead != true }.map(\.yahooSymbol)
            + d.crypto.filter { $0.dead != true }.map(\.yahooSymbol)
        let results = await QuoteService.shared.fetchQuotes(symbols: symbols)
        let bySymbol = Dictionary(uniqueKeysWithValues: results.map { ($0.symbol, $0) })
        var ok = 0
        for i in d.holdings.indices {
            let sym = d.holdings[i].yahooSymbol
            guard let q = bySymbol[sym], q.error == nil else { continue }
            if let last = q.last {
                d.holdings[i].last = last
                ok += 1
            }
            d.holdings[i].dayChangePercent = q.dayChangePercent
            d.holdings[i].afterHoursChangePercent = q.afterHoursChangePercent
            d.holdings[i].afterHoursPrice = q.afterHoursPrice
            d.holdings[i].quoteAsOf = q.asOf
        }
        for i in d.crypto.indices {
            let sym = d.crypto[i].yahooSymbol
            guard let q = bySymbol[sym], q.error == nil, let last = q.last else { continue }
            d.crypto[i].last = last
            d.crypto[i].dayChangePercent = q.dayChangePercent
            d.crypto[i].quoteAsOf = q.asOf
            ok += 1
        }
        d.lastQuoteRefresh = ISO8601DateFormatter().string(from: Date())
        data = d
        persist()
        isRefreshingQuotes = false
        quoteStatus = "Delayed Yahoo · \(ok) marks updated · offline falls back to last/GAV"
    }
}
