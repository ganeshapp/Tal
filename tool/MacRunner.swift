import Cocoa
import FlutterMacOS
import shared_preferences_foundation
import path_provider_foundation

final class TalDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var controller: FlutterViewController!
  func applicationDidFinishLaunching(_ notification: Notification) {
    controller = FlutterViewController(project: FlutterDartProject())
    SharedPreferencesPlugin.register(with: controller.registrar(forPlugin: "SharedPreferencesPlugin"))
    PathProviderPlugin.register(with: controller.registrar(forPlugin: "PathProviderPlugin"))
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
                      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Tal"
    window.minSize = NSSize(width: 640, height: 640)
    window.contentViewController = controller
    window.setContentSize(NSSize(width: 1180, height: 820))
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct TalLauncher {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = TalDelegate()
    app.delegate = delegate
    let menu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About Tal", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit Tal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    menu.addItem(appItem)
    let edit = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    edit.submenu = editMenu; menu.addItem(edit)
    app.mainMenu = menu
    withExtendedLifetime(delegate) { app.run() }
  }
}
