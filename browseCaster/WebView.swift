import SwiftUI
import WebKit

enum WebViewAction: Equatable {
    case load(URL)
    case goBack
    case goForward
    case reload
}

struct WebView: UIViewRepresentable {
    @Binding var action: WebViewAction?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var urlString: String
    let isURLFieldFocused: Bool
    let initialURL: URL?
    let streamStore: StreamStore

    private static let streamMessageHandlerName = "streamFound"

    private static let streamSnifferSource = """
    (function() {
      if (window.__browseCasterStreamSnifferInstalled) { return; }
      window.__browseCasterStreamSnifferInstalled = true;

      function shouldReport(url) {
        if (!url || typeof url !== "string") { return false; }
        var lower = url.toLowerCase();
        return lower.indexOf(".m3u8") !== -1 ||
               lower.indexOf(".mpd") !== -1 ||
               lower.indexOf(".mp4") !== -1 ||
               lower.indexOf(".ts") !== -1 ||
               lower.indexOf(".m4s") !== -1 ||
               lower.indexOf("blob:") === 0;
      }

      function normalize(url) {
        if (!url || typeof url !== "string") { return null; }
        try {
          return new URL(url, document.baseURI).toString();
        } catch (e) {
          return url;
        }
      }

      function report(url) {
        var normalized = normalize(url);
        if (!normalized || !shouldReport(normalized)) { return; }
        try {
          window.webkit.messageHandlers.streamFound.postMessage({ url: normalized, ts: Date.now() });
        } catch (e) {}
      }

      var originalFetch = window.fetch;
      if (originalFetch) {
        window.fetch = function() {
          try {
            var input = arguments[0];
            var url = null;
            if (typeof input === "string") {
              url = input;
            } else if (input && input.url) {
              url = input.url;
            }
            report(url);
          } catch (e) {}
          return originalFetch.apply(this, arguments);
        };
      }

      var originalOpen = XMLHttpRequest && XMLHttpRequest.prototype.open;
      if (originalOpen) {
        XMLHttpRequest.prototype.open = function(method, url) {
          try { report(url); } catch (e) {}
          return originalOpen.apply(this, arguments);
        };
      }

      var mediaProto = window.HTMLMediaElement && window.HTMLMediaElement.prototype;
      if (mediaProto) {
        var desc = Object.getOwnPropertyDescriptor(mediaProto, "src");
        if (desc && desc.set) {
          Object.defineProperty(mediaProto, "src", {
            get: desc.get,
            set: function(url) {
              try { report(url); } catch (e) {}
              return desc.set.call(this, url);
            }
          });
        }
      }
    })();
    """

    private static let streamSnifferScript = WKUserScript(
        source: streamSnifferSource,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.addUserScript(Self.streamSnifferScript)
        userContentController.add(
            WeakScriptMessageHandler(context.coordinator),
            name: Self.streamMessageHandlerName
        )
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let initialURL = initialURL {
            webView.load(URLRequest(url: initialURL))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self

        guard let action = action else { return }

        switch action {
        case .load(let url):
            uiView.load(URLRequest(url: url))
        case .goBack:
            if uiView.canGoBack {
                uiView.goBack()
            }
        case .goForward:
            if uiView.canGoForward {
                uiView.goForward()
            }
        case .reload:
            uiView.reload()
        }

        DispatchQueue.main.async {
            self.action = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateState(for: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateState(for: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(for: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            updateState(for: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            updateState(for: webView)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == WebView.streamMessageHandlerName else { return }

            var urlString: String?
            var timestamp = Date()

            if let body = message.body as? [String: Any] {
                urlString = body["url"] as? String
                if let ts = body["ts"] as? Double {
                    timestamp = Date(timeIntervalSince1970: ts / 1000)
                } else if let ts = body["ts"] as? Int {
                    timestamp = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
                } else if let ts = body["ts"] as? NSNumber {
                    timestamp = Date(timeIntervalSince1970: ts.doubleValue / 1000)
                }
            } else if let body = message.body as? String {
                urlString = body
            }

            guard let urlString = urlString else { return }

            DispatchQueue.main.async {
                self.parent.streamStore.record(urlString: urlString, at: timestamp)
            }
        }

        private func updateState(for webView: WKWebView) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            guard !parent.isURLFieldFocused, let url = webView.url else { return }
            parent.urlString = url.absoluteString
        }
    }

    final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var delegate: WKScriptMessageHandler?

        init(_ delegate: WKScriptMessageHandler) {
            self.delegate = delegate
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            delegate?.userContentController(userContentController, didReceive: message)
        }
    }
}
