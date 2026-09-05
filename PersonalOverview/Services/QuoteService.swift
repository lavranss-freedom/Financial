import Foundation

actor QuoteService {
    static let shared = QuoteService()

    func fetchQuotes(symbols: [String]) async -> [QuoteResult] {
        let unique = Array(Set(symbols.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [] }
        var all: [QuoteResult] = []
        let chunkSize = 8
        var i = 0
        while i < unique.count {
            let end = min(i + chunkSize, unique.count)
            let chunk = Array(unique[i..<end])
            let results = await withTaskGroup(of: QuoteResult.self) { group in
                for symbol in chunk {
                    group.addTask { await self.fetchOne(symbol: symbol) }
                }
                var out: [QuoteResult] = []
                for await r in group { out.append(r) }
                return out
            }
            all.append(contentsOf: results)
            i = end
        }
        return all
    }

    private func fetchOne(symbol: String) async -> QuoteResult {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=5d&includePrePost=true"
        guard let url = URL(string: urlString) else {
            return QuoteResult(symbol: symbol, delayed: true, error: "bad url")
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return QuoteResult(symbol: symbol, delayed: true, error: "http")
            }
            return parseChart(symbol: symbol, data: data)
        } catch {
            return QuoteResult(symbol: symbol, delayed: true, error: error.localizedDescription)
        }
    }

    private func parseChart(symbol: String, data: Data) -> QuoteResult {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let resultArr = chart["result"] as? [[String: Any]],
            let result = resultArr.first,
            let meta = result["meta"] as? [String: Any]
        else {
            return QuoteResult(symbol: symbol, delayed: true, error: "parse")
        }

        let last = number(meta["regularMarketPrice"])
            ?? number(meta["postMarketPrice"])
            ?? number(meta["previousClose"])
        let previous = number(meta["chartPreviousClose"])
            ?? number(meta["previousClose"])
        var dayPct = number(meta["regularMarketChangePercent"])
        if dayPct == nil, let last, let previous, previous != 0 {
            dayPct = ((last - previous) / previous) * 100
        }

        let ahPrice = number(meta["postMarketPrice"])
        var ahPct = number(meta["postMarketChangePercent"])
        if ahPct == nil, let ahPrice, let last, last != 0 {
            ahPct = ((ahPrice - last) / last) * 100
        }

        let asOf: String? = {
            if let t = meta["regularMarketTime"] as? Int {
                return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(t)))
            }
            return ISO8601DateFormatter().string(from: Date())
        }()

        return QuoteResult(
            symbol: symbol,
            last: last,
            previousClose: previous,
            dayChangePercent: dayPct,
            afterHoursPrice: ahPrice,
            afterHoursChangePercent: ahPct,
            delayed: true,
            asOf: asOf
        )
    }

    private func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }
}
