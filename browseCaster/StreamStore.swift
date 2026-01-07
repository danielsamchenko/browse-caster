import Combine
import Foundation

struct StreamCandidate: Identifiable {
    var url: String
    var host: String
    var kind: StreamKind
    var firstSeen: Date
    var lastSeen: Date
    var hitCount: Int
    var score: Int

    var id: String { url }
}

final class StreamStore: ObservableObject {
    @Published private(set) var candidatesByURL: [String: StreamCandidate] = [:]
    @Published var showOnlyManifests = true

    var visibleCandidates: [StreamCandidate] {
        let values = candidatesByURL.values
        let filtered = showOnlyManifests ? values.filter { $0.kind.isManifestLike } : Array(values)
        return filtered.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            if $0.lastSeen != $1.lastSeen {
                return $0.lastSeen > $1.lastSeen
            }
            return $0.url < $1.url
        }
    }

    func record(urlString: String, at date: Date = Date()) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var existing = candidatesByURL[trimmed] {
            existing.hitCount += 1
            existing.lastSeen = date
            existing.score = score(for: existing.kind, hitCount: existing.hitCount)
            candidatesByURL[trimmed] = existing
            return
        }

        let kind = classify(urlString: trimmed)
        let candidate = StreamCandidate(
            url: trimmed,
            host: host(for: trimmed),
            kind: kind,
            firstSeen: date,
            lastSeen: date,
            hitCount: 1,
            score: score(for: kind, hitCount: 1)
        )

        candidatesByURL[trimmed] = candidate
        print("Stream candidate found: \(trimmed)")
    }

    func clear() {
        candidatesByURL.removeAll()
    }

    private func host(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "unknown" }
        if let host = url.host {
            return host
        }
        if let scheme = url.scheme {
            return scheme
        }
        return "unknown"
    }

    private func score(for kind: StreamKind, hitCount: Int) -> Int {
        baseScore(for: kind) + min(hitCount, 20)
    }
}
