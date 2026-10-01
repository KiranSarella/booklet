import Cocoa
import FlutterMacOS
import desktop_multi_window

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

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      // Register plugins for each window spawned via desktop_multi_window.
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}

