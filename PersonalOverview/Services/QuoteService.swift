import Foundation
import CommonCrypto

actor QuoteService {
    static let shared = QuoteService()

    func fetchQuotes(symbols: [String]) async -> [QuoteResult] {
        let unique = Array(Set(symbols.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [] }
        let oslo = unique.filter { Self.osloEuronext[$0.uppercased()] != nil }
        let rest = unique.filter { Self.osloEuronext[$0.uppercased()] == nil }

        var all: [QuoteResult] = []
        // Oslo from Euronext, one at a time. US and crypto stay on Yahoo.
        for symbol in oslo {
            all.append(await fetchOne(symbol: symbol))
        }

        let chunkSize = 8
        var i = 0
        while i < rest.count {
            let end = min(i + chunkSize, rest.count)
            let chunk = Array(rest[i..<end])
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
        if Self.osloEuronext[symbol.uppercased()] != nil {
            if let cached = osloCache[symbol.uppercased()], Date().timeIntervalSince(cached.at) < 90 {
                return cached.quote
            }
            if let enx = await fetchEuronext(symbol: symbol), enx.last != nil {
                osloCache[symbol.uppercased()] = (at: Date(), quote: enx)
                return enx
            }
            // Euronext down: Yahoo last. Session day never uses chartPreviousClose.
            var yahoo = await fetchYahoo(symbol: symbol)
            if yahoo.last != nil {
                yahoo.dayChangePercent = nil
                yahoo.previousClose = nil
            }
            return yahoo
        }
        return await fetchYahoo(symbol: symbol)
    }

    private func fetchYahoo(symbol: String) async -> QuoteResult {
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


    // MARK: - Euronext Oslo delayed / official close

    /// Verified 2026-09-08 via live.euronext.com instrumentSearch (XOSL equity).
    private static let osloEuronext: [String: (isin: String, mic: String)] = [
        "AKER.OL": ("NO0010234552", "XOSL"),
        "KOG.OL": ("NO0013536151", "XOSL"),
        "TRMED.OL": ("NO0010597883", "XOSL"),
        "AUTO.OL": ("BMG0670A1099", "XOSL"),
        "CRNA.OL": ("NO0013033795", "XOSL"),
        "NYKD.OL": ("NO0010714785", "XOSL"),
    ]
    private static let fallbackKye = "24ayqVo7yJma"
    private static let maxAbsDayPct = 75.0

    private var osloCache: [String: (at: Date, quote: QuoteResult)] = [:]
    private var euronextKye: String = QuoteService.fallbackKye

    private func fetchEuronext(symbol: String) async -> QuoteResult? {
        guard let inst = Self.osloEuronext[symbol.uppercased()] else { return nil }
        let code = "\(inst.isin)-\(inst.mic)"
        let referer = "https://live.euronext.com/en/product/equities/\(code)"
        let urls = [
            "https://live.euronext.com/en/intraday_chart/getDetailedQuoteAjax/\(code)/full",
            "https://live.euronext.com/en/ajax/getDetailedQuote/\(code)",
        ]
        for urlString in urls {
            guard let html = await fetchDecryptedEuronext(urlString: urlString, referer: referer, code: code) else {
                continue
            }
            if let quote = parseEuronext(symbol: symbol, html: html), quote.last != nil {
                return quote
            }
        }
        return nil
    }

    private func fetchDecryptedEuronext(urlString: String, referer: String, code: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; PersonalOverview/1.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json,text/html,*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ct = obj["ct"] as? String {
                let salt = obj["s"] as? String ?? ""
                if let html = decryptEuronext(ct: ct, saltHex: salt, password: euronextKye) {
                    return html
                }
                if let kye = await refreshEuronextKye(code: code), kye != euronextKye {
                    euronextKye = kye
                    return decryptEuronext(ct: ct, saltHex: salt, password: kye)
                }
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func refreshEuronextKye(code: String) async -> String? {
        guard let url = URL(string: "https://live.euronext.com/en/product/equities/\(code)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; PersonalOverview/1.0)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) else { return nil }
        let pattern = #""ajax_secure"\s*:\s*\{[^}]*"kye"\s*:\s*"([^"]+)""#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(m.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    private func parseEuronext(symbol: String, html: String) -> QuoteResult? {
        let rows = htmlRows(html)
        let lastTraded = labeledNumber(rows: rows, label: "Last Traded")
        let valuation = labeledNumber(rows: rows, label: "Valuation Close")
        let previous = labeledNumber(rows: rows, label: "Previous Close")
        let currency = labeledText(rows: rows, label: "Currency") ?? "NOK"

        var last = lastTraded.value
        var asOfDt = lastTraded.date
        if let v = valuation.value {
            let same = valuation.date != nil && lastTraded.date != nil && valuation.date?.dateKey == lastTraded.date?.dateKey
            if same || last == nil {
                last = v
                asOfDt = (same ? lastTraded.date : valuation.date) ?? lastTraded.date
            }
        }
        if last == nil {
            last = headerPrice(html)
        }
        guard let last, last > 0 else { return nil }

        var previousClose = previous.value
        if previousClose == nil || previousClose! <= 0 { previousClose = nil }
        if let prevDt = previous.date, let asOfDt, prevDt.dateKey == asOfDt.dateKey {
            previousClose = nil
        }

        var day: Double? = nil
        if let previousClose, previousClose != 0 {
            let pct = ((last - previousClose) / previousClose) * 100
            if pct.isFinite && abs(pct) <= Self.maxAbsDayPct {
                day = pct
            } else {
                previousClose = nil
            }
        }

        return QuoteResult(
            symbol: symbol,
            last: last,
            previousClose: day == nil ? nil : previousClose,
            dayChangePercent: day,
            afterHoursPrice: nil,
            afterHoursChangePercent: nil,
            delayed: true,
            asOf: isoOslo(asOfDt)
        )
    }

    private struct EnxStamp {
        var dateKey: String
        var day: String
        var month: String
        var year: String
        var hh: String?
        var mm: String?
    }

    private func htmlRows(_ html: String) -> [[String]] {
        var rows: [[String]] = []
        guard let re = try? NSRegularExpression(pattern: "<tr\\b[^>]*>([\\s\\S]*?)</tr>", options: [.caseInsensitive]) else {
            return rows
        }
        let ns = html as NSString
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let inner = ns.substring(with: m.range(at: 1))
            var cells: [String] = []
            guard let cre = try? NSRegularExpression(pattern: "<t[dh]\\b[^>]*>([\\s\\S]*?)</t[dh]>", options: [.caseInsensitive]) else {
                continue
            }
            let ins = inner as NSString
            for c in cre.matches(in: inner, range: NSRange(location: 0, length: ins.length)) {
                cells.append(stripTags(ins.substring(with: c.range(at: 1))))
            }
            if !cells.isEmpty { rows.append(cells) }
        }
        return rows
    }

    private func labeledNumber(rows: [[String]], label: String) -> (value: Double?, date: EnxStamp?) {
        let want = label.lowercased()
        for cells in rows {
            let head = (cells.first ?? "").lowercased()
            if !head.contains(want) { continue }
            let value = cells.count > 1 ? parseEnxNumber(cells[1]) : nil
            let date = parseEnxDate(cells.dropFirst().joined(separator: " "))
            return (value, date)
        }
        return (nil, nil)
    }

    private func labeledText(rows: [[String]], label: String) -> String? {
        let want = label.lowercased()
        for cells in rows {
            if (cells.first ?? "").lowercased().hasPrefix(want), cells.count > 1 {
                return cells[1]
            }
        }
        return nil
    }

    private func headerPrice(_ html: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: "id=\"header-instrument-price\"[^>]*>\\s*([^<]+)", options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        guard let m = re.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return parseEnxNumber(ns.substring(with: m.range(at: 1)))
    }

    private func stripTags(_ s: String) -> String {
        let noTags = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return noTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseEnxNumber(_ s: String) -> Double? {
        guard let m = s.range(of: #"-?\d[\d.,]*"#, options: .regularExpression) else { return nil }
        var n = String(s[m])
        let comma = n.contains(",")
        let dot = n.contains(".")
        if comma && dot {
            if let lc = n.lastIndex(of: ","), let ld = n.lastIndex(of: "."), lc > ld {
                n = n.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                n = n.replacingOccurrences(of: ",", with: "")
            }
        } else if comma {
            let parts = n.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2 && parts[1].count != 3 {
                n = n.replacingOccurrences(of: ",", with: ".")
            } else {
                n = n.replacingOccurrences(of: ",", with: "")
            }
        }
        return Double(n)
    }

    private func parseEnxDate(_ s: String) -> EnxStamp? {
        guard let re = try? NSRegularExpression(pattern: #"(\d{2})/(\d{2})/(\d{4})(?:\s*-?\s*(\d{2}):(\d{2}))?"#),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> String? {
            let r = m.range(at: i)
            guard r.location != NSNotFound, let rr = Range(r, in: s) else { return nil }
            return String(s[rr])
        }
        guard let day = g(1), let month = g(2), let year = g(3) else { return nil }
        return EnxStamp(dateKey: "\(year)-\(month)-\(day)", day: day, month: month, year: year, hh: g(4), mm: g(5))
    }

    private func isoOslo(_ dt: EnxStamp?) -> String {
        let formatter = ISO8601DateFormatter()
        guard let dt else { return formatter.string(from: Date()) }
        let hh = dt.hh ?? "16"
        let mm = dt.mm ?? "25"
        let want = "\(dt.day)/\(dt.month)/\(dt.year), \(hh):\(mm)"
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_GB")
        display.timeZone = TimeZone(identifier: "Europe/Oslo")
        display.dateFormat = "dd/MM/yyyy, HH:mm"
        for off in ["+02:00", "+01:00"] {
            let iso = "\(dt.year)-\(dt.month)-\(dt.day)T\(hh):\(mm):00\(off)"
            if let date = ISO8601DateFormatter().date(from: iso), display.string(from: date) == want {
                return formatter.string(from: date)
            }
        }
        let fallback = "\(dt.year)-\(dt.month)-\(dt.day)T\(hh):\(mm):00+02:00"
        if let date = ISO8601DateFormatter().date(from: fallback) {
            return formatter.string(from: date)
        }
        return formatter.string(from: Date())
    }

    private func decryptEuronext(ct: String, saltHex: String, password: String) -> String? {
        guard let salt = hexData(saltHex), let cipher = Data(base64Encoded: ct) else { return nil }
        let derived = evpBytesToKey(password: Data(password.utf8), salt: salt, keyLen: 32, ivLen: 16)
        guard let plain = aes256CbcDecrypt(key: derived.key, iv: derived.iv, data: cipher) else { return nil }
        guard var text = String(data: plain, encoding: .utf8) else { return nil }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\""),
           let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data),
           let str = parsed as? String {
            return str
        }
        return text
    }

    private func evpBytesToKey(password: Data, salt: Data, keyLen: Int, ivLen: Int) -> (key: Data, iv: Data) {
        var chunks = Data()
        var prev = Data()
        while chunks.count < keyLen + ivLen {
            var block = Data()
            block.append(prev)
            block.append(password)
            block.append(salt)
            prev = md5(block)
            chunks.append(prev)
        }
        let key = chunks.prefix(keyLen)
        let iv = chunks.dropFirst(keyLen).prefix(ivLen)
        return (Data(key), Data(iv))
    }

    private func md5(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_MD5(buf.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    private func aes256CbcDecrypt(key: Data, iv: Data, data: Data) -> Data? {
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var outLen = 0
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outBuf in
            data.withUnsafeBytes { dataBuf in
                key.withUnsafeBytes { keyBuf in
                    iv.withUnsafeBytes { ivBuf in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBuf.baseAddress, key.count,
                            ivBuf.baseAddress,
                            dataBuf.baseAddress, data.count,
                            outBuf.baseAddress, out.count,
                            &outLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return out.prefix(outLen)
    }

    private func hexData(_ hex: String) -> Data? {
        let chars = Array(hex)
        guard chars.count % 2 == 0, !chars.isEmpty else { return nil }
        var out = Data()
        out.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let b = UInt8(String(chars[i..<(i + 2)]), radix: 16) else { return nil }
            out.append(b)
            i += 2
        }
        return out
    }
}
