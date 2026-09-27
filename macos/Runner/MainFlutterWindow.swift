import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Keep in sync with PageSettingsController.recommendedWindowWidth/Height (normal page width).
  static let defaultContentSize = NSSize(width: 1340, height: 960)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(MainFlutterWindow.defaultContentSize)
    self.center()
    self.setFrame(self.frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
