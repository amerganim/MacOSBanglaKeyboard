#import "BKCandidatePanel.h"

static const CGFloat kPadX = 10;
static const CGFloat kPadY = 5;
static const CGFloat kRowGap = 2;

@interface BKCandidateView : NSView
@property(nonatomic, copy) NSArray<NSString*>* items;
@property(nonatomic) NSInteger selected;
@property(nonatomic, copy) NSString* message;  // when set, draw only this
@property(nonatomic, weak) BKCandidatePanel* owner;
- (NSSize)preferredSize;
@end

@implementation BKCandidateView

- (BOOL)isFlipped {
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
  return YES;
}

+ (NSFont*)itemFont {
  return [NSFont systemFontOfSize:17];
}

+ (NSFont*)indexFont {
  return [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
}

- (CGFloat)rowHeight {
  NSFont* f = [BKCandidateView itemFont];
  return ceil(f.ascender - f.descender + f.leading) + 8;
}

- (NSDictionary*)itemAttrs:(BOOL)selected {
  return @{
    NSFontAttributeName : [BKCandidateView itemFont],
    NSForegroundColorAttributeName : selected
        ? [NSColor alternateSelectedControlTextColor]
        : [NSColor labelColor],
  };
}

- (NSDictionary*)indexAttrs:(BOOL)selected {
  return @{
    NSFontAttributeName : [BKCandidateView indexFont],
    NSForegroundColorAttributeName : selected
        ? [NSColor alternateSelectedControlTextColor]
        : [NSColor secondaryLabelColor],
  };
}

- (NSSize)preferredSize {
  if (self.message.length) {
    NSSize s = [self.message sizeWithAttributes:[self itemAttrs:NO]];
    return NSMakeSize(ceil(s.width) + 2 * kPadX + 6, [self rowHeight] + 2 * kPadY);
  }
  CGFloat w = 0;
  for (NSString* item in self.items) {
    w = MAX(w, [item sizeWithAttributes:[self itemAttrs:NO]].width);
  }
  const CGFloat indexW = 18;
  const CGFloat rows = self.items.count;
  return NSMakeSize(ceil(w) + indexW + 2 * kPadX + 8,
                    rows * [self rowHeight] + (rows - 1) * kRowGap + 2 * kPadY);
}

- (void)drawRect:(NSRect)dirty {
  NSBezierPath* bg = [NSBezierPath bezierPathWithRoundedRect:self.bounds
                                                     xRadius:8
                                                     yRadius:8];
  [[NSColor windowBackgroundColor] setFill];
  [bg fill];
  [[NSColor separatorColor] setStroke];
  bg.lineWidth = 1;
  [bg stroke];

  const CGFloat rh = [self rowHeight];
  if (self.message.length) {
    NSSize s = [self.message sizeWithAttributes:[self itemAttrs:NO]];
    [self.message drawAtPoint:NSMakePoint((self.bounds.size.width - s.width) / 2,
                                          kPadY + (rh - s.height) / 2)
               withAttributes:[self itemAttrs:NO]];
    return;
  }
  for (NSInteger i = 0; i < (NSInteger)self.items.count; ++i) {
    const BOOL sel = (i == self.selected);
    NSRect row = NSMakeRect(4, kPadY + i * (rh + kRowGap),
                            self.bounds.size.width - 8, rh);
    if (sel) {
      [[NSColor selectedContentBackgroundColor] setFill];
      [[NSBezierPath bezierPathWithRoundedRect:row xRadius:5 yRadius:5] fill];
    }
    NSString* idx = [NSString stringWithFormat:@"%ld", (long)i + 1];
    NSSize is = [idx sizeWithAttributes:[self indexAttrs:sel]];
    [idx drawAtPoint:NSMakePoint(kPadX, NSMidY(row) - is.height / 2)
        withAttributes:[self indexAttrs:sel]];
    NSSize ts = [self.items[i] sizeWithAttributes:[self itemAttrs:sel]];
    [self.items[i] drawAtPoint:NSMakePoint(kPadX + 18, NSMidY(row) - ts.height / 2)
                withAttributes:[self itemAttrs:sel]];
  }
}

- (void)mouseDown:(NSEvent*)event {
  if (self.message.length) return;
  NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  NSInteger i = (NSInteger)floor((p.y - kPadY) / ([self rowHeight] + kRowGap));
  if (i >= 0 && i < (NSInteger)self.items.count && self.owner.onClick) {
    self.owner.onClick(i);
  }
}

@end

@implementation BKCandidatePanel {
  NSPanel* _panel;
  BKCandidateView* _view;
  NSUInteger _flashToken;
}

+ (instancetype)shared {
  static BKCandidatePanel* s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    s = [[BKCandidatePanel alloc] init];
  });
  return s;
}

- (instancetype)init {
  if ((self = [super init])) {
    _panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 100, 40)
                  styleMask:NSWindowStyleMaskBorderless |
                            NSWindowStyleMaskNonactivatingPanel
                    backing:NSBackingStoreBuffered
                      defer:YES];
    _panel.level = NSPopUpMenuWindowLevel;
    _panel.opaque = NO;
    _panel.backgroundColor = [NSColor clearColor];
    _panel.hasShadow = YES;
    _panel.hidesOnDeactivate = NO;
    _panel.becomesKeyOnlyIfNeeded = YES;
    _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary;
    _view = [[BKCandidateView alloc] initWithFrame:NSMakeRect(0, 0, 100, 40)];
    _view.owner = self;
    _panel.contentView = _view;
  }
  return self;
}

- (void)placeBelowRect:(NSRect)caret {
  NSSize size = [_view preferredSize];
  NSPoint top = NSMakePoint(NSMinX(caret), NSMinY(caret) - 4);

  NSScreen* screen = [NSScreen mainScreen];
  for (NSScreen* s in [NSScreen screens]) {
    if (NSPointInRect(caret.origin, s.frame)) {
      screen = s;
      break;
    }
  }
  NSRect vis = screen.visibleFrame;
  NSRect frame = NSMakeRect(top.x, top.y - size.height, size.width, size.height);
  // Not enough room below the text: show above it instead.
  if (NSMinY(frame) < NSMinY(vis)) frame.origin.y = NSMaxY(caret) + 4;
  if (NSMaxX(frame) > NSMaxX(vis)) frame.origin.x = NSMaxX(vis) - size.width;
  if (NSMinX(frame) < NSMinX(vis)) frame.origin.x = NSMinX(vis);

  [_panel setFrame:frame display:NO];
  _view.frame = NSMakeRect(0, 0, size.width, size.height);
  [_view setNeedsDisplay:YES];
  [_panel orderFrontRegardless];
}

- (void)showItems:(NSArray<NSString*>*)items belowRect:(NSRect)caretRect {
  _flashToken++;
  _view.message = nil;
  _view.items = items;
  _view.selected = 0;
  [self placeBelowRect:caretRect];
}

- (void)hide {
  _view.items = @[];
  _view.message = nil;
  [_panel orderOut:nil];
}

- (BOOL)isVisible {
  return _panel.isVisible && _view.items.count > 0 && _view.message == nil;
}

- (NSInteger)selectedIndex {
  return [self isVisible] ? _view.selected : 0;
}

- (void)moveSelection:(NSInteger)delta {
  const NSInteger n = (NSInteger)_view.items.count;
  if (n == 0) return;
  _view.selected = ((_view.selected + delta) % n + n) % n;
  [_view setNeedsDisplay:YES];
}

- (void)flashMessage:(NSString*)message nearRect:(NSRect)caretRect {
  const NSUInteger token = ++_flashToken;
  _view.items = @[];
  _view.message = message;
  [self placeBelowRect:caretRect];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   if (self->_flashToken == token) [self hide];
                 });
}

@end
