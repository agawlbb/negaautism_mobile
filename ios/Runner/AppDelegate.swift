import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {
  private var exportResult: FlutterResult?
  private var exportDirectory: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let started = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "org.negaautism.mobileapp/documents", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "savePdf" else { result(FlutterMethodNotImplemented); return }
        self?.savePdf(call, result: result)
      }
    }
    return started
  }

  private func savePdf(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard exportResult == nil else { result(FlutterError(code: "busy", message: "A document export is already open.", details: nil)); return }
    guard let arguments = call.arguments as? [String: Any],
          let value = arguments["bytes"] as? FlutterStandardTypedData,
          let filename = arguments["filename"] as? String,
          filename.range(of: "^[a-zA-Z0-9_-]+\\.pdf$", options: .regularExpression) != nil,
          value.data.count >= 5, value.data.count <= 15 * 1024 * 1024,
          String(data: value.data.prefix(5), encoding: .ascii) == "%PDF-",
          var presenter = window?.rootViewController else {
      result(FlutterError(code: "invalid", message: "The PDF could not be exported.", details: nil)); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let file = directory.appendingPathComponent(filename)
      try value.data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
      let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      picker.delegate = self
      exportResult = result
      exportDirectory = directory
      presenter.present(picker, animated: true)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      result(FlutterError(code: "write_failed", message: "The PDF could not be prepared for export.", details: nil))
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishExport(true)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finishExport(false) }
  private func finishExport(_ saved: Bool) {
    let result = exportResult
    exportResult = nil
    if let directory = exportDirectory { try? FileManager.default.removeItem(at: directory) }
    exportDirectory = nil
    result?(saved)
  }
}
