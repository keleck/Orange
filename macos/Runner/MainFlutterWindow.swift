import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
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

        // 首帧渲染前内容区是引擎默认的黑底，铺一层跟随系统外观的底色，
        // 避免无网络、初始化慢时先闪一个纯黑窗口。
        self.backgroundColor = MainFlutterWindow.launchBackgroundColor()
    }

    /// 与 Flutter 侧 AppColors.lightScaffold / 深色底色保持一致
    private static func launchBackgroundColor() -> NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if isDark {
            return NSColor(srgbRed: 15.0 / 255.0, green: 14.0 / 255.0, blue: 29.0 / 255.0, alpha: 1.0)
        }
        return NSColor(srgbRed: 237.0 / 255.0, green: 243.0 / 255.0, blue: 253.0 / 255.0, alpha: 1.0)
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
