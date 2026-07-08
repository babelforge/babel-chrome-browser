#import "Browser/UI/Views/BrowserViews.h"

#import "Browser/UI/Theme/BrowserTheme.h"

#include <cmath>

static const CGFloat kBabelTabNormalWidth = 184.0;
static const CGFloat kBabelTabHeight = 32.0;
static const CGFloat kBabelDragStartDistance = 4.0;
static const CGFloat kBabelDraggedItemAlpha = 0.32;
static const CGFloat kBabelDragPreviewAlpha = 0.88;
static const CGFloat kBabelTabTopRightRadius = 8.0;
static const CGFloat kBabelGroupItemTextInset = 6.0;
static const CGFloat kBabelGroupItemSelectionHorizontalPadding = 6.0;
static const CGFloat kBabelGroupItemSelectionMinimumWidth = 42.0;
static const CGFloat kBabelGroupItemSelectionVerticalInset = 1.0;

static NSImage* BabelResourceImage(NSString* resourceName) {
  NSString* resourcePath = [NSBundle.mainBundle pathForResource:resourceName ofType:@"svg"];
  if (!resourcePath) {
    return nil;
  }
  return [[NSImage alloc] initWithContentsOfFile:resourcePath];
}

static NSImage* BabelSnapshotImageForView(NSView* view) {
  NSBitmapImageRep* representation = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
  if (!representation) {
    return nil;
  }

  [view cacheDisplayInRect:view.bounds toBitmapImageRep:representation];
  NSImage* image = [[NSImage alloc] initWithSize:view.bounds.size];
  [image addRepresentation:representation];
  return image;
}

static NSBezierPath* BabelTopRightRoundedPath(NSRect rect, CGFloat radius) {
  CGFloat resolvedRadius = MIN(radius, MIN(rect.size.width, rect.size.height));
  NSBezierPath* path = [NSBezierPath bezierPath];
  [path moveToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
  [path lineToPoint:NSMakePoint(NSMaxX(rect) - resolvedRadius, NSMinY(rect))];
  [path curveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + resolvedRadius)
       controlPoint1:NSMakePoint(NSMaxX(rect) - (resolvedRadius * 0.45), NSMinY(rect))
       controlPoint2:NSMakePoint(NSMaxX(rect), NSMinY(rect) + (resolvedRadius * 0.45))];
  [path lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
  [path lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
  [path closePath];
  return path;
}

void ConfigureIconButton(NSButton* button, NSString* resourceName, NSString* fallbackTitle) {
  NSImage* image = BabelResourceImage(resourceName);
  if (image) {
    image.size = NSMakeSize(18.0, 18.0);
    button.image = image;
    button.title = @"";
    button.imagePosition = NSImageOnly;
  } else {
    button.title = fallbackTitle ?: @"";
  }
}

@interface BabelHandCursorButton : NSButton

@end

@implementation BabelHandCursorButton

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
  return YES;
}

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

- (void)resetCursorRects {
  [super resetCursorRects];
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

@end

@interface BabelImmediateActionButtonView : BabelHandCursorButton

@end

@implementation BabelImmediateActionButtonView

- (void)mouseDown:(NSEvent*)event {
  if (!self.enabled) {
    return;
  }

  [self highlight:YES];
  [NSApp sendAction:self.action to:self.target from:self];
  [self highlight:NO];
}

@end

NSButton* BabelButton(NSString* title, id target, SEL action) {
  NSButton* button = [[BabelHandCursorButton alloc] initWithFrame:NSZeroRect];
  button.title = title ?: @"";
  button.target = target;
  button.action = action;
  return button;
}

NSButton* BabelImmediateActionButton(NSString* title, id target, SEL action) {
  NSButton* button = [[BabelImmediateActionButtonView alloc] initWithFrame:NSZeroRect];
  button.title = title ?: @"";
  button.target = target;
  button.action = action;
  return button;
}

@implementation BabelBrowserHostView {
  CefRefPtr<CefBrowser> browser_;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)setBrowser:(CefRefPtr<CefBrowser>)browser {
  browser_ = browser;
  [self setNeedsLayout:YES];
}

- (void)layout {
  [super layout];
  if (!browser_) {
    return;
  }

  NSView* cefView = (__bridge NSView*)browser_->GetHost()->GetWindowHandle();
  if (cefView) {
    if (cefView.superview != self) {
      [cefView unregisterDraggedTypes];
      [self addSubview:cefView];
    }
    cefView.frame = self.bounds;
  }
}

@end

@implementation BabelPageContainerView {
  BabelBrowserHostView* browserHostView_;
  CefRefPtr<CefBrowser> browser_;
  NSArray<NSString*>* localDropPaths_;
}

@synthesize canAcceptLocalDrop;
@synthesize localDropHandler;

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    localDropPaths_ = @[];
    browserHostView_ = [[BabelBrowserHostView alloc] initWithFrame:self.bounds];
    browserHostView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:browserHostView_];
    [self registerForDraggedTypes:@[ NSPasteboardTypeFileURL ]];
  }
  return self;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)setBrowser:(CefRefPtr<CefBrowser>)browser {
  browser_ = browser;
  [browserHostView_ setBrowser:browser];
}

- (CefRefPtr<CefBrowser>)browser {
  return browser_;
}

- (NSArray<NSString*>*)localDropPaths {
  return localDropPaths_ ?: @[];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  return [self canAcceptDraggingInfo:sender] ? NSDragOperationCopy : NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
  return [self canAcceptDraggingInfo:sender] ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
  return [self canAcceptDraggingInfo:sender];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSArray<NSString*>* paths = [self localPathsFromDraggingInfo:sender];
  if (paths.count == 0 || ![self acceptsLocalDrop]) {
    return NO;
  }

  localDropPaths_ = paths;
  if (self.localDropHandler) {
    self.localDropHandler(self);
  }
  return YES;
}

- (BOOL)canAcceptDraggingInfo:(id<NSDraggingInfo>)sender {
  return [self localPathsFromDraggingInfo:sender].count > 0 && [self acceptsLocalDrop];
}

- (BOOL)acceptsLocalDrop {
  return self.canAcceptLocalDrop ? self.canAcceptLocalDrop(self) : NO;
}

- (NSArray<NSString*>*)localPathsFromDraggingInfo:(id<NSDraggingInfo>)sender {
  NSPasteboard* pasteboard = sender.draggingPasteboard;
  NSMutableArray<NSString*>* paths = [NSMutableArray array];

  NSArray<NSURL*>* fileURLs = [pasteboard readObjectsForClasses:@[ NSURL.class ]
                                                        options:@{
                                                          NSPasteboardURLReadingFileURLsOnlyKey : @YES
                                                        }];
  for (NSURL* url in fileURLs) {
    if (url.isFileURL && url.path.length > 0) {
      [paths addObject:url.path];
    }
  }

  return paths;
}

- (void)layout {
  [super layout];
  browserHostView_.frame = self.bounds;
  [browserHostView_ layoutSubtreeIfNeeded];
}

@end

@implementation BabelFlippedView

- (BOOL)isFlipped {
  return YES;
}

@end

@implementation BabelNonMovableView

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

@end

@implementation BabelNonMovableFlippedView

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

@end

@implementation BabelTitlebarView

@synthesize doubleClickTarget;
@synthesize doubleClickAction;

- (void)mouseUp:(NSEvent*)event {
  if (event.clickCount == 2 && self.doubleClickTarget && self.doubleClickAction) {
    [NSApp sendAction:self.doubleClickAction to:self.doubleClickTarget from:self];
    return;
  }

  [super mouseUp:event];
}

@end

@implementation BabelDeveloperToolsResizeHandleView

@synthesize resizeTarget;
@synthesize resizeAction;
@synthesize dragDelta;

- (BOOL)isFlipped {
  return YES;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self setNeedsDisplay:YES];
}

- (void)resetCursorRects {
  [super resetCursorRects];
  NSCursor* cursor = self.bounds.size.width > self.bounds.size.height
      ? NSCursor.resizeUpDownCursor
      : NSCursor.resizeLeftRightCursor;
  [self addCursorRect:self.bounds cursor:cursor];
}

- (void)drawRect:(NSRect)dirtyRect {
  [[BabelTheme.sharedTheme colorForToken:@"developerTools.handle.background" view:self] setFill];
  NSRectFill(self.bounds);
}

- (void)mouseDragged:(NSEvent*)event {
  self.dragDelta = self.bounds.size.width > self.bounds.size.height
      ? -event.deltaY
      : event.deltaX;
  if (self.resizeTarget && self.resizeAction) {
    [NSApp sendAction:self.resizeAction to:self.resizeTarget from:self];
  }
}

@end

@implementation BabelTabItemView {
  NSImageView* faviconImageView_;
  NSButton* closeButton_;
  NSTextField* titleLabel_;
  NSImageView* dragPreviewView_;
  NSPoint mouseDownWindowPoint_;
  NSPoint dragPreviewOffsetInContentView_;
  BOOL isDragging_;
}

@synthesize identifier;
@synthesize title;
@synthesize faviconImage;
@synthesize accentColor;
@synthesize selected;
@synthesize closeTarget;
@synthesize closeAction;
@synthesize dragTarget;
@synthesize dragAction;
@synthesize dragEndTarget;
@synthesize dragEndAction;

- (instancetype)initWithIdentifier:(NSString*)identifierValue title:(NSString*)titleValue {
  self = [super initWithFrame:NSMakeRect(0, 0, kBabelTabNormalWidth, kBabelTabHeight)];
  if (self) {
    self.identifier = identifierValue;
    self.title = titleValue;
    self.accentColor = NSColor.controlAccentColor;
    self.wantsLayer = YES;

    faviconImageView_ = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 8, 16, 16)];
    faviconImageView_.imageScaling = NSImageScaleProportionallyDown;
    faviconImageView_.hidden = YES;
    [self addSubview:faviconImageView_];

    titleLabel_ = [NSTextField labelWithString:titleValue];
    titleLabel_.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    titleLabel_.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel_.textColor = NSColor.labelColor;
    titleLabel_.frame = NSMakeRect(32, 8, kBabelTabNormalWidth - 64, 16);
    titleLabel_.autoresizingMask = NSViewWidthSizable;
    [self addSubview:titleLabel_];

    closeButton_ = BabelButton(@"", self, @selector(closeTab:));
    closeButton_.bezelStyle = NSBezelStyleRegularSquare;
    closeButton_.bordered = NO;
    closeButton_.frame = NSMakeRect(kBabelTabNormalWidth - 28, 6, 20, 20);
    closeButton_.toolTip = @"Close Tab";
    ConfigureIconButton(closeButton_, @"tab-close", @"x");
    [self addSubview:closeButton_];
  }
  return self;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self setNeedsDisplay:YES];
}

- (void)setTitle:(NSString*)titleValue {
  title = titleValue;
  titleLabel_.stringValue = titleValue ?: @"";
}

- (void)setFaviconImage:(NSImage*)faviconImageValue {
  faviconImage = faviconImageValue;
  faviconImageView_.image = faviconImageValue;
  faviconImageView_.hidden = faviconImageValue == nil;
  [self setNeedsLayout:YES];
}

- (void)setAccentColor:(NSColor*)accentColorValue {
  accentColor = accentColorValue ?: NSColor.controlAccentColor;
  [self setNeedsDisplay:YES];
}

- (void)setSelected:(BOOL)selectedValue {
  selected = selectedValue;
  titleLabel_.font = [NSFont systemFontOfSize:13
                                       weight:selectedValue ? NSFontWeightSemibold
                                                            : NSFontWeightRegular];
  [self setNeedsLayout:YES];
  [self setNeedsDisplay:YES];
}

- (void)layout {
  [super layout];

  BOOL shouldShowCloseButton = self.isSelected || self.bounds.size.width >= 96.0;
  closeButton_.hidden = !shouldShowCloseButton;

  CGFloat leftPadding = 10.0;
  CGFloat iconSize = 16.0;
  CGFloat iconGap = 6.0;
  CGFloat closeSize = 20.0;
  CGFloat closeGap = 6.0;
  CGFloat rightPadding = 8.0;

  faviconImageView_.frame = NSMakeRect(leftPadding, 8.0, iconSize, iconSize);

  CGFloat titleX = leftPadding + iconSize + iconGap;
  CGFloat titleRight = self.bounds.size.width - rightPadding;
  if (shouldShowCloseButton) {
    CGFloat closeX = MAX(titleX, self.bounds.size.width - rightPadding - closeSize);
    closeButton_.frame = NSMakeRect(closeX, 6.0, closeSize, closeSize);
    titleRight = closeX - closeGap;
  }

  CGFloat titleWidth = MAX(0.0, titleRight - titleX);
  titleLabel_.frame = NSMakeRect(titleX, 8.0, titleWidth, 16.0);
}

- (void)mouseDown:(NSEvent*)event {
  mouseDownWindowPoint_ = event.locationInWindow;
  isDragging_ = NO;
}

- (void)mouseDragged:(NSEvent*)event {
  CGFloat deltaX = event.locationInWindow.x - mouseDownWindowPoint_.x;
  CGFloat deltaY = event.locationInWindow.y - mouseDownWindowPoint_.y;
  if (!isDragging_ && hypot(deltaX, deltaY) < kBabelDragStartDistance) {
    return;
  }

  if (!isDragging_) {
    isDragging_ = YES;
    [self beginDragPreviewWithEvent:event];
  }

  [self moveDragPreviewWithEvent:event];
  if (self.dragTarget && self.dragAction) {
    [NSApp sendAction:self.dragAction to:self.dragTarget from:self];
  }
}

- (void)mouseUp:(NSEvent*)event {
  if (isDragging_) {
    isDragging_ = NO;
    [self endDragPreview];
    if (self.dragEndTarget && self.dragEndAction) {
      [NSApp sendAction:self.dragEndAction to:self.dragEndTarget from:self];
    }
    return;
  }

  [self sendAction:self.action to:self.target];
}

- (void)beginDragPreviewWithEvent:(NSEvent*)event {
  NSView* contentView = self.window.contentView;
  if (!contentView) {
    self.alphaValue = kBabelDraggedItemAlpha;
    return;
  }

  NSImage* image = BabelSnapshotImageForView(self);
  if (!image) {
    self.alphaValue = kBabelDraggedItemAlpha;
    return;
  }

  NSRect frameInContentView = [contentView convertRect:self.bounds fromView:self];
  NSPoint pointInContentView = [contentView convertPoint:event.locationInWindow fromView:nil];
  dragPreviewOffsetInContentView_ = NSMakePoint(pointInContentView.x - frameInContentView.origin.x,
                                                pointInContentView.y - frameInContentView.origin.y);

  dragPreviewView_ = [[NSImageView alloc] initWithFrame:frameInContentView];
  dragPreviewView_.image = image;
  dragPreviewView_.imageScaling = NSImageScaleAxesIndependently;
  dragPreviewView_.alphaValue = kBabelDragPreviewAlpha;
  dragPreviewView_.wantsLayer = YES;
  dragPreviewView_.layer.shadowColor = NSColor.blackColor.CGColor;
  dragPreviewView_.layer.shadowOpacity = 0.18;
  dragPreviewView_.layer.shadowRadius = 8.0;
  dragPreviewView_.layer.shadowOffset = CGSizeMake(0.0, -3.0);
  [contentView addSubview:dragPreviewView_ positioned:NSWindowAbove relativeTo:nil];
  self.alphaValue = kBabelDraggedItemAlpha;
}

- (void)moveDragPreviewWithEvent:(NSEvent*)event {
  if (!dragPreviewView_) {
    return;
  }

  NSView* contentView = self.window.contentView;
  NSPoint pointInContentView = [contentView convertPoint:event.locationInWindow fromView:nil];
  NSRect frame = dragPreviewView_.frame;
  frame.origin = NSMakePoint(pointInContentView.x - dragPreviewOffsetInContentView_.x,
                             pointInContentView.y - dragPreviewOffsetInContentView_.y);
  dragPreviewView_.frame = frame;
}

- (void)endDragPreview {
  [dragPreviewView_ removeFromSuperview];
  dragPreviewView_ = nil;
  self.alphaValue = 1.0;
}

- (void)resetCursorRects {
  [super resetCursorRects];
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)drawRect:(NSRect)dirtyRect {
  NSColor* fillColor =
      [BabelTheme.sharedTheme colorForToken:self.isSelected ? @"tab.selected.background"
                                                           : @"tab.inactive.background"
                                      view:self];
  NSColor* strokeColor =
      [BabelTheme.sharedTheme colorForToken:self.isSelected ? @"tab.selected.border"
                                                           : @"tab.inactive.border"
                                      view:self];
  NSColor* accent = self.accentColor ?: NSColor.controlAccentColor;

  NSRect tabRect = NSInsetRect(self.bounds, 0.5, 2.0);
  NSBezierPath* path = BabelTopRightRoundedPath(tabRect, kBabelTabTopRightRadius);
  [fillColor setFill];
  [path fill];

  [accent setFill];
  NSRect accentRect = self.isSelected
      ? NSMakeRect(NSMinX(tabRect), NSMinY(tabRect), NSWidth(tabRect), 3.0)
      : NSMakeRect(NSMinX(tabRect), NSMinY(tabRect), 5.0, NSHeight(tabRect));
  [NSGraphicsContext saveGraphicsState];
  [path addClip];
  NSRectFill(accentRect);
  [NSGraphicsContext restoreGraphicsState];

  [strokeColor setStroke];
  [path stroke];
}

- (void)closeTab:(id)sender {
  if (self.closeTarget && self.closeAction) {
    [NSApp sendAction:self.closeAction to:self.closeTarget from:self];
  }
}

@end

@implementation BabelGroupItemView {
  NSTextField* titleLabel_;
  NSImageView* dragPreviewView_;
  NSPoint mouseDownWindowPoint_;
  NSPoint dragPreviewOffsetInContentView_;
  BOOL isDragging_;
}

@synthesize identifier;
@synthesize title;
@synthesize accentColor;
@synthesize selected;
@synthesize collapsed;
@synthesize renameTarget;
@synthesize renameAction;
@synthesize deleteTarget;
@synthesize deleteAction;
@synthesize dragTarget;
@synthesize dragAction;
@synthesize dragEndTarget;
@synthesize dragEndAction;

- (instancetype)initWithIdentifier:(NSString*)identifierValue title:(NSString*)titleValue {
  self = [super initWithFrame:NSMakeRect(0, 0, 204, 30)];
  if (self) {
    self.identifier = identifierValue;
    self.title = titleValue;
    self.accentColor = NSColor.controlAccentColor;
    self.wantsLayer = YES;

    titleLabel_ = [NSTextField labelWithString:titleValue];
    titleLabel_.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel_.frame = NSMakeRect(6, 7, 192, 16);
    titleLabel_.autoresizingMask = NSViewWidthSizable;
    [self addSubview:titleLabel_];
    [self updateTitleStyle];
  }
  return self;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self setNeedsDisplay:YES];
}

- (void)setTitle:(NSString*)titleValue {
  title = titleValue;
  [self updateDisplayedTitle];
}

- (void)setSelected:(BOOL)selectedValue {
  selected = selectedValue;
  [self updateTitleStyle];
  [self setNeedsDisplay:YES];
}

- (void)setAccentColor:(NSColor*)accentColorValue {
  accentColor = accentColorValue ?: NSColor.controlAccentColor;
  [self updateTitleStyle];
  [self setNeedsDisplay:YES];
}

- (void)setCollapsed:(BOOL)collapsedValue {
  collapsed = collapsedValue;
  titleLabel_.alignment = collapsedValue ? NSTextAlignmentCenter : NSTextAlignmentLeft;
  [self updateDisplayedTitle];
  [self setNeedsLayout:YES];
  [self setNeedsDisplay:YES];
}

- (void)layout {
  [super layout];
  CGFloat labelX = self.isCollapsed ? 0.0 : kBabelGroupItemTextInset;
  CGFloat labelWidth =
      MAX(0.0, self.bounds.size.width - (self.isCollapsed ? 0.0 : (kBabelGroupItemTextInset * 2.0)));
  titleLabel_.frame = NSMakeRect(labelX, 7, labelWidth, 16);
}

- (void)updateDisplayedTitle {
  titleLabel_.stringValue = self.isCollapsed ? [self initialsForTitle:title] : (title ?: @"");
}

- (void)updateTitleStyle {
  if (!titleLabel_) {
    return;
  }

  titleLabel_.textColor = self.accentColor ?: NSColor.controlAccentColor;
  titleLabel_.font = [NSFont systemFontOfSize:13
                                       weight:self.isSelected ? NSFontWeightBold : NSFontWeightMedium];
}

- (NSString*)initialsForTitle:(NSString*)value {
  NSArray<NSString*>* words =
      [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSMutableString* initials = [NSMutableString string];
  for (NSString* word in words) {
    if (word.length == 0) {
      continue;
    }
    [initials appendString:[[word substringToIndex:1] uppercaseString]];
    if (initials.length >= 2) {
      break;
    }
  }
  if (initials.length == 0 && value.length > 0) {
    [initials appendString:[[value substringToIndex:1] uppercaseString]];
  }
  return initials;
}

- (void)mouseDown:(NSEvent*)event {
  mouseDownWindowPoint_ = event.locationInWindow;
  isDragging_ = NO;
}

- (void)mouseDragged:(NSEvent*)event {
  CGFloat deltaX = event.locationInWindow.x - mouseDownWindowPoint_.x;
  CGFloat deltaY = event.locationInWindow.y - mouseDownWindowPoint_.y;
  if (!isDragging_ && hypot(deltaX, deltaY) < kBabelDragStartDistance) {
    return;
  }

  if (!isDragging_) {
    isDragging_ = YES;
    [self beginDragPreviewWithEvent:event];
  }

  [self moveDragPreviewWithEvent:event];
  if (self.dragTarget && self.dragAction) {
    [NSApp sendAction:self.dragAction to:self.dragTarget from:self];
  }
}

- (void)mouseUp:(NSEvent*)event {
  if (isDragging_) {
    isDragging_ = NO;
    [self endDragPreview];
    if (self.dragEndTarget && self.dragEndAction) {
      [NSApp sendAction:self.dragEndAction to:self.dragEndTarget from:self];
    }
    return;
  }

  [self sendAction:self.action to:self.target];
}

- (void)beginDragPreviewWithEvent:(NSEvent*)event {
  NSView* contentView = self.window.contentView;
  if (!contentView) {
    self.alphaValue = kBabelDraggedItemAlpha;
    return;
  }

  NSImage* image = BabelSnapshotImageForView(self);
  if (!image) {
    self.alphaValue = kBabelDraggedItemAlpha;
    return;
  }

  NSRect frameInContentView = [contentView convertRect:self.bounds fromView:self];
  NSPoint pointInContentView = [contentView convertPoint:event.locationInWindow fromView:nil];
  dragPreviewOffsetInContentView_ = NSMakePoint(pointInContentView.x - frameInContentView.origin.x,
                                                pointInContentView.y - frameInContentView.origin.y);

  dragPreviewView_ = [[NSImageView alloc] initWithFrame:frameInContentView];
  dragPreviewView_.image = image;
  dragPreviewView_.imageScaling = NSImageScaleAxesIndependently;
  dragPreviewView_.alphaValue = kBabelDragPreviewAlpha;
  dragPreviewView_.wantsLayer = YES;
  dragPreviewView_.layer.shadowColor = NSColor.blackColor.CGColor;
  dragPreviewView_.layer.shadowOpacity = 0.18;
  dragPreviewView_.layer.shadowRadius = 8.0;
  dragPreviewView_.layer.shadowOffset = CGSizeMake(0.0, -3.0);
  [contentView addSubview:dragPreviewView_ positioned:NSWindowAbove relativeTo:nil];
  self.alphaValue = kBabelDraggedItemAlpha;
}

- (void)moveDragPreviewWithEvent:(NSEvent*)event {
  if (!dragPreviewView_) {
    return;
  }

  NSView* contentView = self.window.contentView;
  NSPoint pointInContentView = [contentView convertPoint:event.locationInWindow fromView:nil];
  NSRect frame = dragPreviewView_.frame;
  frame.origin = NSMakePoint(pointInContentView.x - dragPreviewOffsetInContentView_.x,
                             pointInContentView.y - dragPreviewOffsetInContentView_.y);
  dragPreviewView_.frame = frame;
}

- (void)endDragPreview {
  [dragPreviewView_ removeFromSuperview];
  dragPreviewView_ = nil;
  self.alphaValue = 1.0;
}

- (void)resetCursorRects {
  [super resetCursorRects];
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)rightMouseDown:(NSEvent*)event {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem* renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename Group"
                                                      action:self.renameAction
                                               keyEquivalent:@""];
  renameItem.target = self.renameTarget;
  renameItem.representedObject = self.identifier;
  [menu addItem:renameItem];

  NSMenuItem* deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete Group"
                                                      action:self.deleteAction
                                               keyEquivalent:@""];
  deleteItem.target = self.deleteTarget;
  deleteItem.representedObject = self.identifier;
  [menu addItem:deleteItem];
  [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)drawRect:(NSRect)dirtyRect {
  if (!self.isSelected) {
    return;
  }

  NSColor* accent = self.accentColor ?: NSColor.controlAccentColor;
  [[accent colorWithAlphaComponent:0.14] setFill];
  NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:[self selectionBackgroundRect]
                                                       xRadius:6
                                                       yRadius:6];
  [path fill];

  [[accent colorWithAlphaComponent:0.30] setStroke];
  path.lineWidth = 1.0;
  [path stroke];
}

- (NSRect)selectionBackgroundRect {
  NSRect bounds = self.bounds;
  if (self.isCollapsed) {
    return NSInsetRect(bounds, 2.0, kBabelGroupItemSelectionVerticalInset);
  }

  CGFloat availableWidth = MAX(0.0, bounds.size.width);
  CGFloat textWidth = ceil(titleLabel_.intrinsicContentSize.width);
  CGFloat selectionWidth =
      MIN(availableWidth,
          MAX(kBabelGroupItemSelectionMinimumWidth,
              textWidth + (kBabelGroupItemSelectionHorizontalPadding * 2.0)));

  return NSMakeRect(0.0,
                    kBabelGroupItemSelectionVerticalInset,
                    selectionWidth,
                    MAX(0.0, bounds.size.height - (kBabelGroupItemSelectionVerticalInset * 2.0)));
}

@end
