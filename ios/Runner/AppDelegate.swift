import Flutter
import FirebaseCore
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClipboardImage") {
      registerClipboardImage(messenger: registrar.messenger())
    }
  }

  /// "Paste copied photo" (lib/core/clipboard/clipboard_image_io.dart):
  /// the copied image as a JPEG, fitted within maxWidth × maxHeight, or
  /// nil if nothing copied is an image.
  private func registerClipboardImage(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "squad_hq/clipboard_image", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "readImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let maxWidth = CGFloat(args["maxWidth"] as? Int ?? 1280)
      let maxHeight = (args["maxHeight"] as? Int).map { CGFloat($0) } ?? .greatestFiniteMagnitude
      let quality = CGFloat(args["quality"] as? Int ?? 80) / 100
      // Reading the pasteboard may show iOS's "Allow Paste" prompt.
      guard UIPasteboard.general.hasImages, let image = UIPasteboard.general.image else {
        result(nil)
        return
      }
      let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
      let scale = min(1, maxWidth / pixels.width, maxHeight / pixels.height)
      let size = CGSize(width: max(1, (pixels.width * scale).rounded()), height: max(1, (pixels.height * scale).rounded()))
      let format = UIGraphicsImageRendererFormat.default()
      format.scale = 1
      format.opaque = true
      let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        image.draw(in: CGRect(origin: .zero, size: size))
      }
      guard let jpeg = resized.jpegData(compressionQuality: quality) else {
        result(nil)
        return
      }
      result(FlutterStandardTypedData(bytes: jpeg))
    }
  }
}
