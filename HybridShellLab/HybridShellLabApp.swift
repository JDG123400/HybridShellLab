import SwiftUI
import WebKit

@main
struct HybridShellLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppModel())
        }
    }
}

/// 全局状态: 脚本列表、桥日志、WebView 引用
final class AppModel: ObservableObject {
    @Published var scripts: [UserScript]
    @Published var logs: [String] = []
    @Published var bestScore = 0

    let bridge = NativeBridge()
    weak var webView: WKWebView?

    init() {
        scripts = Self.loadScripts()
        bridge.model = self
    }

    func log(_ text: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            self.logs.append("[\(formatter.string(from: Date()))] \(text)")
            if self.logs.count > 200 {
                self.logs.removeFirst(self.logs.count - 200)
            }
        }
    }

    /// 运行时注入单个脚本 (evaluateJavaScript)
    func inject(_ script: UserScript) {
        guard let webView else {
            log("⚠️ WebView 未就绪")
            return
        }
        webView.evaluateJavaScript(script.source) { _, error in
            if let error {
                self.log("❌ 注入失败 [\(script.name)]: \(error.localizedDescription)")
            } else {
                self.log("✅ 注入成功 [\(script.name)]")
            }
        }
    }

    /// 注入所有已启用的 documentEnd 脚本
    func injectEnabledScripts() {
        let list = scripts.filter { $0.enabled && !$0.atDocumentStart }
        guard !list.isEmpty else {
            log("⚠️ 没有已启用的 documentEnd 脚本")
            return
        }
        list.forEach(inject)
    }

    // MARK: - 脚本持久化

    private static let storageKey = "hybridshell.scripts.v1"

    func saveScripts() {
        if let data = try? JSONEncoder().encode(scripts) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func loadScripts() -> [UserScript] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([UserScript].self, from: data) {
            return saved
        }
        return DefaultScripts.all
    }
}
