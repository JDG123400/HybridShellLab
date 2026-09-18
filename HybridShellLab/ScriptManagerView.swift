import SwiftUI

struct ScriptManagerView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: UserScript?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($model.scripts) { $script in
                        scriptRow($script)
                    }
                } header: {
                    Text("用户脚本 (\(model.scripts.count))")
                } footer: {
                    Text("documentStart 脚本在页面加载前注入, 修改后需「重载页面」生效; documentEnd 脚本可随时点「注入已启用脚本」直接执行。")
                }
                Section {
                    Button {
                        model.scripts.append(UserScript(
                            name: "新脚本",
                            atDocumentStart: false,
                            enabled: false,
                            source: "// 在这里写 JS\nconsole.log('hello');\n"
                        ))
                    } label: {
                        Label("新建脚本", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("脚本管理")
            .onChange(of: model.scripts) { _ in model.saveScripts() }
            .sheet(item: $editing) { script in
                ScriptEditorView(script: script) { updated in
                    if let i = model.scripts.firstIndex(where: { $0.id == updated.id }) {
                        model.scripts[i] = updated
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scriptRow(_ script: Binding<UserScript>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(script.wrappedValue.name).font(.headline)
                Spacer()
                Toggle("", isOn: script.enabled).labelsHidden()
            }
            Text(script.wrappedValue.atDocumentStart ? "documentStart · 需重载生效" : "documentEnd · 可直接注入")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("注入") { model.inject(script.wrappedValue) }
                    .buttonStyle(.bordered)
                    .font(.caption)
                Button("编辑") { editing = script.wrappedValue }
                    .buttonStyle(.bordered)
                    .font(.caption)
                Spacer()
                Button(role: .destructive) {
                    model.scripts.removeAll { $0.id == script.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 脚本编辑器

struct ScriptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var script: UserScript
    var onSave: (UserScript) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $script.name)
                Toggle("documentStart 注入", isOn: $script.atDocumentStart)
                Section("JS 源码") {
                    TextEditor(text: $script.source)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 300)
                }
            }
            .navigationTitle("编辑脚本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(script)
                        dismiss()
                    }
                }
            }
        }
    }
}
