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
    let access = BookletFileAccess()
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
        case "rememberAccess":
          try access.remember(destination)
          result(nil)
        case "restoreAccess":
          result(try access.restore(destination).path)
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


// Each engine retains access while its document is in use. Releasing the engine
// balances all successful security-scope acquisitions.
private final class BookletFileAccess {
  private var active: [String: URL] = [:]
  private let defaults = UserDefaults.standard
  private let key = "booklet.fileBookmarks.v1"

  func remember(_ url: URL) throws {
    let data = try url.bookmarkData(options: [.withSecurityScope],
      includingResourceValuesForKeys: nil, relativeTo: nil)
    var bookmarks = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    bookmarks[url.path] = data
    defaults.set(bookmarks, forKey: key)
  }

  func restore(_ original: URL) throws -> URL {
    if let url = active[original.path] { return url }
    let bookmarks = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    guard let data = bookmarks[original.path] else { return original }
    var stale = false
    let url = try URL(resolvingBookmarkData: data,
      options: [.withSecurityScope, .withoutUI], relativeTo: nil,
      bookmarkDataIsStale: &stale)
    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
    }
    active[original.path] = url
    if stale {
      // Access is already granted even if refreshing the bookmark fails.
      try? remember(url)
    }
    return url
  }

  deinit {
    for url in active.values { url.stopAccessingSecurityScopedResource() }
  }
}
