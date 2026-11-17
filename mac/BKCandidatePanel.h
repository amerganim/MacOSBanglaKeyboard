// A small floating, non-activating window listing word suggestions under the
// text being composed (the macOS counterpart of the Windows CandidateWindow).
#pragma once

#import <Cocoa/Cocoa.h>

@interface BKCandidatePanel : NSObject

+ (instancetype)shared;

// Show `items` with the top-left corner just below `caretRect` (screen
// coordinates, as returned by IMKTextInput). Selection resets to 0.
- (void)showItems:(NSArray<NSString*>*)items belowRect:(NSRect)caretRect;
- (void)hide;
- (BOOL)isVisible;
- (NSInteger)selectedIndex;
- (void)moveSelection:(NSInteger)delta;

// Briefly flash a short message (e.g. "বাং" / "Eng") near `caretRect`.
- (void)flashMessage:(NSString*)message nearRect:(NSRect)caretRect;

// Called when the user clicks a row: (index).
@property(nonatomic, copy) void (^onClick)(NSInteger index);

@end
