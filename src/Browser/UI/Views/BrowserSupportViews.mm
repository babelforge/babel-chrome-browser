#import "Browser/UI/Views/BrowserSupportViews.h"

#import "Browser/UI/Theme/BrowserTheme.h"

BabelReloadIgnoreCacheCallback::BabelReloadIgnoreCacheCallback(CefRefPtr<CefBrowser> browser)
    : browser_(browser) {}

void BabelReloadIgnoreCacheCallback::OnComplete() {
  if (browser_) {
    browser_->ReloadIgnoreCache();
  }
}

@implementation BabelOmniboxSuggestionRowView {
  NSImageView* iconImageView_;
}

@synthesize titleLabel = titleLabel_;
@synthesize subtitleLabel = subtitleLabel_;
@synthesize iconImage;
@synthesize suggestionHighlighted;

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.wantsLayer = YES;

    iconImageView_ = [[NSImageView alloc] initWithFrame:NSMakeRect(12, 14, 16, 16)];
    iconImageView_.imageScaling = NSImageScaleProportionallyDown;
    iconImageView_.hidden = YES;
    [self addSubview:iconImageView_];

    titleLabel_ = [NSTextField labelWithString:@""];
    titleLabel_.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    titleLabel_.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:titleLabel_];

    subtitleLabel_ = [NSTextField labelWithString:@""];
    subtitleLabel_.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    subtitleLabel_.textColor = NSColor.secondaryLabelColor;
    subtitleLabel_.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:subtitleLabel_];
  }
  return self;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)layout {
  [super layout];
  CGFloat textX = 38.0;
  CGFloat textWidth = MAX(0.0, self.bounds.size.width - textX - 12.0);
  iconImageView_.frame = NSMakeRect(12.0, 14.0, 16.0, 16.0);
  titleLabel_.frame = NSMakeRect(textX, 6, textWidth, 17);
  subtitleLabel_.frame = NSMakeRect(textX, 24, textWidth, 15);
}

- (void)setSuggestionHighlighted:(BOOL)highlightedValue {
  suggestionHighlighted = highlightedValue;
  self.layer.backgroundColor = (highlightedValue
      ? [BabelTheme.sharedTheme cgColorForToken:@"omnibox.highlight.background" view:self]
      : NSColor.clearColor.CGColor);
}

- (void)configureWithTitle:(NSString*)title subtitle:(NSString*)subtitle iconImage:(NSImage*)iconImageValue {
  self.titleLabel.stringValue = title ?: @"";
  self.subtitleLabel.stringValue = subtitle ?: @"";
  self.iconImage = iconImageValue;
  iconImageView_.image = iconImageValue;
  iconImageView_.hidden = iconImageValue == nil;
}

- (void)mouseDown:(NSEvent*)event {
  [self sendAction:self.action to:self.target];
}

- (void)resetCursorRects {
  [super resetCursorRects];
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

@end

@implementation BabelThemeRootView

@synthesize themeTarget;
@synthesize themeAction;

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  if (self.themeTarget && self.themeAction) {
    [NSApp sendAction:self.themeAction to:self.themeTarget from:self];
  }
}

@end

@implementation BabelBadgeLabel

{
  NSString* badgeText_;
  NSColor* badgeTextColor_;
  NSColor* badgeBackgroundColor_;
  NSFont* badgeFont_;
}

@synthesize settingsRoute;
@synthesize settingsTarget;
@synthesize settingsAction;

- (instancetype)init {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    self.wantsLayer = YES;
    badgeText_ = @"";
    badgeTextColor_ = NSColor.whiteColor;
    badgeBackgroundColor_ = NSColor.clearColor;
    badgeFont_ = [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];
  }
  return self;
}

- (void)configureWithText:(NSString*)text
                textColor:(NSColor*)textColor
          backgroundColor:(NSColor*)backgroundColor {
  badgeText_ = text ?: @"";
  badgeTextColor_ = textColor ?: NSColor.whiteColor;
  badgeBackgroundColor_ = backgroundColor ?: NSColor.clearColor;
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  NSBezierPath* backgroundPath = [NSBezierPath bezierPathWithRoundedRect:self.bounds
                                                                 xRadius:5.0
                                                                 yRadius:5.0];
  [badgeBackgroundColor_ setFill];
  [backgroundPath fill];

  if (badgeText_.length == 0) {
    return;
  }

  NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.alignment = NSTextAlignmentCenter;
  NSDictionary* attributes = @{
    NSFontAttributeName: badgeFont_,
    NSForegroundColorAttributeName: badgeTextColor_,
    NSParagraphStyleAttributeName: paragraphStyle
  };
  NSSize textSize = [badgeText_ sizeWithAttributes:attributes];
  NSRect textRect = NSMakeRect(0.0,
                               floor((self.bounds.size.height - textSize.height) / 2.0),
                               self.bounds.size.width,
                               textSize.height);
  [badgeText_ drawInRect:textRect withAttributes:attributes];
}

- (void)resetCursorRects {
  [super resetCursorRects];
  [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)rightMouseDown:(NSEvent*)event {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem* settingsItem = [[NSMenuItem alloc] initWithTitle:@"View Settings"
                                                        action:self.settingsAction
                                                 keyEquivalent:@""];
  settingsItem.target = self.settingsTarget;
  settingsItem.representedObject = self.settingsRoute ?: @"";
  settingsItem.enabled = self.settingsRoute.length > 0;
  [menu addItem:settingsItem];
  [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

@end

@implementation BabelMainWindow

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen*)screen {
  for (NSScreen* availableScreen in NSScreen.screens) {
    if (NSIntersectsRect(frameRect, availableScreen.visibleFrame)) {
      return frameRect;
    }
  }

  return [super constrainFrameRect:frameRect toScreen:screen];
}

@end
