import Foundation

/// 用户脚本模型 —— 对应油猴式脚本引擎的最小实现
struct UserScript: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// true = documentStart (页面加载前注入, 需重载生效)
    /// false = documentEnd (可随时用 evaluateJavaScript 注入)
    var atDocumentStart: Bool
    var enabled: Bool
    var source: String
}

/// 内置示例脚本 —— 只操作打包在 App 内的 demo.html
enum DefaultScripts {
    static let all: [UserScript] = [
        UserScript(
            name: "标题变色 (documentStart)",
            atDocumentStart: true,
            enabled: true,
            source: """
            // documentStart 演示: 页面加载前注入
            (function () {
              function go() {
                var h1 = document.querySelector('h1');
                if (h1) { h1.style.color = '#7c3aed'; }
              }
              if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', go);
              } else { go(); }
            })();
            """
        ),
        UserScript(
            name: "浮动提示 (documentEnd)",
            atDocumentStart: false,
            enabled: true,
            source: """
            // documentEnd 演示: 向页面注入浮动文字效果
            (function () {
              function float(text) {
                var el = document.createElement('div');
                el.textContent = text;
                el.style.cssText = 'position:fixed;left:50%;top:20%;transform:translateX(-50%);' +
                  'padding:8px 16px;background:rgba(0,0,0,.75);color:#fff;border-radius:20px;' +
                  'z-index:99999;font-size:14px;transition:all 1s ease;opacity:1;';
                document.body.appendChild(el);
                requestAnimationFrame(function () { el.style.top = '10%'; el.style.opacity = '0'; });
                setTimeout(function () { el.remove(); }, 1100);
              }
              if (!window.__floatTextInstalled) {
                window.__floatTextInstalled = true;
                document.addEventListener('click', function () { float('✨ 注入脚本生效'); }, true);
              }
              float('脚本已注入');
            })();
            """
        ),
        UserScript(
            name: "自动点击器 (documentEnd)",
            atDocumentStart: false,
            enabled: false,
            source: """
            // 演示: 定时器自动调用页面暴露的 window.game 接口 (仅本地 demo.html)
            (function () {
              if (window.__autoClicker) {
                clearInterval(window.__autoClicker);
                window.__autoClicker = null;
                return;
              }
              window.__autoClicker = setInterval(function () {
                if (window.game && window.game.click) { window.game.click(); }
              }, 200);
            })();
            """
        )
    ]
}
