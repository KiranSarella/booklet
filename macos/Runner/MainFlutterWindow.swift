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
    MainFlutterWindow.registerDocumentFileChannel(flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      // Register plugins for each window spawned via desktop_multi_window.
      RegisterGeneratedPlugins(registry: controller)
      MainFlutterWindow.registerDocumentFileChannel(controller)
    }

    super.awakeFromNib()
  }

  // Foundation's replacement directory supports safe saves to user-selected
  // files under the macOS sandbox, including documents on external volumes.
  static func registerDocumentFileChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "booklet/document_file", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard let arguments = call.arguments as? [String: String],
            let path = arguments["destination"] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let manager = FileManager.default
      let destination = URL(fileURLWithPath: path)
      do {
        switch call.method {
        case "prepareSave":
          let directory = try manager.url(for: .itemReplacementDirectory,
            in: .userDomainMask, appropriateFor: destination, create: true)
          result(directory.path)
        case "commitSave":
          guard let sourcePath = arguments["source"] else {
            result(FlutterError(code: "save_failed", message: "Missing staged document", details: nil))
            return
          }
          let source = URL(fileURLWithPath: sourcePath)
          var isDirectory: ObjCBool = false
          if manager.fileExists(atPath: path, isDirectory: &isDirectory) {
            let backup = isDirectory.boolValue
              ? destination.lastPathComponent + ".legacy-" + UUID().uuidString : nil
            let options: FileManager.ItemReplacementOptions = isDirectory.boolValue
              ? .withoutDeletingBackupItem : []
            _ = try manager.replaceItemAt(destination, withItemAt: source,
              backupItemName: backup, options: options)
          } else {
            try manager.moveItem(at: source, to: destination)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

}

