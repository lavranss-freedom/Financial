import Foundation

enum AnalyzeBrief {
    static func generate(for h: Holding, moonshotPct: Double) -> String {
        let ret = PortfolioCalc.holdingReturnPct(h)
        let px = h.last ?? h.gav
        var lines: [String] = []
        lines.append("## \(h.symbol) — \(h.name)")
        lines.append("")
        lines.append("**Sleeve:** \(h.sleeve.rawValue)\(h.excluded == true ? " (EXCLUDED)" : "")")
        lines.append("**GAV:** \(Formatters.price(h.gav, h.currency)) → **Last:** \(Formatters.price(px, h.currency)) (\(Formatters.pct(ret)))")
        lines.append("**Qty:** \(Formatters.num(h.qty, digits: 0)) whole shares")
        if let day = h.dayChangePercent {
            lines.append("**Day:** \(Formatters.pct(day)) (delayed)")
        }
        if let ah = h.afterHoursChangePercent {
            lines.append("**After-hours:** \(Formatters.pct(ah))")
        }
        lines.append("")
        lines.append("### Mandate check")
        lines.append("- Goal: seek 20%+ multi-year outcomes; current mark \(Formatters.pct(ret)) vs GAV.")
        lines.append("- Whole shares only — no fractional theater.")
        lines.append("- No leverage / no margin.")
        if h.sleeve == .moonshot {
            lines.append("- Moonshot sleeve: book moonshots now ~\(Formatters.num(moonshotPct, digits: 1))% (cap ≤3%).")
        } else {
            lines.append("- Moonshot sleeve of book: ~\(Formatters.num(moonshotPct, digits: 1))% (cap ≤3%).")
        }
        lines.append("")
        if let plan = h.plan, !plan.isEmpty {
            lines.append("### Plan")
            lines.append(plan)
            lines.append("")
        }
        if let trigger = h.trigger, !trigger.isEmpty {
            lines.append("### Trigger")
            lines.append(trigger)
            lines.append("")
        }
        lines.append("### Brief")
        if h.dead == true || h.excluded == true {
            lines.append("Position ignored for weights. Keep at zero economic weight; no add.")
        } else if let r = ret, r >= 20 {
            lines.append("Mark is at/above 20% goal band vs GAV. Re-underwrite thesis; trim only if sizing crowds out better risk/reward — not for celebration.")
        } else if let r = ret, r <= -20 {
            lines.append("Drawdown ≥20% vs GAV. Kill criteria first: if thesis broken, exit. If intact, size and patience — no average-down ritual without a fresh edge.")
        } else {
            lines.append("Within normal band vs GAV. Hold if thesis intact; adds only on plan/trigger and whole-share lots.")
        }
        return lines.joined(separator: "\n")
    }
}

enum Formatters {
    static func nok(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = " "
        return (f.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " NOK"
    }

    static func usd(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = " "
        return "$" + (f.string(from: NSNumber(value: value)) ?? "\(Int(value))")
    }

    static func num(_ value: Double, digits: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = digits
        f.groupingSeparator = " "
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func pct(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value > 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, value)
    }

    static func price(_ value: Double, _ currency: AssetCurrency) -> String {
        String(format: "%.2f %@", value, currency.rawValue)
    }
}
