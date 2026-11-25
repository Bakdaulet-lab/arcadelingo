import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "arcadelingo/daily_word_share", binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak controller] call, result in
        guard call.method == "shareText" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let grid = call.arguments as? String, !grid.isEmpty,
              let controller = controller, controller.viewIfLoaded?.window != nil else {
          result(false)
          return
        }
        var presenter: UIViewController = controller
        while let presented = presenter.presentedViewController {
          presenter = presented
        }
        guard !presenter.isBeingDismissed, !presenter.isBeingPresented else {
          result(false)
          return
        }
        let sheet = UIActivityViewController(activityItems: [grid], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
          let view = presenter.view!
          popover.sourceView = view
          popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
          popover.permittedArrowDirections = []
        }
        presenter.present(sheet, animated: true) { result(true) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
