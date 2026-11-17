// Entry point of the input method process. Normally launched by macOS when the
// user selects "Amader Bangla Keyboard" in the Input menu. The installer also
// runs it with a command-line flag to register / enable the input source:
//
//   AmaderBanglaKeyboard --register   register the bundle with Text Input Sources
//   AmaderBanglaKeyboard --enable     register + enable (adds it to the Input menu)
//   AmaderBanglaKeyboard --select     enable + make it the current input source
//   AmaderBanglaKeyboard --disable    disable (removes it from the Input menu)

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#import "BKShared.h"

static NSArray* FindSources() {
  NSDictionary* filter = @{(__bridge NSString*)kTISPropertyBundleID : BK_BUNDLE_ID};
  CFArrayRef list =
      TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true);
  return CFBridgingRelease(list) ?: @[];
}

static int RunCommand(NSString* cmd) {
  NSURL* url = [[NSBundle mainBundle] bundleURL];
  if ([cmd isEqualToString:@"--register"] || [cmd isEqualToString:@"--enable"] ||
      [cmd isEqualToString:@"--select"]) {
    OSStatus st = TISRegisterInputSource((__bridge CFURLRef)url);
    if (st != noErr) fprintf(stderr, "TISRegisterInputSource failed: %d\n", (int)st);
    if ([cmd isEqualToString:@"--register"]) return st == noErr ? 0 : 1;
    NSArray* sources = FindSources();
    if (sources.count == 0) {
      fprintf(stderr, "Input source not found after registration.\n");
      return 1;
    }
    for (id src in sources) {
      TISInputSourceRef ref = (__bridge TISInputSourceRef)src;
      NSString* sid = (__bridge NSString*)TISGetInputSourceProperty(
          ref, kTISPropertyInputSourceID);
      // Enable the Bangla input mode (the bundle-level source is a container).
      if ([sid isEqualToString:BK_MODE_ID] || sources.count == 1) {
        TISEnableInputSource(ref);
        if ([cmd isEqualToString:@"--select"]) TISSelectInputSource(ref);
      }
    }
    return 0;
  }
  if ([cmd isEqualToString:@"--disable"]) {
    for (id src in FindSources()) {
      TISDisableInputSource((__bridge TISInputSourceRef)src);
    }
    return 0;
  }
  fprintf(stderr, "Unknown option: %s\n", cmd.UTF8String);
  return 2;
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    if (argc > 1) return RunCommand([NSString stringWithUTF8String:argv[1]]);

    IMKServer* server =
        [[IMKServer alloc] initWithName:BK_CONNECTION_NAME
                       bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    (void)server;
    bk::EnsureLoaded();  // load dictionaries before the first keystroke
    [[NSApplication sharedApplication] run];
  }
  return 0;
}
