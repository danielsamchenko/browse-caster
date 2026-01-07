import SwiftUI
import UIKit

struct BrowserView: View {
    @State private var urlString = "https://example.com"
    @State private var webViewAction: WebViewAction?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var showInvalidURLAlert = false
    @FocusState private var isURLFieldFocused: Bool
    @StateObject private var streamStore = StreamStore()
    @StateObject private var castManager = CastManager()
    @State private var assumeLive = false

    private let initialURL = URL(string: "https://example.com")
    private let streamPanelHeight: CGFloat = 220

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Enter URL", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .submitLabel(.go)
                        .focused($isURLFieldFocused)
                        .onSubmit { loadFromField() }

                    Button("Go") { loadFromField() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                HStack {
                    Toggle("Manifests only", isOn: $streamStore.showOnlyManifests)
                    Spacer()
                    Button("Clear") { streamStore.clear() }
                        .buttonStyle(.bordered)
                }
                .font(.subheadline)
                .padding(.horizontal)

                HStack(spacing: 24) {
                    Button {
                        webViewAction = .goBack
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Back")

                    Button {
                        webViewAction = .goForward
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Forward")

                    Button {
                        webViewAction = .reload
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")
                }
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal)

                Divider()

                WebView(
                    action: $webViewAction,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    urlString: $urlString,
                    isURLFieldFocused: isURLFieldFocused,
                    initialURL: initialURL,
                    streamStore: streamStore
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

                Divider()

                HStack {
                    Text(castManager.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Assume Live", isOn: $assumeLive)
                }
                .padding(.horizontal)

                streamList
                    .frame(maxWidth: .infinity)
                    .frame(height: streamPanelHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("browseCaster")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CastButtonView()
                        .frame(width: 28, height: 28)
                }
            }
            .alert("Invalid URL", isPresented: $showInvalidURLAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a valid URL to continue.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func loadFromField() {
        guard let url = normalizedURL(from: urlString) else {
            showInvalidURLAlert = true
            return
        }

        isURLFieldFocused = false
        urlString = url.absoluteString
        webViewAction = .load(url)
    }

    private func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private var streamList: some View {
        List {
            Section(header: Text("Detected Streams")) {
                if streamStore.visibleCandidates.isEmpty {
                    Text("No streams yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(streamStore.visibleCandidates) { candidate in
                        StreamCandidateRow(
                            candidate: candidate,
                            canCast: URL(string: candidate.url) != nil
                        ) {
                            guard let url = URL(string: candidate.url) else {
                                castManager.statusText = "Cast failed: invalid URL."
                                return
                            }

                            castManager.cast(
                                url: url,
                                kind: candidate.kind,
                                title: candidate.host,
                                assumeLive: assumeLive
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct StreamCandidateRow: View {
    let candidate: StreamCandidate
    let canCast: Bool
    let onCast: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(candidate.kind.label) • \(candidate.score)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cast", action: onCast)
                    .buttonStyle(.bordered)
                    .disabled(!canCast)
            }

            HStack {
                Text(candidate.host)
                Spacer()
                Text("Hits \(candidate.hitCount)")
                Text("Last \(formatLastSeen(candidate.lastSeen))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(candidate.url)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy URL") {
                UIPasteboard.general.string = candidate.url
            }
        }
    }
}
