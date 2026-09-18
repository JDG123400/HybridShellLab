import SwiftUI
import WebKit

// MARK: - 壳页面 (地址栏 + WebView + 控制条)

struct WebViewScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var urlString = "bundle://demo.html"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("bundle://demo.html 或 https://你的页面", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.footnote, design: .monospaced))
                        .onSubmit(load)
                    Button("前往", action: load)
                        .buttonStyle(.bordered)
                    Button {
                        urlString = "bundle://demo.html"
                        load()
                    } label: {
                        Image(systemName: "house")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ShellWebView(model: model)
                    .ignoresSafeArea(edges: .bottom)

                HStack {
                    Button("重载页面") { model.webView?.reload() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("注入已启用脚本") { model.injectEnabledScripts() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("混合壳演示")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func load() {
        guard let webView = model.webView else { return }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("bundle://") {
            webView.loadDemoPage()
            model.log("🔄 加载内置演示页 demo.html")
        } else if let url = URL(string: trimmed), let scheme = url.scheme,
                  scheme == "http" || scheme == "https" {
            webView.load(URLRequest(url: url))
            model.log("🔄 加载: \(trimmed)")
        } else {
            model.log("⚠️ 仅支持 http(s) 或 bundle:// 地址")
        }
    }
}

// MARK: - WKWebView 壳

struct ShellWebView: UIViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let bridge = NativeBridge()

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.model?.log("✅ 页面加载完成")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            bridge.model?.log("❌ 加载失败: \(error.localizedDescription)")
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.bridge.model = model

        let content = WKUserContentController()

        // 固定注入: 悬浮控制面板 (documentStart) —— 对应真实壳里"内嵌脚本"的做法
        content.addUserScript(WKUserScript(
            source: Self.panelScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // 用户启用且标记为 documentStart 的脚本
        for script in model.scripts where script.enabled && script.atDocumentStart {
            content.addUserScript(WKUserScript(
                source: script.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        // 注册原生桥
        content.add(context.coordinator.bridge, name: NativeBridge.name)

        let config = WKWebViewConfiguration()
        config.userContentController = content

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        model.webView = webView
        webView.loadDemoPage()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // 注入到页面的悬浮面板: 速度倍率 / 自动点击 / 上报分数, 全部通过桥回传原生
    static let panelScript = """
    (function () {
      if (window.__shellPanelMounted) { return; }
      window.__shellPanelMounted = true;

      function post(cmd, payload) {
        var msg = JSON.stringify({ cmd: cmd, payload: payload });
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shell) {
          window.webkit.messageHandlers.shell.postMessage(msg);
        }
      }

      var btn = document.createElement('div');
      btn.textContent = '⚙';
      btn.style.cssText = 'position:fixed;right:14px;top:70px;width:44px;height:44px;border-radius:22px;' +
        'background:rgba(20,20,30,.85);color:#fff;font-size:22px;text-align:center;line-height:44px;' +
        'z-index:2147483647;user-select:none;';

      var panel = null;
      var autoTimer = null;

      function mount() {
        if (!document.body) { return; }
        document.body.appendChild(btn);
        btn.addEventListener('touchstart', toggle, { passive: true });
      }

      function toggle() {
        if (panel) { panel.remove(); panel = null; return; }
        panel = document.createElement('div');
        panel.style.cssText = 'position:fixed;right:14px;top:124px;width:200px;padding:12px;' +
          'background:rgba(20,20,30,.92);border-radius:12px;z-index:2147483647;color:#fff;' +
          'font-size:13px;display:flex;flex-direction:column;gap:8px;';
        panel.innerHTML =
          '<b>注入控制面板</b>' +
          '<button data-a="1">速度 x1</button>' +
          '<button data-a="2">速度 x2</button>' +
          '<button data-a="5">速度 x5</button>' +
          '<button data-a="auto">自动点击 开/关</button>' +
          '<button data-a="score">上报分数给 App</button>';
        Array.prototype.forEach.call(panel.querySelectorAll('button'), function (b) {
          b.style.cssText = 'padding:8px;border:0;border-radius:8px;background:#3b82f6;color:#fff;font-size:13px;';
          b.addEventListener('click', function () { act(b.getAttribute('data-a')); });
        });
        document.body.appendChild(panel);
      }

      function act(a) {
        if (!window.game) { post('log', '未检测到 window.game (当前页面不是演示页)'); return; }
        if (a === 'auto') {
          if (autoTimer) { clearInterval(autoTimer); autoTimer = null; post('log', '自动点击: 关'); }
          else {
            autoTimer = setInterval(function () { window.game.click(); }, 200);
            post('log', '自动点击: 开');
          }
          return;
        }
        if (a === 'score') { post('score', window.game.getScore()); return; }
        var n = parseInt(a, 10);
        if (n) { window.game.setSpeed(n); post('log', '速度已设为 x' + n); }
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', mount);
      } else { mount(); }
    })();
    """
}

extension WKWebView {
    func loadDemoPage() {
        if let url = Bundle.main.url(forResource: "demo", withExtension: "html") {
            loadFileURL(url, allowingReadAccessTo: Bundle.main.resourceURL ?? url)
        } else {
            loadHTMLString("<h1>demo.html 缺失</h1>", baseURL: nil)
        }
    }
}
