import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WebViewScreen()
                .tabItem { Label("壳 Shell", systemImage: "safari") }
            ScriptManagerView()
                .tabItem { Label("脚本", systemImage: "doc.text.fill") }
            BridgeLogView()
                .tabItem { Label("桥日志", systemImage: "terminal") }
        }
    }
}

// MARK: - 桥日志 + 说明

struct BridgeLogView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("统计") {
                    LabeledContent("历史最高分", value: "\(model.bestScore)")
                    LabeledContent("日志条数", value: "\(model.logs.count)")
                }
                Section("JS ↔ Native 通信日志") {
                    if model.logs.isEmpty {
                        Text("暂无日志, 去演示页点点看")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.logs.enumerated().reversed()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                Section("学习要点") {
                    Text("本工程演示混合壳核心技术: WKWebView 壳、WKUserScript 注入、scriptMessageHandler 原生桥、脚本管理器与持久化。")
                    Text("仅对你拥有或获得授权的页面使用注入能力, 对第三方页面注入可能违反其服务条款。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("桥日志")
            .toolbar {
                Button("清空") { model.logs.removeAll() }
            }
        }
    }
}
