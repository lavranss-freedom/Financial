import Foundation

enum Sleeve: String, Codable, CaseIterable, Identifiable {
    case core = "Core"
    case fortress = "Fortress"
    case growth = "Growth"
    case moonshot = "Moonshot"
    case ignore = "Ignore"
    var id: String { rawValue }
}

enum AssetCurrency: String, Codable {
    case nok = "NOK"
    case usd = "USD"
    case eur = "EUR"
}

struct Holding: Identifiable, Codable, Hashable {
    var id: String
    var symbol: String
    var name: String
    var yahooSymbol: String
    var qty: Double
    var gav: Double
    var currency: AssetCurrency
    var sleeve: Sleeve
    var plan: String?
    var trigger: String?
    var excluded: Bool?
    var dead: Bool?
    var last: Double?
    var dayChangePercent: Double?
    var afterHoursChangePercent: Double?
    var afterHoursPrice: Double?
    var quoteAsOf: String?
}

struct CryptoHolding: Identifiable, Codable, Hashable {
    var id: String
    var symbol: String
    var name: String
    var yahooSymbol: String
    var valueUsd: Double
    var dead: Bool?
    var last: Double?
    var dayChangePercent: Double?
    var quoteAsOf: String?
}

struct OtherAsset: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var valueNok: Double
    var note: String?
}

struct NetWorthInputs: Codable, Hashable {
    var house1Value: Double
    var house2Value: Double
    var houseEquityPct: Double
    var mortgageHalf: Double
    var mortgageRatePct: Double
    var cashNok: Double
    var otherDebts: Double
    var leasedCar: Bool
    var ducatiValue: Double?
    var usdNok: Double
}

enum CandidateBoard: String, Codable {
    case core
    case moonshot
}

enum CandidateStatus: String, Codable {
    case watch
    case promoted
    case rejected
}

struct Candidate: Identifiable, Codable, Hashable {
    var id: String
    var board: CandidateBoard
    var name: String
    var symbol: String?
    var thesis: String
    var beatsHold: String
    var killCriteria: String
    var proposedSize: String
    var status: CandidateStatus
}

enum AlertSeverity: String, Codable {
    case info
    case warn
    case move
}

struct AlertItem: Identifiable, Codable, Hashable {
    var id: String
    var createdAt: String
    var title: String
    var body: String
    var severity: AlertSeverity
    var read: Bool
    var symbol: String?
}

struct ActionLogEntry: Identifiable, Codable, Hashable {
    var id: String
    var at: String
    var action: String
    var detail: String?
}

struct AppData: Codable {
    var version: Int
    var holdings: [Holding]
    var crypto: [CryptoHolding]
    var otherAssets: [OtherAsset]
    var netWorth: NetWorthInputs
    var candidates: [Candidate]
    var alerts: [AlertItem]
    var actionLog: [ActionLogEntry]
    var lastQuoteRefresh: String?
}

struct QuoteResult: Identifiable {
    var id: String { symbol }
    var symbol: String
    var last: Double?
    var previousClose: Double?
    var dayChangePercent: Double?
    var afterHoursPrice: Double?
    var afterHoursChangePercent: Double?
    var delayed: Bool
    var asOf: String?
    var error: String?
}

struct NetWorthBreakdown {
    var equity: Double
    var listed: Double
    var cryptoNok: Double
    var cryptoUsd: Double
    var cash: Double
    var mortgage: Double
    var other: Double
    var otherAssetsNok: Double
    var assets: Double
    var liabilities: Double
    var netWorth: Double
}
