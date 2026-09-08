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

        let session = sessionDay(meta: meta, result: result)
        // Last is independent of day proof. Oslo charts often have a null
        // intermediate close; that dashes Day % only and must not blank last.
        let last = number(meta["regularMarketPrice"]) ?? session.last ?? latestClose(result: result)

        let ahPrice = number(meta["postMarketPrice"])
        var ahPct = number(meta["postMarketChangePercent"])
        if ahPct == nil, let ahPrice, let last, last != 0 {
            ahPct = ((ahPrice - last) / last) * 100
        }

        let asOf: String? = {
            if let t = number(meta["regularMarketTime"]) {
                return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: t))
            }
            return ISO8601DateFormatter().string(from: Date())
        }()

        return QuoteResult(
            symbol: symbol,
            last: last,
            previousClose: session.previousClose,
            dayChangePercent: session.dayChangePercent,
            afterHoursPrice: ahPrice,
            afterHoursChangePercent: ahPct,
            delayed: true,
            asOf: asOf
        )
    }

    /// Session vs previous official close. Never chartPreviousClose, GAV, or 5-day range start.
    /// Day % is nil unless previous close is the immediately prior session.
    private func latestClose(result: [String: Any]) -> Double? {
        let quote = (result["indicators"] as? [String: Any])?["quote"] as? [[String: Any]]
        let rawCloses = quote?.first?["close"] as? [Any] ?? []
        for item in rawCloses.reversed() {
            if let close = number(item) { return close }
        }
        return nil
    }

    private func sessionDay(meta: [String: Any], result: [String: Any]) -> (last: Double?, previousClose: Double?, dayChangePercent: Double?) {
        // regularMarketPrice first; else latest non-null daily close. Never require previous close.
        let last = number(meta["regularMarketPrice"]) ?? latestClose(result: result)
        let yahooPct = number(meta["regularMarketChangePercent"])
        let officialPrev = number(meta["previousClose"])
        let priorClose = priorSessionClose(result: result, meta: meta)

        var prev: Double? = nil
        var proven = false
        if let priorClose, priorClose != 0 {
            if let officialPrev {
                if closeMatches(officialPrev, priorClose) {
                    prev = officialPrev
                    proven = true
                }
            } else {
                prev = priorClose
                proven = true
            }
        }

        guard proven, let prev, prev != 0, let last else {
            return (last, nil, nil)
        }
        if let yahooPct, let implied = impliedPrevious(last: last, pct: yahooPct), closeMatches(implied, prev) {
            return (last, prev, yahooPct)
        }
        return (last, prev, ((last - prev) / prev) * 100)
    }

    private func priorSessionClose(result: [String: Any], meta: [String: Any]) -> Double? {
        let timestamps = result["timestamp"] as? [Any] ?? []
        let quote = (result["indicators"] as? [String: Any])?["quote"] as? [[String: Any]]
        let rawCloses = quote?.first?["close"] as? [Any] ?? []
        let sessionStart = ((meta["currentTradingPeriod"] as? [String: Any])?["regular"] as? [String: Any]).flatMap { number($0["start"]) }

        var points: [(t: Double, close: Double?)] = []
        let n = max(timestamps.count, rawCloses.count)
        for i in 0..<n {
            guard i < timestamps.count, let t = number(timestamps[i]) else { continue }
            let close = i < rawCloses.count ? number(rawCloses[i]) : nil
            points.append((t, close))
        }
        guard !points.isEmpty else { return nil }

        let cutoff = sessionStart ?? points[points.count - 1].t
        let before = points.filter { $0.t < cutoff }
        guard !before.isEmpty else { return nil }

        var prior: (t: Double, close: Double)? = nil
        for p in before.reversed() {
            if let close = p.close {
                prior = (p.t, close)
                break
            }
        }
        guard let prior else { return nil }
        if before.contains(where: { $0.t > prior.t }) { return nil }
        let gap = cutoff - prior.t
        if gap <= 0 || gap > 5 * 24 * 3600 { return nil }
        return prior.close
    }

    private func closeMatches(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= max(0.05, abs(b) * 0.0015)
    }

    private func impliedPrevious(last: Double, pct: Double) -> Double? {
        let denom = 1 + pct / 100
        guard denom != 0, denom.isFinite else { return nil }
        let prev = last / denom
        return prev.isFinite && prev != 0 ? prev : nil
    }

    private func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d.isFinite ? d : nil }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue.isFinite ? n.doubleValue : nil }
        return nil
    }
}
