import Foundation

enum StreamKind: String {
    case hlsManifest
    case dashManifest
    case mp4
    case segment
    case blob
    case other

    var label: String {
        switch self {
        case .hlsManifest:
            return "HLS"
        case .dashManifest:
            return "DASH"
        case .mp4:
            return "MP4"
        case .segment:
            return "SEG"
        case .blob:
            return "BLOB"
        case .other:
            return "OTHER"
        }
    }

    var isManifestLike: Bool {
        switch self {
        case .hlsManifest, .dashManifest, .mp4:
            return true
        case .segment, .blob, .other:
            return false
        }
    }
}

func classify(urlString: String) -> StreamKind {
    let lowercased = urlString.lowercased()

    if lowercased.hasPrefix("blob:") {
        return .blob
    }

    if lowercased.contains(".m3u8") {
        return .hlsManifest
    }

    if lowercased.contains(".mpd") {
        return .dashManifest
    }

    if lowercased.contains(".mp4") {
        return .mp4
    }

    if lowercased.contains(".m4s") || lowercased.contains(".ts") {
        return .segment
    }

    return .other
}

func baseScore(for kind: StreamKind) -> Int {
    switch kind {
    case .hlsManifest:
        return 100
    case .dashManifest:
        return 95
    case .mp4:
        return 80
    case .segment:
        return 10
    case .blob:
        return 0
    case .other:
        return 1
    }
}

func formatLastSeen(_ date: Date, relativeTo now: Date = Date()) -> String {
    let elapsed = max(0, Int(now.timeIntervalSince(date)))

    if elapsed < 5 {
        return "now"
    }

    if elapsed < 60 {
        return "\(elapsed)s"
    }

    let minutes = elapsed / 60
    if minutes < 60 {
        return "\(minutes)m"
    }

    let hours = minutes / 60
    if hours < 24 {
        return "\(hours)h"
    }

    let days = hours / 24
    return "\(days)d"
}
