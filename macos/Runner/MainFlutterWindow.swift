import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Set minimum window size
    self.minSize = NSSize(width: 1050, height: 500)

    // Maximize window on launch
    if let screen = self.screen {
      self.setFrame(screen.visibleFrame, display: true)
    }
  }
}
