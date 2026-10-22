import Cocoa
import AVFoundation
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

      let thumbnailChannel = FlutterMethodChannel(
        name: "booklet/video_thumbnail",
        binaryMessenger: controller.engine.binaryMessenger)
      thumbnailChannel.setMethodCallHandler { call, result in
        guard call.method == "createVideoThumbnail",
              let arguments = call.arguments as? [String: String],
              let videoPath = arguments["videoPath"],
              let thumbnailPath = arguments["thumbnailPath"] else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          let video = AVURLAsset(url: URL(fileURLWithPath: videoPath))
          let generator = AVAssetImageGenerator(asset: video)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: 320, height: 320)
          let duration = video.duration.seconds
          let time = CMTime(seconds: duration.isFinite ? min(1, duration / 2) : 0, preferredTimescale: 600)
          let image = try generator.copyCGImage(at: time, actualTime: nil)
          let bitmap = NSBitmapImageRep(cgImage: image)
          guard let data = bitmap.representation(using: .png, properties: [:]) else {
            result(false)
            return
          }
          try data.write(to: URL(fileURLWithPath: thumbnailPath), options: .atomic)
          result(true)
        } catch {
          result(FlutterError(code: "thumbnail_failed", message: error.localizedDescription, details: nil))
        }
      }
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
