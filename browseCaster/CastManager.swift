import Foundation
import GoogleCast

final class CastManager: NSObject, ObservableObject {
    @Published var statusText: String = "Not connected"

    private let sessionManager: GCKSessionManager

    override init() {
        sessionManager = GCKCastContext.sharedInstance().sessionManager
        super.init()
        sessionManager.add(self)
        updateStatusForCurrentSession()
    }

    deinit {
        sessionManager.remove(self)
    }

    func cast(url: URL, kind: StreamKind, title: String?, assumeLive: Bool) {
        guard let castSession = sessionManager.currentCastSession,
              let remoteMediaClient = castSession.remoteMediaClient else {
            setStatus("Connect to a Cast device first.")
            return
        }

        let contentType: String
        switch kind {
        case .hlsManifest:
            contentType = "application/x-mpegURL"
        case .dashManifest:
            contentType = "application/dash+xml"
        case .mp4:
            contentType = "video/mp4"
        case .segment, .blob, .other:
            contentType = "application/octet-stream"
        }

        let streamType: GCKMediaStreamType = assumeLive ? .live : .buffered

        var metadata: GCKMediaMetadata?
        if let title = title, !title.isEmpty {
            let mediaMetadata = GCKMediaMetadata(metadataType: .generic)
            mediaMetadata.setString(title, forKey: kGCKMetadataKeyTitle)
            metadata = mediaMetadata
        }

        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.contentID = url.absoluteString
        builder.streamType = streamType
        builder.contentType = contentType
        builder.metadata = metadata

        let mediaInfo = builder.build()

        _ = remoteMediaClient.loadMedia(mediaInfo)
        setStatus("Casting…")
    }

    private func updateStatusForCurrentSession() {
        guard let session = sessionManager.currentCastSession else {
            setStatus("Not connected")
            return
        }

        let deviceName = session.device.friendlyName ?? "Cast device"
        setStatus("Connected to \(deviceName)")
    }

    private func setStatus(_ text: String) {
        if Thread.isMainThread {
            statusText = text
        } else {
            DispatchQueue.main.async {
                self.statusText = text
            }
        }
    }
}

extension CastManager: GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        updateStatusForCurrentSession()
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didResumeSession session: GCKSession) {
        updateStatusForCurrentSession()
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        if let error = error {
            setStatus("Cast failed: \(error.localizedDescription)")
        } else {
            setStatus("Not connected")
        }
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStartSessionWithError error: Error) {
        setStatus("Cast failed: \(error.localizedDescription)")
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didFailToResumeSessionWithError error: Error) {
        setStatus("Cast failed: \(error.localizedDescription)")
    }
}
