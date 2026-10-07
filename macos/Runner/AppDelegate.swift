import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var openFileChannel: FlutterMethodChannel?
  private var pendingPath: String?
  private var dartIsListening = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = NSApp.windows
      .compactMap { $0.contentViewController as? FlutterViewController }
      .first
    if let controller = controller {
      let channel = FlutterMethodChannel(
        name: "booklet/open_file",
        binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self, call.method == "takeInitialFile" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.dartIsListening = true
        result(self.pendingPath)
        self.pendingPath = nil
      }
      openFileChannel = channel
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let path = urls.first(where: { $0.isFileURL })?.path else {
      super.application(application, open: urls)
      return
    }
    if dartIsListening {
      openFileChannel?.invokeMethod("openFile", arguments: path)
    } else {
      pendingPath = path
    }
  }
}
