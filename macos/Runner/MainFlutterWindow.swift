import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
    private var splashView: NSView?
    private var splashChannel: FlutterMethodChannel?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        self.contentViewController = flutterViewController
        // 窗口尺寸/位置在这里就定死并居中，避免启动画面先以 xib 的尺寸露出、
        // 等 Dart 侧 setSize 之后又跳一下（看起来就是窗口突然变形）
        self.setContentSize(NSSize(width: 420, height: 780))
        self.center()

        // 去掉原生标题栏的灰色横条：标题栏透明、标题文字隐藏，
        // 内容视图延伸到窗口顶部（红绿灯浮在应用背景上）。
        // Dart 侧会给顶部补 28pt 安全区，避免 AppBar 被红绿灯压住。
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.styleMask.insert(.fullSizeContentView)
        self.isMovableByWindowBackground = true

        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()

        installSplash()
        installSplashChannel(flutterViewController)
    }

    /// 启动画面。
    ///
    /// 首帧渲染之前 FlutterView 是空的，露出来的是引擎默认黑底；与其想办法藏掉，
    /// 不如盖一层品牌底色 + 应用图标，等 Flutter 画好后再淡出。
    private func installSplash() {
        guard let contentView = self.contentView else { return }

        // 跟随应用内选择的主题，而不是系统外观：
        // Dart 侧每次主题生效时把明暗写进 NSUserDefaults（flutter.splash_dark），
        // 这里读上一次的值；没有记录时才退回系统外观。
        let isDark: Bool
        if let saved = UserDefaults.standard.object(forKey: "flutter.splash_dark") as? Bool {
            isDark = saved
        } else {
            isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
        let background = isDark
            ? NSColor(srgbRed: 15.0 / 255.0, green: 14.0 / 255.0, blue: 29.0 / 255.0, alpha: 1.0)
            : NSColor(srgbRed: 233.0 / 255.0, green: 242.0 / 255.0, blue: 254.0 / 255.0, alpha: 1.0)
        let titleColor = isDark
            ? NSColor(calibratedWhite: 0.88, alpha: 1.0)
            : NSColor(calibratedWhite: 0.30, alpha: 1.0)

        let splash = NSView(frame: contentView.bounds)
        splash.autoresizingMask = [.width, .height]
        splash.wantsLayer = true
        splash.layer?.backgroundColor = background.cgColor

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(iconView)

        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "梦想云"
        let label = NSTextField(labelWithString: appName)
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = titleColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: splash.centerYAnchor, constant: -20),
            iconView.widthAnchor.constraint(equalToConstant: 88),
            iconView.heightAnchor.constraint(equalToConstant: 88),
            label.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
        ])

        contentView.addSubview(splash)
        splashView = splash

        // 兜底：Dart 侧没通知到也要能消失，不能把用户永久挡在启动画面
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.hideSplash()
        }
    }

    private func installSplashChannel(_ controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "mxycloud/splash",
            binaryMessenger: controller.engine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "hide" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.hideSplash()
            result(nil)
        }
        splashChannel = channel
    }

    private func hideSplash() {
        guard let splash = splashView else { return }
        splashView = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            splash.animator().alphaValue = 0
        }, completionHandler: {
            splash.removeFromSuperview()
        })
    }
}
