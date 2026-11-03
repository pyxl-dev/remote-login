// rl-helper: finds the Claude desktop browser pane and drives it with real
// mouse and keyboard events, so a person on their phone can sign in there.
//
//   rl-helper status                 -> {"locked":bool,"ax":bool}
//   rl-helper locate [host]          -> {"x","y","w","h","url"} of the pane page (points)
//   rl-helper click X Y              -> left click at global point
//   rl-helper type                   -> types UTF-8 text read from stdin
//   rl-helper key NAME               -> enter|tab|shifttab|backspace|clear|escape|left|right|up|down|selectall
//   rl-helper scroll X Y DY          -> scroll wheel at point (DY > 0 scrolls down)
//
// Permissions (Accessibility, Screen Recording) come from the responsible
// process: run it from a Claude Code session in the desktop app.
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

let bundleId = "com.anthropic.claudefordesktop"

func out(_ obj: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("rl-helper: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

func claudeApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
}

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(e, name as CFString, &v)
    return v
}

struct WebArea { var url: String; var frame: CGRect; var depth: Int }

func webAreas(_ app: NSRunningApplication) -> [WebArea] {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    // Electron only builds its web accessibility tree once asked.
    AXUIElementSetAttributeValue(ax, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    var found: [WebArea] = []
    func walk(_ e: AXUIElement, _ depth: Int) {
        if depth > 16 { return }
        if (attr(e, "AXRole") as? String) == "AXWebArea" {
            var p = CGPoint.zero, s = CGSize.zero
            if let v = attr(e, "AXPosition") { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
            if let v = attr(e, "AXSize") { AXValueGetValue(v as! AXValue, .cgSize, &s) }
            let url = (attr(e, "AXURL") as? URL)?.absoluteString ?? ""
            found.append(WebArea(url: url, frame: CGRect(origin: p, size: s), depth: depth))
        }
        for c in (attr(e, "AXChildren") as? [AXUIElement] ?? []) { walk(c, depth + 1) }
    }
    walk(ax, 0)
    return found
}

// The pane page is any web area that is not the app shell itself.
func isAppShell(_ url: String) -> Bool {
    url.isEmpty || url.hasPrefix("file://") || url.hasPrefix("https://claude.ai/")
}

func activate() {
    guard let app = claudeApp() else { fail("Claude desktop app is not running") }
    if !app.isActive {
        app.activate()
        usleep(250_000)
    }
}

func post(_ e: CGEvent?) {
    e?.post(tap: .cghidEventTap)
    usleep(8_000)
}

func click(_ p: CGPoint) {
    activate()
    post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left))
    post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left))
    post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left))
}

func typeText(_ text: String) {
    activate()
    let src = CGEventSource(stateID: .hidSystemState)
    for scalar in text.utf16.map({ $0 }) {
        var ch = scalar
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
        // Never inherit a modifier left over from selectall or shifttab.
        down?.flags = []
        up?.flags = []
        post(down)
        post(up)
    }
}

let keyCodes: [String: CGKeyCode] = [
    "enter": 36, "tab": 48, "shifttab": 48, "backspace": 51, "escape": 53,
    "left": 123, "right": 124, "down": 125, "up": 126, "selectall": 0,
]

func key(_ name: String) {
    guard let code = keyCodes[name] else { fail("unknown key \(name)") }
    activate()
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
    let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
    down?.flags = []
    up?.flags = []
    if name == "selectall" { down?.flags = .maskCommand; up?.flags = .maskCommand }
    if name == "shifttab" { down?.flags = .maskShift; up?.flags = .maskShift }
    post(down)
    post(up)
}

func scroll(_ p: CGPoint, _ dy: Int32) {
    activate()
    post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left))
    post(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -dy, wheel2: 0, wheel3: 0))
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { fail("usage: rl-helper status|locate|click|type|key|scroll") }

func num(_ i: Int) -> Double {
    guard args.count > i, let v = Double(args[i]) else { fail("missing number argument \(i)") }
    return v
}

switch cmd {
case "status":
    let d = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
    out(["locked": (d["CGSSessionScreenIsLocked"] as? Bool) ?? false,
         "ax": AXIsProcessTrusted(),
         "running": claudeApp() != nil])
case "locate":
    guard let app = claudeApp() else { fail("Claude desktop app is not running") }
    let host = args.count > 1 ? args[1].lowercased() : ""
    let pages = webAreas(app).filter { !isAppShell($0.url) && $0.frame.width > 40 && $0.frame.height > 40 }
    let pick = pages.first { !host.isEmpty && (URL(string: $0.url)?.host?.lowercased().contains(host) ?? false) }
        ?? pages.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    guard let w = pick else { fail("browser pane not visible") }
    out(["x": w.frame.minX, "y": w.frame.minY, "w": w.frame.width, "h": w.frame.height, "url": w.url])
case "click":
    click(CGPoint(x: num(1), y: num(2)))
case "type":
    let data = FileHandle.standardInput.readDataToEndOfFile()
    typeText(String(decoding: data, as: UTF8.self))
case "key":
    guard args.count > 1 else { fail("missing key name") }
    if args[1] == "clear" { key("selectall"); key("backspace") } else { key(args[1]) }
case "scroll":
    scroll(CGPoint(x: num(1), y: num(2)), Int32(num(3)))
default:
    fail("unknown command \(cmd)")
}
