import WebKit
import UIKit

/// JS ↔ Native 桥: 页面通过 webkit.messageHandlers.shell.postMessage(JSON 字符串) 调用原生
///
/// 约定消息格式: { "cmd": "log|score|vibrate", "payload": ... }
/// 这与真实混合壳里 "QVQ.saveFile" 之类的原生桥是同一套原理
final class NativeBridge: NSObject, WKScriptMessageHandler {
    static let name = "shell"
    weak var model: AppModel?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }

        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cmd = obj["cmd"] as? String else {
            model?.log("↩︎ 收到消息: \(body)")
            return
        }

        switch cmd {
        case "log":
            model?.log("📄 页面: \(obj["payload"] as? String ?? "")")
        case "score":
            let score = obj["payload"] as? Int ?? 0
            model?.log("🏆 页面上报分数: \(score)")
            if score > model?.bestScore ?? 0 {
                model?.bestScore = score
            }
        case "vibrate":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            model?.log("📳 原生震动已触发")
        default:
            model?.log("❓ 未知指令: \(cmd)")
        }
    }
}
