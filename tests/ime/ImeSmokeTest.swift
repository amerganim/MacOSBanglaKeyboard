// End-to-end smoke test: hosts an NSTextView, selects the installed Amader
// Bangla Keyboard input source for this app only, feeds synthetic key events
// through the real text-input system (no Accessibility permission needed),
// and checks the committed text.
//   swiftc tests/ime/ImeSmokeTest.swift -o build/ime_smoke && build/ime_smoke
import Cocoa
import Carbon

let modeID = "io.github.amerganim.inputmethod.AmaderBanglaKeyboard.Bangla"

// (input keys, expected text). "\r" = Return, "\u{8}" = Backspace.
let cases: [(String, String)] = [
  ("amar sOnar bangla ", "আমার সোনার বাংলা "),
  ("ami\r", "আমি"),
  ("kShoma ", "ক্ষমা "),
  ("bhaix\u{8} ", "ভাই "),
  ("123 ", "১২৩ "),
]

let keyCodes: [Character: UInt16] = [
  "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,
  "y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"9":25,"7":26,"8":28,"0":29,"o":31,"u":32,
  "i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46,".":47," ":49,"\r":36,"\u{8}":51,
]

final class App: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var tv: NSTextView!
  var failures = 0

  func applicationDidFinishLaunching(_ n: Notification) {
    window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 500, height: 200),
                      styleMask: [.titled], backing: .buffered, defer: false)
    tv = NSTextView(frame: window.contentView!.bounds)
    window.contentView!.addSubview(tv)
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(tv)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.selectIM() }
  }

  func selectIM() {
    guard let ctx = tv.inputContext else { return finish("no input context") }
    ctx.selectedKeyboardInputSource = modeID
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      guard ctx.selectedKeyboardInputSource == modeID else {
        return self.finish("could not select \(modeID) (selected: \(ctx.selectedKeyboardInputSource ?? "nil")); install it and add it in System Settings → Keyboard → Input Sources")
      }
      self.run(0)
    }
  }

  func run(_ i: Int) {
    if i >= cases.count { return finish(nil) }
    tv.string = ""
    let (keys, want) = cases[i]
    var delay = 0.0
    for ch in keys {
      delay += 0.06
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.press(ch) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.6) {
      let got = self.tv.string
      let ok = got == want
      if !ok { self.failures += 1 }
      print(ok ? "ok  " : "FAIL", keys.debugDescription, "->", got.debugDescription,
            ok ? "" : "(want \(want.debugDescription))")
      self.run(i + 1)
    }
  }

  func press(_ ch: Character) {
    let upper = ch.isUppercase
    let code = keyCodes[Character(ch.lowercased())] ?? 0
    let flags: NSEvent.ModifierFlags = upper ? [.shift] : []
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                               timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber, context: nil,
                               characters: String(ch), charactersIgnoringModifiers: String(ch).lowercased(),
                               isARepeat: false, keyCode: code)!
      NSApp.postEvent(e, atStart: false)
    }
  }

  func finish(_ err: String?) {
    if let err { print("ERROR:", err); exit(2) }
    print(failures == 0 ? "\nall \(cases.count) IME cases passed" : "\n\(failures) failed")
    exit(failures == 0 ? 0 : 1)
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let d = App()
app.delegate = d
app.run()
