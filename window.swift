import Cocoa

class CustomWindow {
    let size: [Double]     // These are never changed... should they be 'let'?
    let position: [Double] // These are never changed... should they be 'let'?
    let window: NSWindow! // A "Window" contains a window... that's a little odd.

    init(size: [Double], position: [Double], title: String, styleMasking: NSWindow.StyleMask) {
        self.size = size
        self.position = position

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: self.size[0], height: self.size[1]), styleMask: styleMasking, backing: .buffered, defer: true)
        window.title = title

        window.makeKeyAndOrderFront(nil)
    }

    convenience init() {
        self.init(size: [100, 100], position: [0, 0], title: "Untitled", styleMasking: [.closable, .titled, .resizable, .miniaturizable])
    }
}

let myWindow: CustomWindow = CustomWindow()

NSApplication.shared // Sets the value of `NSApp`
NSApp.setActivationPolicy(.regular)
NSApp.run()