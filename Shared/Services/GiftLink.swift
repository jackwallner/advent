import Foundation

/// A calendar made for someone else. It travels entirely inside its link, so there is no server.
/// Format matches `giftLink` / `parseGift` in docs/index.html.
struct Gift: Equatable, Sendable {
    var year: Int
    var to: String
    var from: String
    var note: String
    var seed: UInt32
    var days: [String]

    static let base = "https://jackwallner.com/ios/advent/"

    private struct Payload: Codable {
        let y: Int
        let t: String
        let f: String
        let m: String
        let l: UInt32
        let d: String
    }

    var url: URL {
        let payload = Payload(y: year, t: to, f: from, m: note, l: seed, d: Gift.encodeDays(days))
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        return URL(string: Gift.base + "#g=" + Gift.base64URL(data))!
    }

    init(year: Int, to: String, from: String, note: String, seed: UInt32, days: [String]) {
        self.year = year
        self.to = to
        self.from = from
        self.note = note
        self.seed = seed
        self.days = days
    }

    init?(url: URL, library: ContentLibrary) {
        guard let fragment = url.fragment, fragment.hasPrefix("g=") else { return nil }
        var b64 = String(fragment.dropFirst(2))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        let days = Gift.decodeDays(p.d)
        guard days.count == CalendarBuilder.dayCount, days.allSatisfy({ library.byID[$0] != nil }) else { return nil }
        self.init(year: p.y, to: p.t, from: p.f, note: p.m, seed: p.l, days: days)
    }

    static func encodeDays(_ ids: [String]) -> String {
        ids.compactMap { id -> String? in
            let parts = id.split(separator: "-")
            guard parts.count == 2, let cat = Category(rawValue: String(parts[0])), let n = Int(parts[1]) else { return nil }
            return "\(cat.code)\(n)"
        }.joined(separator: ".")
    }

    static func decodeDays(_ s: String) -> [String] {
        s.split(separator: ".").compactMap { token -> String? in
            guard let first = token.first,
                  let cat = Category.allCases.first(where: { $0.code == first }),
                  let n = Int(token.dropFirst()) else { return nil }
            return String(format: "%@-%02d", cat.rawValue, n)
        }
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
