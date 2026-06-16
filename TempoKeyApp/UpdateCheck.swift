import Foundation

struct AppUpdate: Equatable {
    let version: String   // e.g. "1.1.0" (release tag, "v" stripped for display where shown)
    let url: URL          // the GitHub release page to download from
}

/// Lightweight update check against the GitHub Releases API. No third-party deps; the app
/// stays sandboxed and only needs the network-client entitlement (outbound only).
enum UpdateCheck {
    /// GitHub "owner/repo" the app checks for releases. If wrong, the check fails silently
    /// (no banner) — it never blocks or crashes the app.
    static let repository = "tekvisions/TempoKey"

    static func currentVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// Fetches the latest published release; returns nil on any failure (offline, 404, etc.).
    static func latest() async -> AppUpdate? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")
        else { return nil }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        guard
            let (data, resp) = try? await URLSession.shared.data(for: req),
            (resp as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            let pageStr = json["html_url"] as? String,
            let page = URL(string: pageStr)
        else { return nil }
        return AppUpdate(version: tag, url: page)
    }

    /// True if semantic version `latest` is strictly newer than `current`. Tolerant of a leading
    /// "v" and of non-numeric suffixes (compares the first three numeric components).
    static func isNewer(_ latest: String, than current: String) -> Bool {
        func components(_ s: String) -> [Int] {
            let cleaned = s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            return cleaned.split(separator: ".").prefix(3).map { part in
                Int(part.prefix(while: \.isNumber)) ?? 0
            }
        }
        let a = components(latest), b = components(current)
        for i in 0..<3 {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
