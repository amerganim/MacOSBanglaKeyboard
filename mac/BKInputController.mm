// The InputMethodKit controller: one instance per text-input client. It
// buffers romanized keystrokes, shows the live Bangla transliteration as
// marked (underlined) text, and commits on Space / Enter — mirroring the
// Windows TSF text service (app/src/TextService.cpp in WindowsBanglaKeyboard).

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#include <string>
#include <vector>

#import "BKCandidatePanel.h"
#import "BKShared.h"
#include "bnphonetic/Transliterator.h"

@interface BKInputController : IMKInputController
@end

@implementation BKInputController {
  std::string _buffer;                    // romanized keystrokes of the word
  std::vector<std::string> _suggestions;  // [0] = literal transliteration
  id _client;                             // last client we drew into
}

#pragma mark - Helpers

- (BOOL)isComposing {
  return !_buffer.empty();
}

- (NSRect)caretRectForClient:(id)client {
  NSRect rect = NSZeroRect;
  @try {
    [client attributesForCharacterIndex:0 lineHeightRectangle:&rect];
  } @catch (NSException*) {
  }
  return rect;
}

- (void)updateMarkedText:(id)client {
  _client = client;
  NSString* text = BKString(bk::Transliterate(_buffer));
  NSDictionary* attrs = [self markForStyle:kTSMHiliteConvertedText
                                   atRange:NSMakeRange(0, text.length)];
  NSAttributedString* marked =
      [[NSAttributedString alloc] initWithString:text attributes:attrs];
  [client setMarkedText:marked
         selectionRange:NSMakeRange(text.length, 0)
       replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  [self refreshCandidates:client];
}

- (void)refreshCandidates:(id)client {
  _suggestions = bk::Suggest(_buffer, 9);
  // Only show the list when there are real alternatives beyond the literal.
  if (_suggestions.size() > 1) {
    NSMutableArray<NSString*>* items = [NSMutableArray array];
    for (const std::string& s : _suggestions) [items addObject:BKString(s)];
    BKCandidatePanel* panel = [BKCandidatePanel shared];
    __weak BKInputController* weakSelf = self;
    panel.onClick = ^(NSInteger index) {
      [weakSelf commitIndex:index trailing:@""];
    };
    [panel showItems:items belowRect:[self caretRectForClient:client]];
  } else {
    [[BKCandidatePanel shared] hide];
  }
}

// Commit the current word: the suggestion at `index` (0 = what was typed),
// followed by `trailing` (e.g. the space that committed it).
- (void)commitIndex:(NSInteger)index trailing:(NSString*)trailing {
  id client = _client ?: self.client;
  if (![self isComposing]) {
    [[BKCandidatePanel shared] hide];
    return;
  }
  std::string word;
  if (index > 0 && index < (NSInteger)_suggestions.size()) {
    word = _suggestions[index];
    bk::RecordUsage(word);  // learn from the choice
  } else {
    word = bk::Transliterate(_buffer);
  }
  _buffer.clear();
  _suggestions.clear();
  [[BKCandidatePanel shared] hide];
  NSString* text = [BKString(word) stringByAppendingString:trailing ?: @""];
  [client insertText:text
      replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)commitLiteral {
  [self commitIndex:0 trailing:@""];
}

- (void)toggleModeForClient:(id)client {
  if ([self isComposing]) [self commitLiteral];
  bk::SetBanglaEnabled(!bk::BanglaEnabled());
  [[BKCandidatePanel shared]
      flashMessage:bk::BanglaEnabled() ? @"বাংলা" : @"English"
          nearRect:[self caretRectForClient:client]];
}

#pragma mark - IMKStateSetting

- (void)activateServer:(id)sender {
  [super activateServer:sender];
  bk::EnsureLoaded();
  // Switching into the input method always starts in Bangla mode.
  bk::SetBanglaEnabled(true);
}

- (void)deactivateServer:(id)sender {
  if ([self isComposing]) {
    _client = sender;
    [self commitLiteral];
  }
  [[BKCandidatePanel shared] hide];
  bk::SaveLearned();
  [super deactivateServer:sender];
}

- (NSUInteger)recognizedEvents:(id)sender {
  return NSEventMaskKeyDown;
}

#pragma mark - IMKInputController

- (void)commitComposition:(id)sender {
  // The app asked us to finish (focus change, mouse click, ...).
  if ([self isComposing]) {
    _client = sender;
    [self commitLiteral];
  }
}

- (id)composedString:(id)sender {
  return BKString(bk::Transliterate(_buffer));
}

- (id)originalString:(id)sender {
  return [[NSAttributedString alloc]
      initWithString:[NSString stringWithUTF8String:_buffer.c_str()]];
}

- (BOOL)handleEvent:(NSEvent*)event client:(id)sender {
  if (event.type != NSEventTypeKeyDown) return NO;
  _client = sender;

  const NSEventModifierFlags mods =
      event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  const unsigned short key = event.keyCode;

  // Control+Shift+B toggles Bangla / English (works in both modes).
  if ((mods & NSEventModifierFlagControl) && (mods & NSEventModifierFlagShift) &&
      !(mods & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) &&
      [event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"b"]) {
    [self toggleModeForClient:sender];
    return YES;
  }

  if (!bk::BanglaEnabled()) return NO;  // English mode: pass everything through

  // Command / Control / Option shortcuts are the app's: finish the word first.
  if (mods & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
              NSEventModifierFlagOption)) {
    if ([self isComposing]) [self commitLiteral];
    return NO;
  }

  BKCandidatePanel* panel = [BKCandidatePanel shared];
  if ([self isComposing] && [panel isVisible]) {
    switch (key) {
      case kVK_DownArrow:
      case kVK_Tab:
        [panel moveSelection:(mods & NSEventModifierFlagShift) && key == kVK_Tab
                                 ? -1
                                 : 1];
        return YES;
      case kVK_UpArrow:
        [panel moveSelection:-1];
        return YES;
      case kVK_Escape:
        [panel hide];
        return YES;
      case kVK_Space:
        [self commitIndex:[panel selectedIndex] trailing:@" "];
        return YES;
      case kVK_Return:
      case kVK_ANSI_KeypadEnter:
        [self commitIndex:[panel selectedIndex] trailing:@""];
        return YES;
      default:
        break;  // typing / backspace falls through and refreshes the list
    }
  }

  if (key == kVK_Delete) {
    if (![self isComposing]) return NO;
    _buffer.pop_back();
    if (_buffer.empty()) {
      [sender setMarkedText:@""
             selectionRange:NSMakeRange(0, 0)
           replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      [panel hide];
    } else {
      [self updateMarkedText:sender];
    }
    return YES;
  }

  if (key == kVK_Space) {
    if (![self isComposing]) return NO;
    [self commitIndex:0 trailing:@" "];
    return YES;
  }

  if (key == kVK_Return || key == kVK_ANSI_KeypadEnter) {
    if (![self isComposing]) return NO;
    // Commit the word; Enter is consumed (press it again for a new line).
    [self commitLiteral];
    return YES;
  }

  NSString* chars = event.characters;
  if (chars.length == 1) {
    const unichar c = [chars characterAtIndex:0];
    if (c < 0x80 && bnphonetic::IsPhoneticInput(static_cast<char>(c))) {
      _buffer.push_back(static_cast<char>(c));
      [self updateMarkedText:sender];
      return YES;
    }
  }

  // A key we don't handle: if a word is open, commit it so it doesn't dangle,
  // then let the app process the key normally.
  if ([self isComposing]) [self commitLiteral];
  return NO;
}

#pragma mark - Menu

- (NSMenu*)menu {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Amader Bangla Keyboard"];
  NSMenuItem* mode = [[NSMenuItem alloc]
      initWithTitle:bk::BanglaEnabled()
                        ? @"Switch to English  (⌃⇧B)"
                        : @"Switch to Bangla  (⌃⇧B)"
             action:@selector(menuToggleMode:)
      keyEquivalent:@""];
  mode.target = self;
  [menu addItem:mode];
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* guide =
      [[NSMenuItem alloc] initWithTitle:@"Typing Guide…"
                                 action:@selector(menuShowGuide:)
                          keyEquivalent:@""];
  guide.target = self;
  [menu addItem:guide];
  NSMenuItem* site =
      [[NSMenuItem alloc] initWithTitle:@"Website & Updates…"
                                 action:@selector(menuShowWebsite:)
                          keyEquivalent:@""];
  site.target = self;
  [menu addItem:site];
  return menu;
}

- (void)menuToggleMode:(id)sender {
  [self toggleModeForClient:self.client];
}

- (void)menuShowGuide:(id)sender {
  NSString* path = [[NSBundle mainBundle] pathForResource:@"KEYMAP"
                                                   ofType:@"html"];
  if (path) [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)menuShowWebsite:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:
                         @"https://github.com/amerganim/MacOSBanglaKeyboard"]];
}

@end
