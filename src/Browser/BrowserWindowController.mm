#import "Browser/BrowserWindowController.h"

#import "Browser/BrowserClient.h"
#import "Browser/BrowserModels.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"
#import "Configuration/Configuration.h"
#import "LocalServices/LocalServiceHost.h"

#include <cmath>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_app.h"
#include "include/cef_callback.h"
#include "include/wrapper/cef_helpers.h"

static const CGFloat kSidebarInitialWidth = 240.0;
static const CGFloat kSidebarHeaderButtonSize = 28.0;
static const CGFloat kSidebarHeaderLeadingInset = 10.0;
static const CGFloat kSidebarHeaderButtonGap = 8.0;
static const CGFloat kSidebarHeaderTrailingInset = 12.0;
static const CGFloat kSidebarMaximumWidth = 360.0;
static const CGFloat kSidebarCollapsedWidth = 48.0;
static const CGFloat kTabBarHeight = 40.0;
static const CGFloat kTitlebarTabLeadingInset = 88.0;
static const CGFloat kToolbarHeight = 44.0;
static const CGFloat kTabNormalWidth = 184.0;
static const CGFloat kTabActiveWidth = 210.0;
static const CGFloat kTabMinimumWidth = 36.0;
static const CGFloat kTabHeight = 32.0;
static const CGFloat kTabSpacing = 3.0;
static const CGFloat kNewTabButtonWidth = 34.0;
static const CGFloat kDeveloperToolsToolbarHeight = 30.0;
static const CGFloat kDeveloperToolsResizeHandleThickness = 7.0;
static const CGFloat kLinkStatusBarHeight = 24.0;
static const CGFloat kLinkStatusBarMaximumWidth = 760.0;
static const CGFloat kOmniboxSuggestionRowHeight = 44.0;
static const NSUInteger kOmniboxSuggestionMaximumCount = 10;
static const CGFloat kOmniboxSuggestionPanelMaximumHeight =
    kOmniboxSuggestionRowHeight * kOmniboxSuggestionMaximumCount;
static const int64_t kGoogleSuggestDebounceDelayNanoseconds = 220 * NSEC_PER_MSEC;
static NSString* const kDefaultGroupIdentifier = @"default";
static NSString* const kDefaultGroupName = @"default";
static NSString* const kDeveloperToolsDockModeDefaultsKey = @"DeveloperToolsDockMode";
static NSString* const kDeveloperToolsSizeRatioDefaultsKey = @"DeveloperToolsSizeRatio";
static NSString* const kSidebarCollapsedDefaultsKey = @"SidebarCollapsed";
static NSString* const kSidebarWidthDefaultsKey = @"SidebarWidth";
static NSString* const kAddressSuggestionsModeDefaultsKey = @"AddressSuggestionsMode";
static NSString* const kTabOpeningStrategyDefaultsKey = @"TabOpeningStrategy";
static NSString* const kMarkdownThemeDefaultsKey = @"MarkdownTheme";
static NSString* const kMainWindowFrameDefaultsKey = @"MainWindowFrame";
static NSString* const kMainWindowZoomedDefaultsKey = @"MainWindowZoomed";
static NSString* const kModuleUpdateURLDefaultsKey = @"ModuleUpdateURL";
static NSString* const kModuleUpdateLocalDirectoryDefaultsKey = @"ModuleUpdateLocalDirectory";
static NSString* const kModuleUpdateLocalIndexFilename = @"module-update-local-index.json";
static NSString* const kDeveloperToolsDockModeBottom = @"bottom";
static NSString* const kDeveloperToolsDockModeTop = @"top";
static NSString* const kDeveloperToolsDockModeLeft = @"left";
static NSString* const kDeveloperToolsDockModeRight = @"right";
static NSString* const kTabOpeningStrategyAppend = @"append";
static NSString* const kTabOpeningStrategyAfterSelected = @"after-selected";
static NSString* const kTabOpeningStrategyChildCluster = @"child-cluster";
static NSString* const kAddressSuggestionsModeLocal = @"local";
static NSString* const kAddressSuggestionsModeGoogle = @"google";
static NSString* const kMarkdownThemeGitHubLight = @"github-light";
static NSString* const kMarkdownThemeGitHubDark = @"github-dark";
static NSString* const kMarkdownThemeReader = @"reader";
static NSString* const kMarkdownThemeCompact = @"compact";
static NSString* const kCompactCommandOpaquePrefix = @"babelchrome:group:";
static NSString* const kCompactCommandHierarchicalPrefix = @"babelchrome://command/group:";
static NSString* const kInternalStartQueryParameter = @"__babelchrome_start";
static NSString* const kInternalRefreshQueryParameter = @"__babelchrome_refresh";
static NSString* const kHistoryPageURLString = @"babelchrome://history";
static NSString* const kSettingsPageURLString = @"babelchrome://settings";
static NSString* const kExtensionsPageURLString = @"babelchrome://extensions";
static NSString* const kModulesPageURLString = @"babelchrome://modules";
static const NSInteger kDeveloperToolsDockTagLeft = 1;
static const NSInteger kDeveloperToolsDockTagRight = 2;
static const NSInteger kDeveloperToolsDockTagBottom = 3;
static const NSInteger kDeveloperToolsDockTagTop = 4;
static const int64_t kKeyboardTabSelectionBrowserCreationDelayNanoseconds = 220 * NSEC_PER_MSEC;
static const int64_t kAdjacentTabPreloadInitialDelayNanoseconds = 700 * NSEC_PER_MSEC;
static const int64_t kAdjacentTabPreloadStepDelayNanoseconds = 350 * NSEC_PER_MSEC;
static const int64_t kTabDragGroupHoverDelayNanoseconds = 450 * NSEC_PER_MSEC;
static const NSUInteger kMaximumLivePageBrowsers = 8;

class BabelReloadIgnoreCacheCallback final : public CefCompletionCallback {
 public:
  explicit BabelReloadIgnoreCacheCallback(CefRefPtr<CefBrowser> browser)
      : browser_(browser) {}

  void OnComplete() override {
    if (browser_) {
      browser_->ReloadIgnoreCache();
    }
  }

 private:
  CefRefPtr<CefBrowser> browser_;

  IMPLEMENT_REFCOUNTING(BabelReloadIgnoreCacheCallback);
};

@interface BabelOmniboxSuggestionRowView : NSControl

@property(nonatomic, strong) NSTextField* titleLabel;
@property(nonatomic, strong) NSTextField* subtitleLabel;
@property(nonatomic, strong) NSImage* iconImage;
@property(nonatomic, assign, getter=isSuggestionHighlighted) BOOL suggestionHighlighted;

- (instancetype)initWithFrame:(NSRect)frame;
- (void)configureWithTitle:(NSString*)title subtitle:(NSString*)subtitle iconImage:(NSImage*)iconImage;

@end

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

@interface BabelThemeRootView : NSView

@property(nonatomic, weak) id themeTarget;
@property(nonatomic, assign) SEL themeAction;

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

@interface BabelBadgeLabel : NSView

@property(nonatomic, copy) NSString* settingsRoute;
@property(nonatomic, weak) id settingsTarget;
@property(nonatomic, assign) SEL settingsAction;

- (void)configureWithText:(NSString*)text
                textColor:(NSColor*)textColor
          backgroundColor:(NSColor*)backgroundColor;

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

@implementation BabelBrowserWindowController {
  NSView* rootView_;
  NSSplitView* splitView_;
  NSView* sidebarView_;
  NSTextField* sidebarTitle_;
  NSButton* sidebarCollapseButton_;
  NSButton* newGroupButton_;
  NSView* groupsListView_;
  NSView* rightView_;
  NSView* tabsBarPanel_;
  NSView* tabsItemsPanel_;
  NSButton* newTabButton_;
  NSView* addressBarPanel_;
  NSTextField* addressLabel_;
  NSView* addressTextFieldContainer_;
  NSTextField* urlTextField_;
  BabelBadgeLabel* viewerBadgeLabel_;
  NSButton* reloadButton_;
  NSView* omniboxSuggestionsPanel_;
  NSView* pagesPanel_;
  NSView* linkStatusBarView_;
  NSTextField* linkStatusBarLabel_;
  NSMutableArray<BabelBrowserGroup*>* groups_;
  NSMutableArray<BabelClosedTab*>* closedTabs_;
  NSMutableArray<NSDictionary*>* omniboxSuggestions_;
  NSMutableDictionary<NSString*, NSArray<NSString*>*>* googleSuggestCache_;
  NSMutableDictionary<NSString*, NSImage*>* faviconImagesByOrigin_;
  NSMutableArray<NSString*>* recentlyUsedTabIdentifiers_;
  NSMutableSet<NSString*>* evictingBrowserTabIdentifiers_;
  NSMutableDictionary<NSNumber*, NSDate*>* pendingLocalDropBrowserIdentifiers_;
  NSMutableDictionary<NSNumber*, NSArray<NSString*>*>* pendingRefreshURLStringsByBrowserIdentifier_;
  BabelBrowserGroup* selectedGroup_;
  NSMutableArray<BabelBrowserTab*>* tabs_;
  NSMutableArray<BabelBrowserTab*>* pendingTabs_;
  BabelBrowserTab* selectedTab_;
  BabelBrowserTab* draggingTab_;
  BabelBrowserGroup* pendingTabDragHoverGroup_;
  BabelBrowserTab* pendingDeveloperToolsTab_;
  CefRefPtr<BabelBrowserClient> browserClient_;
  NSString* developerToolsDockMode_;
  CGFloat developerToolsSizeRatio_;
  CGFloat expandedSidebarWidth_;
  BOOL sidebarCollapsed_;
  BOOL isTerminating_;
  BOOL didRestoreMainWindowState_;
  BOOL isReorderingGroups_;
  BOOL isReorderingTabs_;
  BOOL isDraggingTabAcrossGroups_;
  BOOL isRestoringSession_;
  BOOL isBuildingInterface_;
  BOOL didApplyInitialSidebarRestore_;
  BOOL needsInitialRestoredBrowserCreation_;
  NSUInteger deferredBrowserCreationGeneration_;
  NSUInteger adjacentTabPreloadGeneration_;
  NSUInteger tabDragHoverGeneration_;
  NSUInteger googleSuggestGeneration_;
  NSInteger selectedOmniboxSuggestionIndex_;
}

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 1280, 820);
  NSWindow* window =
      [[NSWindow alloc] initWithContentRect:frame
                                  styleMask:NSWindowStyleMaskTitled |
                                            NSWindowStyleMaskClosable |
                                            NSWindowStyleMaskMiniaturizable |
                                            NSWindowStyleMaskResizable
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  window.title = BabelChromeConfiguration.applicationName;
  window.minSize = NSMakeSize(900, 580);
  window.titleVisibility = NSWindowTitleHidden;
  window.titlebarAppearsTransparent = YES;
  window.movableByWindowBackground = YES;
  window.styleMask = window.styleMask | NSWindowStyleMaskFullSizeContentView;

  self = [super initWithWindow:window];
  if (self) {
    groups_ = [NSMutableArray array];
    closedTabs_ = [NSMutableArray array];
    omniboxSuggestions_ = [NSMutableArray array];
    googleSuggestCache_ = [NSMutableDictionary dictionary];
    faviconImagesByOrigin_ = [NSMutableDictionary dictionary];
    recentlyUsedTabIdentifiers_ = [NSMutableArray array];
    evictingBrowserTabIdentifiers_ = [NSMutableSet set];
    pendingLocalDropBrowserIdentifiers_ = [NSMutableDictionary dictionary];
    pendingRefreshURLStringsByBrowserIdentifier_ = [NSMutableDictionary dictionary];
    tabs_ = [NSMutableArray array];
    pendingTabs_ = [NSMutableArray array];
    browserClient_ = new BabelBrowserClient(self);
    developerToolsDockMode_ = [self restoredDeveloperToolsDockMode];
    developerToolsSizeRatio_ = [self restoredDeveloperToolsSizeRatio];
    expandedSidebarWidth_ = kSidebarInitialWidth;
    sidebarCollapsed_ = NO;
    isTerminating_ = NO;
    didRestoreMainWindowState_ = NO;
    isReorderingGroups_ = NO;
    isReorderingTabs_ = NO;
    isDraggingTabAcrossGroups_ = NO;
    isRestoringSession_ = NO;
    isBuildingInterface_ = NO;
    didApplyInitialSidebarRestore_ = NO;
    needsInitialRestoredBrowserCreation_ = NO;
    deferredBrowserCreationGeneration_ = 0;
    adjacentTabPreloadGeneration_ = 0;
    tabDragHoverGeneration_ = 0;
    googleSuggestGeneration_ = 0;
    selectedOmniboxSuggestionIndex_ = -1;
    [self restoreSessionWindowFrame];
    [self restoreProfileExtensionsMovedByOlderVersions];
    [self clearPendingProfileExtensionRestartStates];
    window.delegate = self;
    [self buildInterface];
    [self restoreFaviconStore];
    [self restoreSessionGroupsAndTabs];
    [self restoreSessionInitialBrowsers];
    [self restoreSessionModulesLifecycle];
  }
  return self;
}

- (void)restoreSessionWindowFrame {
  [self restoreMainWindowFrame];
}

- (void)restoreSessionWindowZoom {
  [self restoreMainWindowZoomStateIfNeeded];
}

- (void)restoreSessionSidebarCollapsedState {
  sidebarCollapsed_ = [NSUserDefaults.standardUserDefaults boolForKey:kSidebarCollapsedDefaultsKey];
}

- (void)restoreSessionSidebarExpandedWidth {
  expandedSidebarWidth_ = [self restoredExpandedSidebarWidth];
}

- (void)restoreSessionSidebarState {
  [self restoreSessionSidebarCollapsedState];
  [self restoreSessionSidebarExpandedWidth];
}

- (void)applySessionSidebarDividerPosition {
  if (didApplyInitialSidebarRestore_) {
    return;
  }

  didApplyInitialSidebarRestore_ = YES;
  BOOL previousBuildingState = isBuildingInterface_;
  isBuildingInterface_ = YES;
  [splitView_ setPosition:[self targetSidebarWidth] ofDividerAtIndex:0];
  [self layoutInterfaceForCurrentSplitViewSize];
  isBuildingInterface_ = previousBuildingState;
}

- (void)restoreSessionSidebarAfterInitialLayout {
  [self restoreSessionSidebarState];
  [self applySessionSidebarDividerPosition];
}

- (void)restoreSessionGroupsAndTabs {
  isRestoringSession_ = YES;
  [self restoreGroupsState];
  isRestoringSession_ = NO;
}

- (void)restoreSessionInitialBrowsers {
  [self createInitialRestoredBrowserIfNeeded];
}

- (void)restoreSessionModulesLifecycle {
  [self dispatchApplicationDidStartModuleLifecycleHook];
}

- (void)dispatchApplicationDidStartModuleLifecycleHook {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSError* error = nil;
    NSDictionary* response =
        [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.did-start" error:&error];
    if (error) {
      NSLog(@"BabelChrome module lifecycle app.did-start failed: %@", error.localizedDescription);
    }
    NSArray<NSString*>* restoredProjectIdentifiers =
        [self restoredProjectIdentifiersFromLifecycleResponse:response];
    if (restoredProjectIdentifiers.count > 0) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadServerTabsWithProjectIdentifiers:restoredProjectIdentifiers];
      });
    }
  });
}

- (void)dispatchApplicationWillQuitModuleLifecycleHook {
  NSError* error = nil;
  [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.will-quit" error:&error];
  if (error) {
    NSLog(@"BabelChrome module lifecycle app.will-quit failed: %@", error.localizedDescription);
  }
}

- (void)buildInterface {
  isBuildingInterface_ = YES;
  BabelThemeRootView* themeRootView = [[BabelThemeRootView alloc] initWithFrame:self.window.contentView.bounds];
  themeRootView.themeTarget = self;
  themeRootView.themeAction = @selector(applyThemeColors);
  rootView_ = themeRootView;
  rootView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  splitView_ = [[NSSplitView alloc] initWithFrame:rootView_.bounds];
  splitView_.delegate = self;
  splitView_.dividerStyle = NSSplitViewDividerStyleThin;
  splitView_.vertical = YES;
  splitView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  sidebarView_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kSidebarInitialWidth, 820)];
  sidebarView_.wantsLayer = YES;

  sidebarTitle_ = [NSTextField labelWithString:@"BabelForge"];
  sidebarTitle_.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  [sidebarTitle_ sizeToFit];
  sidebarTitle_.frame = NSMakeRect(kSidebarHeaderLeadingInset + kSidebarHeaderButtonSize +
                                       kSidebarHeaderButtonGap,
                                   780,
                                   sidebarTitle_.frame.size.width,
                                   24);
  sidebarTitle_.autoresizingMask = NSViewMinYMargin;
  [sidebarView_ addSubview:sidebarTitle_];
  [self restoreSessionSidebarState];
  CGFloat initialSidebarWidth = [self targetSidebarWidth];
  sidebarView_.frame = NSMakeRect(0, 0, initialSidebarWidth, 820);

  sidebarCollapseButton_ = BabelButton(@"", self, @selector(toggleSidebarCollapsed:));
  sidebarCollapseButton_.bezelStyle = NSBezelStyleTexturedRounded;
  sidebarCollapseButton_.toolTip = @"Collapse Sidebar";
  [sidebarView_ addSubview:sidebarCollapseButton_];

  newGroupButton_ = BabelButton(@"+", self, @selector(addGroupFromButton:));
  newGroupButton_.bezelStyle = NSBezelStyleTexturedRounded;
  newGroupButton_.font = [NSFont systemFontOfSize:17 weight:NSFontWeightRegular];
  newGroupButton_.toolTip = @"New Group";
  newGroupButton_.frame = NSMakeRect(200, 778, kSidebarHeaderButtonSize, kSidebarHeaderButtonSize);
  newGroupButton_.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
  [sidebarView_ addSubview:newGroupButton_];

  groupsListView_ = [[BabelFlippedView alloc] initWithFrame:NSMakeRect(5, 24, 230, 740)];
  groupsListView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [sidebarView_ addSubview:groupsListView_];

  rightView_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 820)];
  rightView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  rightView_.wantsLayer = YES;

  tabsBarPanel_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 780, 1040, kTabBarHeight)];
  tabsBarPanel_.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tabsBarPanel_.wantsLayer = YES;
  [rootView_ addSubview:tabsBarPanel_];

  tabsItemsPanel_ = [[NSView alloc] initWithFrame:NSMakeRect(8, 4, 990, 34)];
  tabsItemsPanel_.autoresizingMask = NSViewWidthSizable;
  tabsItemsPanel_.clipsToBounds = YES;
  [tabsBarPanel_ addSubview:tabsItemsPanel_];

  newTabButton_ = BabelButton(@"+", self, @selector(openNewTabFromButton:));
  newTabButton_.bezelStyle = NSBezelStyleTexturedRounded;
  newTabButton_.font = [NSFont systemFontOfSize:17 weight:NSFontWeightRegular];
  newTabButton_.toolTip = @"New Tab";
  newTabButton_.frame = NSMakeRect(1002, 6, 28, 28);
  newTabButton_.autoresizingMask = NSViewMinXMargin;
  [tabsBarPanel_ addSubview:newTabButton_];

  addressBarPanel_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 736, 1040, kToolbarHeight)];
  addressBarPanel_.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  addressBarPanel_.wantsLayer = YES;
  [rightView_ addSubview:addressBarPanel_];

  addressLabel_ = [NSTextField labelWithString:@"URL"];
  addressLabel_.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  addressLabel_.alignment = NSTextAlignmentRight;
  [addressBarPanel_ addSubview:addressLabel_];

  addressTextFieldContainer_ = [[NSView alloc] initWithFrame:NSMakeRect(50, 7, 978, 30)];
  addressTextFieldContainer_.wantsLayer = YES;
  addressTextFieldContainer_.layer.borderWidth = 1.0;
  addressTextFieldContainer_.layer.cornerRadius = 6.0;
  addressTextFieldContainer_.autoresizingMask = NSViewWidthSizable;
  [addressBarPanel_ addSubview:addressTextFieldContainer_];

  viewerBadgeLabel_ = [[BabelBadgeLabel alloc] init];
  viewerBadgeLabel_.hidden = YES;
  viewerBadgeLabel_.settingsTarget = self;
  viewerBadgeLabel_.settingsAction = @selector(openAddressBadgeSettingsFromMenu:);
  [addressTextFieldContainer_ addSubview:viewerBadgeLabel_];

  urlTextField_ = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 4, 962, 22)];
  urlTextField_.delegate = self;
  urlTextField_.target = self;
  urlTextField_.action = @selector(navigateFromAddressField:);
  urlTextField_.placeholderString = @"Enter URL";
  urlTextField_.font = [NSFont systemFontOfSize:14];
  urlTextField_.bezeled = NO;
  urlTextField_.drawsBackground = NO;
  urlTextField_.focusRingType = NSFocusRingTypeNone;
  urlTextField_.autoresizingMask = NSViewWidthSizable;
  [addressTextFieldContainer_ addSubview:urlTextField_];

  reloadButton_ = BabelButton(@"", self, @selector(reloadSelectedTabFromButton:));
  reloadButton_.bezelStyle = NSBezelStyleTexturedRounded;
  reloadButton_.toolTip = @"Reload";
  reloadButton_.frame = NSMakeRect(1000, 8, 28, 28);
  reloadButton_.autoresizingMask = NSViewMinXMargin;
  ConfigureIconButton(reloadButton_, @"toolbar-reload", @"↻");
  [addressBarPanel_ addSubview:reloadButton_];

  omniboxSuggestionsPanel_ = [[NSView alloc] initWithFrame:NSMakeRect(50, 520, 978, 0)];
  omniboxSuggestionsPanel_.hidden = YES;
  omniboxSuggestionsPanel_.wantsLayer = YES;
  omniboxSuggestionsPanel_.layer.cornerRadius = 8.0;
  omniboxSuggestionsPanel_.layer.borderWidth = 1.0;
  [rightView_ addSubview:omniboxSuggestionsPanel_];

  pagesPanel_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 736)];
  pagesPanel_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  pagesPanel_.clipsToBounds = YES;
  [rightView_ addSubview:pagesPanel_];

  linkStatusBarView_ = [[NSView alloc] initWithFrame:NSMakeRect(8, 8, 320, kLinkStatusBarHeight)];
  linkStatusBarView_.hidden = YES;
  linkStatusBarView_.wantsLayer = YES;
  linkStatusBarView_.layer.borderWidth = 1.0;
  linkStatusBarView_.layer.cornerRadius = 5.0;
  [rightView_ addSubview:linkStatusBarView_ positioned:NSWindowAbove relativeTo:pagesPanel_];

  linkStatusBarLabel_ = [NSTextField labelWithString:@""];
  linkStatusBarLabel_.font = [NSFont systemFontOfSize:12];
  linkStatusBarLabel_.lineBreakMode = NSLineBreakByTruncatingMiddle;
  linkStatusBarLabel_.frame = NSMakeRect(8, 4, 304, 16);
  linkStatusBarLabel_.autoresizingMask = NSViewWidthSizable;
  [linkStatusBarView_ addSubview:linkStatusBarLabel_];

  [splitView_ addSubview:sidebarView_];
  [splitView_ addSubview:rightView_];
  [rootView_ addSubview:splitView_ positioned:NSWindowBelow relativeTo:tabsBarPanel_];
  [self.window setContentView:rootView_];
  [self applyThemeColors];
  [splitView_ setPosition:initialSidebarWidth ofDividerAtIndex:0];
  [self layoutInterfaceForCurrentSplitViewSize];
  isBuildingInterface_ = NO;
}

- (void)restoreGroupsState {
  NSData* data = [NSData dataWithContentsOfURL:BabelChromeConfiguration.groupsStateFileURL];
  if (data.length > 0) {
    NSError* error = nil;
    NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data
                                                          options:0
                                                            error:&error];
    if ([state isKindOfClass:NSDictionary.class]) {
      [self restoreGroupsFromState:state];
    }
  }

  BabelBrowserGroup* defaultGroup = [self groupWithIdentifier:kDefaultGroupIdentifier];
  if (!defaultGroup) {
    defaultGroup = [self createGroupWithName:kDefaultGroupName identifier:kDefaultGroupIdentifier];
  }

  NSString* selectedGroupIdentifier = [self persistedSelectedGroupIdentifierFromData:data];
  BabelBrowserGroup* groupToSelect = [self groupWithIdentifier:selectedGroupIdentifier] ?: defaultGroup;
  [self selectGroup:groupToSelect];
  [self saveGroupsState];
}

- (NSString*)persistedSelectedGroupIdentifierFromData:(NSData*)data {
  if (data.length == 0) {
    return kDefaultGroupIdentifier;
  }

  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSString* selectedGroupIdentifier = state[@"selectedGroupId"];
  return selectedGroupIdentifier.length > 0 ? selectedGroupIdentifier : kDefaultGroupIdentifier;
}

- (void)restoreGroupsFromState:(NSDictionary*)state {
  NSArray* groupStates = state[@"groups"];
  if (![groupStates isKindOfClass:NSArray.class]) {
    return;
  }

  for (NSDictionary* groupState in groupStates) {
    if (![groupState isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* groupName = groupState[@"name"];
    NSString* groupIdentifier = groupState[@"id"];
    if (groupName.length == 0 || groupIdentifier.length == 0) {
      continue;
    }

    BabelBrowserGroup* group = [self createGroupWithName:groupName identifier:groupIdentifier];
    group.selectedTabIdentifier = groupState[@"selectedTabId"];

    NSArray* tabStates = groupState[@"tabs"];
    if (![tabStates isKindOfClass:NSArray.class]) {
      continue;
    }

    for (NSDictionary* tabState in tabStates) {
      if (![tabState isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* urlString = tabState[@"url"];
      if (urlString.length == 0) {
        continue;
      }

      NSString* requestedURLString = tabState[@"requestedUrl"] ?: urlString;
      NSString* restoredNavigationURLString =
          [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
      if (restoredNavigationURLString.length > 0) {
        urlString = restoredNavigationURLString;
      } else if ([self isStableBabelChromeURLString:requestedURLString]) {
        urlString = requestedURLString;
      }
      if ([self tabWithURLString:requestedURLString inGroup:group] ||
          [self tabWithURLString:urlString inGroup:group]) {
        continue;
      }

      NSString* tabIdentifier = tabState[@"id"] ?: NSUUID.UUID.UUIDString;
      NSString* title = tabState[@"title"] ?: urlString;
      BabelBrowserTab* tab = [self makeTabForURL:urlString
                                      identifier:tabIdentifier
                                           title:title];
      tab.requestedURLString = requestedURLString;
      tab.parentTabIdentifier = tabState[@"parentTabId"];
      [group.tabs addObject:tab];
      [pagesPanel_ addSubview:tab.hostView];
      [pagesPanel_ addSubview:tab.developerToolsPanelView];
    }
  }
}

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  BabelBrowserGroup* existingGroup = [self groupWithIdentifier:identifier];
  if (existingGroup) {
    return existingGroup;
  }

  BabelBrowserGroup* group = [[BabelBrowserGroup alloc] init];
  group.identifier = identifier;
  group.name = name;
  group.groupItemView = [[BabelGroupItemView alloc] initWithIdentifier:identifier title:name];
  group.groupItemView.target = self;
  group.groupItemView.action = @selector(selectGroupFromItem:);
  group.groupItemView.renameTarget = self;
  group.groupItemView.renameAction = @selector(renameGroupFromMenu:);
  group.groupItemView.deleteTarget = self;
  group.groupItemView.deleteAction = @selector(deleteGroupFromMenu:);
  group.groupItemView.dragTarget = self;
  group.groupItemView.dragAction = @selector(dragGroupFromItem:);
  group.groupItemView.dragEndTarget = self;
  group.groupItemView.dragEndAction = @selector(finishDraggingGroupFromItem:);
  [groups_ addObject:group];
  [groupsListView_ addSubview:group.groupItemView];
  [self layoutGroupItems];
  return group;
}

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if ([group.identifier isEqualToString:identifier]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name {
  for (BabelBrowserGroup* group in groups_) {
    if ([group.name isEqualToString:name]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name {
  NSString* normalizedName = name.length > 0 ? name : kDefaultGroupName;
  BabelBrowserGroup* existingGroup = [self groupWithName:normalizedName];
  if (existingGroup) {
    return existingGroup;
  }

  NSString* identifier = [normalizedName isEqualToString:kDefaultGroupName]
      ? kDefaultGroupIdentifier
      : NSUUID.UUID.UUIDString;
  return [self createGroupWithName:normalizedName identifier:identifier];
}

- (NSString*)nextManualGroupName {
  NSUInteger index = 1;
  while ([self groupWithName:[NSString stringWithFormat:@"Group %lu", (unsigned long)index]]) {
    index++;
  }
  return [NSString stringWithFormat:@"Group %lu", (unsigned long)index];
}

- (void)addGroupFromButton:(id)sender {
  NSString* groupName = [self nextManualGroupName];
  BabelBrowserGroup* group = [self createGroupWithName:groupName identifier:NSUUID.UUID.UUIDString];
  [self selectGroup:group];
  [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [self saveGroupsState];
}

- (void)selectGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [self groupWithIdentifier:groupItemView.identifier];
  if (group) {
    [self selectGroup:group];
    [self saveGroupsState];
  }
}

- (void)dragGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [self groupWithIdentifier:groupItemView.identifier];
  if (!group) {
    return;
  }

  NSUInteger currentIndex = [groups_ indexOfObject:group];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSEvent* currentEvent = NSApp.currentEvent;
  NSPoint listPoint = [groupsListView_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self groupInsertionIndexForListY:listPoint.y];
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  targetIndex = MIN(targetIndex, groups_.count - 1);
  if (targetIndex == currentIndex) {
    return;
  }

  isReorderingGroups_ = YES;
  [groups_ removeObjectAtIndex:currentIndex];
  [groups_ insertObject:group atIndex:targetIndex];
  [self layoutGroupItems];
}

- (NSUInteger)groupInsertionIndexForListY:(CGFloat)y {
  if (groups_.count == 0) {
    return 0;
  }

  CGFloat rowPitch = 34.0;
  NSInteger targetIndex = (NSInteger)floor((y + (rowPitch / 2.0)) / rowPitch);
  if (targetIndex < 0) {
    return 0;
  }
  return MIN((NSUInteger)targetIndex, groups_.count);
}

- (void)finishDraggingGroupFromItem:(BabelGroupItemView*)groupItemView {
  if (!isReorderingGroups_) {
    return;
  }

  isReorderingGroups_ = NO;
  [self layoutGroupItems];
  [self saveGroupsState];
}

- (void)selectGroup:(BabelBrowserGroup*)group {
  selectedGroup_ = group;
  tabs_ = group.tabs;

  for (BabelBrowserGroup* currentGroup in groups_) {
    currentGroup.groupItemView.selected = currentGroup == group;
    for (BabelBrowserTab* tab in currentGroup.tabs) {
      if (tab != draggingTab_) {
        [tab.tabItemView removeFromSuperview];
      }
      tab.hostView.hidden = YES;
      tab.developerToolsPanelView.hidden = YES;
    }
  }

  for (BabelBrowserTab* tab in tabs_) {
    if (tab.tabItemView.superview != tabsItemsPanel_) {
      [tabsItemsPanel_ addSubview:tab.tabItemView];
    }
  }

  BabelBrowserTab* tabToSelect = [self tabWithIdentifier:group.selectedTabIdentifier inGroup:group] ?:
      tabs_.lastObject;
  if (tabToSelect) {
    [self selectTab:tabToSelect];
  } else {
    selectedTab_ = nil;
    [self clearAddressBar];
    [self updateWindowTitleForSelectedTab];
    [self layoutTabItemsSelectingLastTab:NO];
  }
  [self layoutGroupItems];
}

- (void)deleteGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [self groupWithIdentifier:groupIdentifier];
  if (!group || groups_.count <= 1) {
    return;
  }

  NSUInteger groupIndex = [groups_ indexOfObject:group];
  BabelBrowserGroup* nextGroup = [self groupToSelectAfterDeletingGroupAtIndex:groupIndex];
  [self deleteGroup:group selectingGroup:nextGroup];
}

- (void)renameGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [self groupWithIdentifier:groupIdentifier];
  if (!group) {
    return;
  }

  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Rename Group";
  alert.informativeText = @"Enter the new group name.";
  [alert addButtonWithTitle:@"Rename"];
  [alert addButtonWithTitle:@"Cancel"];

  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)];
  textField.stringValue = group.name ?: @"";
  alert.accessoryView = textField;

  NSModalResponse response = [alert runModal];
  if (response != NSAlertFirstButtonReturn) {
    return;
  }

  NSString* newName = [textField.stringValue stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (newName.length == 0 || [newName isEqualToString:group.name]) {
    return;
  }

  BabelBrowserGroup* existingGroup = [self groupWithName:newName];
  if (existingGroup && existingGroup != group) {
    [self showGroupRenameDuplicateNameAlert:newName];
    return;
  }

  group.name = newName;
  group.groupItemView.title = newName;
  [self saveGroupsState];
}

- (void)showGroupRenameDuplicateNameAlert:(NSString*)groupName {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Group Name Already Exists";
  alert.informativeText = [NSString stringWithFormat:@"A group named \"%@\" already exists.",
                                                     groupName];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex {
  if (groups_.count <= 1) {
    return nil;
  }

  NSUInteger nextIndex = groupIndex > 0 ? groupIndex - 1 : 1;
  return groups_[nextIndex];
}

- (void)deleteGroup:(BabelBrowserGroup*)group selectingGroup:(BabelBrowserGroup*)nextGroup {
  BOOL deletingSelectedGroup = group == selectedGroup_;
  for (BabelBrowserTab* tab in [group.tabs copy]) {
    CefRefPtr<CefBrowser> browser = [tab browser];
    [self pushClosedTab:tab fromGroup:group];
    [self removeTab:tab fromGroup:group allowSelection:!deletingSelectedGroup];
    if (browser) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

  [group.groupItemView removeFromSuperview];
  [groups_ removeObject:group];

  if (deletingSelectedGroup) {
    [self selectGroup:nextGroup ?: groups_.firstObject];
  } else {
    [self layoutGroupItems];
  }

  [self saveGroupsState];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier inGroup:(BabelBrowserGroup*)group {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserTab* tab in group.tabs) {
    if ([tab.identifier isEqualToString:identifier]) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserTab*)tabWithURLString:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  for (BabelBrowserTab* tab in group.tabs) {
    if ([self tab:tab matchesURLString:urlString]) {
      return tab;
    }
  }
  return nil;
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesURLString:(NSString*)urlString {
  if ([tab.urlString isEqualToString:urlString] ||
      [tab.requestedURLString isEqualToString:urlString]) {
    return YES;
  }

  NSString* normalizedURLString = [self URLStringByRemovingTrailingSlash:urlString];
  if ([[self URLStringByRemovingTrailingSlash:tab.urlString] isEqualToString:normalizedURLString] ||
      [[self URLStringByRemovingTrailingSlash:tab.requestedURLString] isEqualToString:normalizedURLString]) {
    return YES;
  }

  return [self rootURLString:urlString matchesURLString:tab.urlString] ||
         [self rootURLString:urlString matchesURLString:tab.requestedURLString];
}

- (NSString*)URLStringByRemovingTrailingSlash:(NSString*)urlString {
  if (urlString.length > 1 && [urlString hasSuffix:@"/"]) {
    return [urlString substringToIndex:urlString.length - 1];
  }
  return urlString ?: @"";
}

- (BOOL)rootURLString:(NSString*)rootURLString matchesURLString:(NSString*)candidateURLString {
  NSURLComponents* rootComponents = [NSURLComponents componentsWithString:rootURLString];
  NSURLComponents* candidateComponents = [NSURLComponents componentsWithString:candidateURLString];
  if (rootComponents.scheme.length == 0 || candidateComponents.scheme.length == 0) {
    return NO;
  }

  NSString* rootPath = rootComponents.path ?: @"";
  if (rootPath.length > 0 && ![rootPath isEqualToString:@"/"]) {
    return NO;
  }

  BOOL sameScheme = [rootComponents.scheme isEqualToString:candidateComponents.scheme];
  BOOL sameHost = [rootComponents.host isEqualToString:candidateComponents.host];
  NSNumber* rootPort = rootComponents.port ?: @([rootComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  NSNumber* candidatePort = candidateComponents.port ?:
      @([candidateComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  return sameScheme && sameHost && [rootPort isEqualToNumber:candidatePort];
}

- (void)saveGroupsState {
  NSMutableArray<NSDictionary*>* groupStates = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    NSMutableArray<NSDictionary*>* tabStates = [NSMutableArray array];
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      [tabStates addObject:@{
        @"id": tab.identifier ?: @"",
        @"url": tab.urlString ?: @"",
        @"requestedUrl": tab.requestedURLString ?: tab.urlString ?: @"",
        @"title": tab.title ?: tab.urlString ?: @"",
        @"parentTabId": tab.parentTabIdentifier ?: @""
      }];
    }

    [groupStates addObject:@{
      @"id": group.identifier ?: @"",
      @"name": group.name ?: @"",
      @"selectedTabId": group.selectedTabIdentifier ?: @"",
      @"tabs": tabStates
    }];
  }

  NSDictionary* state = @{
    @"selectedGroupId": selectedGroup_.identifier ?: kDefaultGroupIdentifier,
    @"groups": groupStates
  };

  NSURL* stateURL = BabelChromeConfiguration.groupsStateFileURL;
  [NSFileManager.defaultManager createDirectoryAtURL:stateURL.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:state
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [data writeToURL:stateURL atomically:YES];
}

- (void)openURLs:(NSArray<NSURL*>*)urls {
  if (urls.count == 0 && [self totalTabCount] > 0) {
    [self showMainWindow];
    [self saveGroupsState];
    return;
  }

  NSArray<NSURL*>* urlsToOpen = urls.count > 0
      ? urls
      : @[ [NSURL URLWithString:BabelChromeConfiguration.defaultURLString] ];

  for (NSURL* url in urlsToOpen) {
    [self openURL:url];
  }

  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openNewTab {
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openAdjacentNewTab {
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  if (selectedTab_ && [group.tabs containsObject:selectedTab_]) {
    [self createTabForURL:BabelChromeConfiguration.defaultURLString
                  inGroup:group
                parentTab:selectedTab_
     respectingUserStrategy:NO];
  } else {
    [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  }
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openNewTabFromButton:(id)sender {
  [self openNewTab];
}

- (void)scheduleQueuedURLOpening {
}

- (void)drainQueuedURLOpening {
}

- (void)openURL:(NSURL*)url {
  if ([url.scheme isEqualToString:@"babelchrome"]) {
    if ([self isStableViewerURLString:url.absoluteString]) {
      [self openURLString:url.absoluteString groupName:kDefaultGroupName];
      return;
    }
    if ([self handleInternalNavigationURLString:url.absoluteString]) {
      return;
    }
    [self openBabelChromeCommandURL:url];
    return;
  }

  [self openURLString:url.absoluteString groupName:kDefaultGroupName];
}

- (void)openBabelChromeCommandURL:(NSURL*)url {
  if ([self openCompactBabelChromeCommandString:url.absoluteString]) {
    return;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:url
                                           resolvingAgainstBaseURL:NO];
  NSString* groupName = kDefaultGroupName;
  NSString* targetURLString = nil;

  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:@"group"] && item.value.length > 0) {
      groupName = item.value;
      continue;
    }

    if ([item.name isEqualToString:@"url"] && item.value.length > 0) {
      targetURLString = item.value;
    }
  }

  if (targetURLString.length == 0) {
    targetURLString = BabelChromeConfiguration.defaultURLString;
  }

  [self openURLString:targetURLString groupName:groupName];
}

- (BOOL)openCompactBabelChromeCommandString:(NSString*)urlString {
  NSString* payload = nil;
  if ([urlString hasPrefix:kCompactCommandOpaquePrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandOpaquePrefix.length];
  } else if ([urlString hasPrefix:kCompactCommandHierarchicalPrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandHierarchicalPrefix.length];
  }

  if (!payload) {
    return NO;
  }

  NSArray<NSString*>* separators = @[
    @"::|::url:",
    @"::%7C::url:",
    @"::%7c::url:"
  ];

  NSRange separatorRange = NSMakeRange(NSNotFound, 0);
  for (NSString* separator in separators) {
    separatorRange = [payload rangeOfString:separator];
    if (separatorRange.location != NSNotFound) {
      break;
    }
  }

  if (separatorRange.location == NSNotFound) {
    return NO;
  }

  NSString* encodedGroupName = [payload substringToIndex:separatorRange.location];
  NSString* targetURLString =
      [payload substringFromIndex:separatorRange.location + separatorRange.length];
  NSString* groupName = encodedGroupName.stringByRemovingPercentEncoding ?: encodedGroupName;
  if (groupName.length == 0) {
    groupName = kDefaultGroupName;
  }

  if (targetURLString.length == 0) {
    targetURLString = BabelChromeConfiguration.defaultURLString;
  }

  [self openURLString:targetURLString groupName:groupName];
  return YES;
}

- (void)openURLString:(NSString*)urlString groupName:(NSString*)groupName {
  BabelBrowserGroup* group = [self ensureGroupNamed:groupName];
  [self selectGroup:group];

  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([self isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* existingTab = [self tabWithURLString:requestedURLString inGroup:group] ?:
      [self tabWithURLString:urlString inGroup:group];
  if (existingTab) {
    if (![existingTab.urlString isEqualToString:navigationURLString]) {
      existingTab.urlString = navigationURLString;
      existingTab.requestedURLString = requestedURLString;
      if ([existingTab browser]) {
        existingTab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
    [self selectTab:existingTab];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* navigationExistingTab = [self tabWithURLString:navigationURLString inGroup:group];
  if (navigationExistingTab) {
    navigationExistingTab.requestedURLString = requestedURLString;
    [self selectTab:navigationExistingTab];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
}

- (NSString*)viewerURLStringForSupportedURLString:(NSString*)urlString {
  NSURL* url = [self sourceURLForViewerURLString:urlString];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSError* serviceError = nil;
  if (![BabelLocalServiceHost.sharedHost startIfNeededWithError:&serviceError]) {
    [self showLocalServiceStartupAlert:serviceError];
    return nil;
  }

  NSURL* viewerURL = [BabelLocalServiceHost.sharedHost viewerURLForURL:url];
  NSURLComponents* viewerComponents = viewerURL ? [NSURLComponents componentsWithURL:viewerURL
                                                             resolvingAgainstBaseURL:NO] : nil;
  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString];
  if (viewerKind.length == 0) {
    viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  }
  if (viewerComponents && [viewerKind isEqualToString:@"markdown"]) {
    NSMutableArray<NSURLQueryItem*>* queryItems =
        [viewerComponents.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"theme" value:[self markdownTheme]]];
    viewerComponents.queryItems = queryItems;
    viewerURL = viewerComponents.URL;
  }

  NSString* viewerURLString = viewerURL.absoluteString;
  NSString* fragment = [self stableViewerFragmentForURLString:urlString];
  if (viewerURLString.length > 0 && fragment.length > 0) {
    return [viewerURLString stringByAppendingString:fragment];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  NSString* sourceDisplayString = sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString;
  if (sourceDisplayString.length == 0) {
    sourceDisplayString = urlString ?: @"";
  }

  NSString* extension = sourceURL.pathExtension.lowercaseString ?: @"";
  NSString* title = @"No viewer installed for this file type";
  NSString* detail = extension.length > 0
      ? [NSString stringWithFormat:@"No enabled BabelChrome viewer module currently handles .%@ files.", extension]
      : @"No enabled BabelChrome viewer module currently handles this source.";
  NSString* html = [NSString stringWithFormat:
      @"<!doctype html>"
       "<html><head><meta charset='utf-8'>"
       "<style>"
       "body{margin:0;background:#f5f6f8;color:#1f2328;font:15px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;}"
       "main{max-width:760px;margin:92px auto;padding:0 28px;}"
       "h1{font-size:28px;line-height:1.2;margin:0 0 14px;font-weight:700;}"
       "p{line-height:1.55;margin:0 0 18px;color:#59636e;}"
       "code{display:block;background:#fff;border:1px solid #d8dee4;border-radius:8px;padding:14px 16px;white-space:pre-wrap;word-break:break-all;color:#1f2328;}"
       "</style></head><body><main>"
       "<h1>%@</h1>"
       "<p>%@</p>"
       "<code>%@</code>"
       "</main></body></html>",
      [self htmlEscapedString:title],
      [self htmlEscapedString:detail],
      [self htmlEscapedString:sourceDisplayString]];
  return [self dataURLStringForHTML:html];
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  if ([self isStableViewerURLString:urlString]) {
    return urlString;
  }

  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSString* viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  if (viewerKind.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceKind = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* encodedSourceValue = [self stableViewerEscapedString:sourceValue];
  if (encodedSourceValue.length == 0) {
    return nil;
  }

  return [NSString stringWithFormat:@"babelchrome://%@/%@/%@",
                                    viewerKind,
                                    sourceKind,
                                    encodedSourceValue];
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  if (![self isStableBabelChromeURLString:urlString]) {
    return nil;
  }

  NSString* viewerURLString = [self viewerURLStringForSupportedURLString:urlString];
  if (viewerURLString.length > 0) {
    return viewerURLString;
  }

  if ([self isStableViewerURLString:urlString]) {
    return [self noViewerInstalledPageURLStringForStableViewerURLString:urlString];
  }

  return [self moduleNavigationURLStringForStableBabelChromeURLString:urlString];
}

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0;
}

- (BOOL)isStableServerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] &&
         [components.host isEqualToString:@"server"] &&
         components.path.length > 1;
}

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString {
  if (![self isStableServerURLString:urlString]) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kInternalStartQueryParameter] &&
        ![item.value isEqualToString:@"0"]) {
      return YES;
    }
  }

  return NO;
}

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSMutableArray<NSString*>* refreshURLStrings = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if (![item.name isEqualToString:kInternalRefreshQueryParameter] || item.value.length == 0) {
      continue;
    }

    NSString* refreshURLString = item.value.stringByRemovingPercentEncoding ?: item.value;
    if ([self isStableBabelChromeURLString:refreshURLString]) {
      [refreshURLStrings addObject:refreshURLString];
    }
  }

  return refreshURLStrings;
}

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (!components) {
    return urlString;
  }

  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kInternalStartQueryParameter] ||
        [item.name isEqualToString:kInternalRefreshQueryParameter]) {
      continue;
    }

    [queryItems addObject:item];
  }

  components.queryItems = queryItems.count > 0 ? queryItems : nil;
  return components.string ?: urlString;
}

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components {
  NSString* path = components.percentEncodedPath ?: components.path ?: @"";
  NSArray<NSString*>* pathComponents = [path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 2 && pathComponents[1].length > 0) {
    return [@"/" stringByAppendingString:pathComponents[1]];
  }

  return path.length > 0 ? path : @"/";
}

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab {
  NSString* requestedURLString = tab.requestedURLString ?: @"";
  if (![self isStableServerURLString:requestedURLString]) {
    return requestedURLString;
  }

  NSURLComponents* requestedComponents =
      [NSURLComponents componentsWithString:requestedURLString];
  NSURLComponents* actualComponents =
      [NSURLComponents componentsWithString:tab.urlString ?: @""];
  NSString* actualScheme = actualComponents.scheme.lowercaseString ?: @"";
  if (![actualScheme isEqualToString:@"http"] && ![actualScheme isEqualToString:@"https"]) {
    return requestedURLString;
  }

  NSString* actualPath = actualComponents.percentEncodedPath ?: actualComponents.path ?: @"";
  if ([actualPath hasPrefix:@"/module/"]) {
    return requestedURLString;
  }

  NSString* projectPath = [self stableServerProjectPathForURLComponents:requestedComponents];
  if (actualPath.length > 0 && ![actualPath isEqualToString:@"/"]) {
    requestedComponents.percentEncodedPath = [projectPath stringByAppendingString:actualPath];
  } else {
    requestedComponents.percentEncodedPath = projectPath;
  }

  requestedComponents.percentEncodedQuery = actualComponents.percentEncodedQuery;
  requestedComponents.percentEncodedFragment = actualComponents.percentEncodedFragment;

  return requestedComponents.string ?: requestedURLString;
}

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* moduleIdentifier = nil;
  NSString* route = nil;
  NSString* sourceURLString = nil;
  if ([components.host isEqualToString:@"modules"]) {
    NSArray<NSString*>* pathComponents = [components.path pathComponents];
    if (pathComponents.count >= 3) {
      moduleIdentifier = pathComponents[1];
      route = pathComponents[2];
    }
  } else {
    NSError* error = nil;
    NSDictionary* moduleRoute = [self moduleRouteForBabelChromeComponents:components error:&error];
    if (!moduleRoute) {
      return nil;
    }

    moduleIdentifier =
        [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
    route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
    sourceURLString = urlString;
  }

  if (moduleIdentifier.length == 0 || route.length == 0) {
    return nil;
  }

  NSError* error = nil;
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                                       route:route
                                                             sourceURLString:sourceURLString
                                                                       error:&error];
  return moduleURL.absoluteString;
}

- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        return tab;
      }
    }
  }

  return nil;
}

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path hasPrefix:@"/module/"];
}

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.host isEqualToString:@"127.0.0.1"] ||
      (![components.scheme isEqualToString:@"http"] && ![components.scheme isEqualToString:@"https"])) {
    return NO;
  }

  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:@"token"] && item.value.length > 0) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path isEqualToString:@"/module/babelforge.project-launcher/index"];
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesRefreshURLString:(NSString*)requestedURLString {
  if ([tab.requestedURLString isEqualToString:requestedURLString]) {
    return YES;
  }

  if ([requestedURLString isEqualToString:@"babelchrome://project-launcher"] &&
      [self isProjectLauncherModuleURLString:tab.urlString]) {
    return YES;
  }

  if (![self isStableServerURLString:requestedURLString]) {
    return NO;
  }

  NSString* requestedProjectIdentifier =
      [self serverProjectIdentifierForStableURLString:requestedURLString];
  NSString* tabProjectIdentifier =
      [self serverProjectIdentifierForStableURLString:tab.requestedURLString];
  return requestedProjectIdentifier.length > 0 &&
         [requestedProjectIdentifier isEqualToString:tabProjectIdentifier];
}

- (void)reloadTabsWithRequestedURLString:(NSString*)requestedURLString excludingTab:(BabelBrowserTab*)excludedTab {
  if (![self isStableBabelChromeURLString:requestedURLString]) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab == excludedTab || ![self tab:tab matchesRefreshURLString:requestedURLString]) {
        continue;
      }

      NSString* stableURLString =
          [self isStableServerURLString:requestedURLString] ? tab.requestedURLString : requestedURLString;
      NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:stableURLString];
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
  }

  [self saveGroupsState];
}

- (void)reloadRequestedURLStrings:(NSArray<NSString*>*)requestedURLStrings excludingTab:(BabelBrowserTab*)excludedTab {
  for (NSString* requestedURLString in requestedURLStrings) {
    [self reloadTabsWithRequestedURLString:requestedURLString excludingTab:excludedTab];
  }
}

- (NSArray<NSString*>*)restoredProjectIdentifiersFromLifecycleResponse:(NSDictionary*)response {
  NSMutableArray<NSString*>* identifiers = [NSMutableArray array];
  NSArray* results = [response[@"results"] isKindOfClass:NSArray.class] ? response[@"results"] : @[];
  for (NSDictionary* result in results) {
    if (![result isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSDictionary* payload = [result[@"payload"] isKindOfClass:NSDictionary.class] ? result[@"payload"] : nil;
    NSArray* restored = [payload[@"restored"] isKindOfClass:NSArray.class] ? payload[@"restored"] : @[];
    for (NSString* identifier in restored) {
      if ([identifier isKindOfClass:NSString.class] && identifier.length > 0 &&
          ![identifiers containsObject:identifier]) {
        [identifiers addObject:identifier];
      }
    }
  }

  return identifiers;
}

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] ||
      ![components.host isEqualToString:@"server"]) {
    return @"";
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count < 2) {
    return @"";
  }

  return pathComponents[1].stringByRemovingPercentEncoding ?: pathComponents[1];
}

- (void)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers {
  NSSet<NSString*>* identifierSet = [NSSet setWithArray:projectIdentifiers];
  if (identifierSet.count == 0) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      NSString* projectIdentifier =
          [self serverProjectIdentifierForStableURLString:tab.requestedURLString];
      if (projectIdentifier.length == 0 || ![identifierSet containsObject:projectIdentifier]) {
        continue;
      }

      NSString* navigationURLString =
          [self navigationURLStringForStableBabelChromeURLString:tab.requestedURLString];
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
  }

  [self saveGroupsState];
}

- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![self stableServerURLStringRequestsStart:urlString]) {
    return NO;
  }

  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:urlString];
  if (navigationURLString.length == 0) {
    return NO;
  }

  NSString* requestedURLString = [self stableURLStringByRemovingInternalQueryParameters:urlString];
  NSArray<NSString*>* refreshURLStrings = [self refreshURLStringsForStableURLString:urlString];
  if (refreshURLStrings.count > 0) {
    pendingRefreshURLStringsByBrowserIdentifier_[@(browser->GetIdentifier())] = refreshURLStrings;
  }

  tab.requestedURLString = requestedURLString;
  tab.urlString = navigationURLString;
  browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  [self saveGroupsState];
  return YES;
}

- (BOOL)isStableViewerURLString:(NSString*)urlString {
  return [self viewerKindForStableViewerURLString:urlString].length > 0 &&
         [self sourceKindForStableViewerURLString:urlString].length > 0;
}

- (NSURL*)sourceURLForViewerURLString:(NSString*)urlString {
  NSString* sourceKind = nil;
  NSString* encodedSourceValue = nil;
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if ([components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0) {
    NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
    if (pathComponents.count >= 3) {
      NSString* candidateSourceKind = pathComponents[1];
      if ([candidateSourceKind isEqualToString:@"file"] || [candidateSourceKind isEqualToString:@"url"]) {
        sourceKind = candidateSourceKind;
        NSString* prefix = [NSString stringWithFormat:@"/%@/", candidateSourceKind];
        encodedSourceValue = [components.path hasPrefix:prefix]
            ? [components.path substringFromIndex:prefix.length]
            : @"";
      }
    }
  }

  if (encodedSourceValue.length > 0) {
    NSString* sourceValue = encodedSourceValue.stringByRemovingPercentEncoding ?: encodedSourceValue;
    if ([sourceKind isEqualToString:@"file"]) {
      return [NSURL fileURLWithPath:sourceValue];
    }
    return [NSURL URLWithString:sourceValue];
  }

  return [NSURL URLWithString:urlString ?: @""];
}

- (NSString*)stableViewerFragmentForURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return @"";
  }

  NSRange fragmentRange = [urlString rangeOfString:@"#"];
  if (fragmentRange.location == NSNotFound) {
    return @"";
  }

  return [urlString substringFromIndex:fragmentRange.location];
}

- (NSString*)stableViewerEscapedString:(NSString*)value {
  NSMutableCharacterSet* allowedCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
  [allowedCharacters addCharactersInString:@"-._~"];
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)viewerKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  return sourceKind.length > 0 ? components.host : nil;
}

- (NSString*)resolvedViewerKindForStableViewerURLString:(NSString*)urlString {
  NSString* viewerKind = [self viewerKindForStableViewerURLString:urlString];
  if (![viewerKind isEqualToString:@"viewer"]) {
    return viewerKind;
  }

  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (!sourceURL) {
    return nil;
  }

  return [BabelLocalServiceHost.sharedHost viewerKindForURL:sourceURL];
}

- (NSString*)sourceKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 3 &&
      ([pathComponents[1] isEqualToString:@"file"] || [pathComponents[1] isEqualToString:@"url"])) {
    return pathComponents[1];
  }
  return nil;
}

- (NSString*)displayURLStringForStableViewerURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return urlString ?: @"";
  }

  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString] ?:
      [self viewerKindForStableViewerURLString:urlString];
  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (viewerKind.length == 0 || sourceKind.length == 0 || !sourceURL) {
    return urlString.stringByRemovingPercentEncoding ?: urlString ?: @"";
  }

  NSString* sourceDisplayString = [sourceKind isEqualToString:@"file"]
      ? sourceURL.path
      : sourceURL.absoluteString;
  NSString* fragment = [self stableViewerFragmentForURLString:urlString];

  return [sourceDisplayString stringByAppendingString:fragment ?: @""];
}

- (void)showMainWindow {
  [self restoreSessionWindowZoom];
  [self layoutInterfaceForCurrentSplitViewSize];
  [self restoreSessionSidebarAfterInitialLayout];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                        identifier:(NSString*)identifier
                             title:(NSString*)title {
  BabelBrowserTab* tab = [[BabelBrowserTab alloc] init];
  tab.identifier = identifier ?: NSUUID.UUID.UUIDString;
  tab.urlString = urlString;
  tab.requestedURLString = urlString;
  tab.title = title ?: urlString;
  tab.hostView = [[BabelPageContainerView alloc] initWithFrame:pagesPanel_.bounds];
  __weak BabelBrowserWindowController* weakSelf = self;
  tab.hostView.canAcceptLocalDrop = ^BOOL(BabelPageContainerView* container) {
    return [weakSelf pageContainerSupportsLocalDrop:container];
  };
  tab.hostView.localDropHandler = ^(BabelPageContainerView* container) {
    [weakSelf pageContainerDidReceiveLocalDrop:container];
  };
  tab.hostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.hostView.hidden = YES;

  tab.developerToolsPanelView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsPanelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = YES;
  tab.developerToolsPanelView.wantsLayer = YES;
  tab.developerToolsPanelView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsPanelView];

  tab.developerToolsToolbarView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsToolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tab.developerToolsToolbarView.wantsLayer = YES;
  tab.developerToolsToolbarView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.toolbar.background"
                                         view:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView];

  tab.developerToolsResizeHandleView =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsResizeHandleView.resizeTarget = self;
  tab.developerToolsResizeHandleView.resizeAction = @selector(resizeDeveloperToolsFromHandle:);
  tab.developerToolsResizeHandleView.wantsLayer = YES;
  tab.developerToolsResizeHandleView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.handle.background"
                                         view:tab.developerToolsResizeHandleView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView];

  tab.developerToolsHostView = [[BabelBrowserHostView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsHostView.wantsLayer = YES;
  tab.developerToolsHostView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsHostView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView];
  [self addDeveloperToolsControlsToTab:tab];
  tab.developerToolsVisible = NO;

  tab.tabItemView = [[BabelTabItemView alloc] initWithIdentifier:tab.identifier
                                                          title:[self compactTitleForString:tab.title]];
  tab.tabItemView.faviconImage = [self faviconImageForURLString:tab.urlString];
  tab.tabItemView.target = self;
  tab.tabItemView.action = @selector(selectTabFromItem:);
  tab.tabItemView.closeTarget = self;
  tab.tabItemView.closeAction = @selector(closeTabFromItem:);
  tab.tabItemView.dragTarget = self;
  tab.tabItemView.dragAction = @selector(dragTabFromItem:);
  tab.tabItemView.dragEndTarget = self;
  tab.tabItemView.dragEndAction = @selector(finishDraggingTabFromItem:);
  return tab;
}

- (void)addDeveloperToolsControlsToTab:(BabelBrowserTab*)tab {
  NSArray<NSButton*>* buttons = @[
    [self developerToolsButtonWithImageName:@"devtools-close"
                              fallbackTitle:@"x"
                                toolTip:@"Close Developer Tools"
                                    tag:0
                                 action:@selector(closeDeveloperToolsFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-left"
                              fallbackTitle:@"L"
                                toolTip:@"Dock Developer Tools Left"
                                    tag:kDeveloperToolsDockTagLeft
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-right"
                              fallbackTitle:@"R"
                                toolTip:@"Dock Developer Tools Right"
                                    tag:kDeveloperToolsDockTagRight
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-bottom"
                              fallbackTitle:@"B"
                                toolTip:@"Dock Developer Tools Bottom"
                                    tag:kDeveloperToolsDockTagBottom
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-top"
                              fallbackTitle:@"T"
                                toolTip:@"Dock Developer Tools Top"
                                    tag:kDeveloperToolsDockTagTop
                                 action:@selector(changeDeveloperToolsDockFromButton:)]
  ];

  CGFloat x = 8.0;
  for (NSButton* button in buttons) {
    button.frame = NSMakeRect(x, 4.0, 26.0, 22.0);
    [tab.developerToolsToolbarView addSubview:button];
    x += 30.0;
  }
}

- (NSButton*)developerToolsButtonWithImageName:(NSString*)imageName
                                 fallbackTitle:(NSString*)fallbackTitle
                                       toolTip:(NSString*)toolTip
                                           tag:(NSInteger)tag
                                        action:(SEL)action {
  NSButton* button = BabelButton(fallbackTitle, self, action);
  button.bezelStyle = NSBezelStyleTexturedRounded;
  button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  button.toolTip = toolTip;
  button.tag = tag;
  ConfigureIconButton(button, imageName, fallbackTitle);
  return button;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab {
  return [self createTabForURL:urlString
                       inGroup:group
                     parentTab:parentTab
          respectingUserStrategy:YES];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab
   respectingUserStrategy:(BOOL)respectingUserStrategy {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  tab.parentTabIdentifier = parentTab.identifier;
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:respectingUserStrategy];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab {
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:YES];
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
 respectingUserStrategy:(BOOL)respectingUserStrategy {
  if (!parentTab || ![group.tabs containsObject:parentTab] ||
      (respectingUserStrategy &&
       [[self tabOpeningStrategy] isEqualToString:kTabOpeningStrategyAppend])) {
    [group.tabs addObject:tab];
    return;
  }

  NSUInteger insertionIndex = [self insertionIndexForNewChildOfTab:parentTab inGroup:group];
  [group.tabs insertObject:tab atIndex:MIN(insertionIndex, group.tabs.count)];
}

- (NSUInteger)insertionIndexForNewChildOfTab:(BabelBrowserTab*)parentTab
                                     inGroup:(BabelBrowserGroup*)group {
  NSUInteger parentIndex = [group.tabs indexOfObject:parentTab];
  if (parentIndex == NSNotFound) {
    return group.tabs.count;
  }

  if ([[self tabOpeningStrategy] isEqualToString:kTabOpeningStrategyAfterSelected]) {
    return parentIndex + 1;
  }

  NSUInteger insertionIndex = parentIndex + 1;
  for (NSUInteger index = parentIndex + 1; index < group.tabs.count; index++) {
    BabelBrowserTab* candidate = group.tabs[index];
    if (![self tab:candidate descendsFromTabIdentifier:parentTab.identifier inGroup:group]) {
      break;
    }
    insertionIndex = index + 1;
  }
  return insertionIndex;
}

- (BOOL)tab:(BabelBrowserTab*)tab
    descendsFromTabIdentifier:(NSString*)parentTabIdentifier
      inGroup:(BabelBrowserGroup*)group {
  NSString* currentParentIdentifier = tab.parentTabIdentifier;
  NSMutableSet<NSString*>* seenIdentifiers = [NSMutableSet set];
  while (currentParentIdentifier.length > 0) {
    if ([currentParentIdentifier isEqualToString:parentTabIdentifier]) {
      return YES;
    }

    if ([seenIdentifiers containsObject:currentParentIdentifier]) {
      return NO;
    }
    [seenIdentifiers addObject:currentParentIdentifier];

    BabelBrowserTab* parentTab = [self tabWithIdentifier:currentParentIdentifier inGroup:group];
    currentParentIdentifier = parentTab.parentTabIdentifier;
  }
  return NO;
}

- (NSString*)tabOpeningStrategy {
  NSString* strategy = [NSUserDefaults.standardUserDefaults stringForKey:kTabOpeningStrategyDefaultsKey];
  if ([self isSupportedTabOpeningStrategy:strategy]) {
    return strategy;
  }
  return kTabOpeningStrategyChildCluster;
}

- (BOOL)isSupportedTabOpeningStrategy:(NSString*)strategy {
  return [strategy isEqualToString:kTabOpeningStrategyAppend] ||
         [strategy isEqualToString:kTabOpeningStrategyAfterSelected] ||
         [strategy isEqualToString:kTabOpeningStrategyChildCluster];
}

- (NSString*)addressSuggestionsMode {
  NSString* mode = [NSUserDefaults.standardUserDefaults stringForKey:kAddressSuggestionsModeDefaultsKey];
  if ([self isSupportedAddressSuggestionsMode:mode]) {
    return mode;
  }
  return kAddressSuggestionsModeLocal;
}

- (BOOL)isSupportedAddressSuggestionsMode:(NSString*)mode {
  return [mode isEqualToString:kAddressSuggestionsModeLocal] ||
         [mode isEqualToString:kAddressSuggestionsModeGoogle];
}

- (NSString*)markdownTheme {
  NSString* theme = [NSUserDefaults.standardUserDefaults stringForKey:kMarkdownThemeDefaultsKey];
  if ([self isSupportedMarkdownTheme:theme]) {
    return theme;
  }
  return kMarkdownThemeGitHubLight;
}

- (BOOL)isSupportedMarkdownTheme:(NSString*)theme {
  return [theme isEqualToString:kMarkdownThemeGitHubLight] ||
         [theme isEqualToString:kMarkdownThemeGitHubDark] ||
         [theme isEqualToString:kMarkdownThemeReader] ||
         [theme isEqualToString:kMarkdownThemeCompact];
}

- (BOOL)googleSuggestEnabled {
  return [[self addressSuggestionsMode] isEqualToString:kAddressSuggestionsModeGoogle];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  if (!tab || ![tabs_ containsObject:tab] || [tab browser] || [pendingTabs_ containsObject:tab]) {
    return;
  }

  [pendingTabs_ addObject:tab];
  CefWindowInfo windowInfo;
  NSRect bounds = tab.hostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.hostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings browserSettings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(tab.urlString.UTF8String),
                                browserSettings,
                                nullptr,
                                nullptr);
}

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  NSUInteger generation = ++deferredBrowserCreationGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               kKeyboardTabSelectionBrowserCreationDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != deferredBrowserCreationGeneration_ ||
        self->selectedTab_ != tab ||
        self->isTerminating_) {
      return;
    }

    [self createBrowserForTabIfNeeded:tab];
    [self scheduleAdjacentTabPreloadForSelectedTab];
  });
}

- (void)createInitialRestoredBrowserIfNeeded {
  if (!needsInitialRestoredBrowserCreation_ || isTerminating_ || !selectedTab_) {
    return;
  }

  needsInitialRestoredBrowserCreation_ = NO;
  ++deferredBrowserCreationGeneration_;
  [self createBrowserForTabIfNeeded:selectedTab_];
  [self scheduleAdjacentTabPreloadForSelectedTab];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  if (isTerminating_ || !selectedTab_ || tabs_.count < 2) {
    return;
  }

  NSUInteger generation = ++adjacentTabPreloadGeneration_;
  BabelBrowserTab* anchorTab = selectedTab_;
  NSArray<BabelBrowserTab*>* tabsToPreload = [self adjacentTabsToPreloadAroundTab:anchorTab];
  [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                anchorTab:anchorTab
                               generation:generation
                                    index:0];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  NSUInteger selectedIndex = [tabs_ indexOfObject:tab];
  if (selectedIndex == NSNotFound || tabs_.count < 2) {
    return @[];
  }

  NSMutableArray<BabelBrowserTab*>* tabsToPreload = [NSMutableArray array];
  if (selectedIndex > 0) {
    [tabsToPreload addObject:tabs_[selectedIndex - 1]];
  }

  if (selectedIndex + 1 < tabs_.count) {
    BabelBrowserTab* nextTab = tabs_[selectedIndex + 1];
    if (![tabsToPreload containsObject:nextTab]) {
      [tabsToPreload addObject:nextTab];
    }
  }

  return tabsToPreload;
}

- (void)scheduleAdjacentTabPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabsToPreload
                                anchorTab:(BabelBrowserTab*)anchorTab
                               generation:(NSUInteger)generation
                                    index:(NSUInteger)index {
  if (index >= tabsToPreload.count) {
    return;
  }

  int64_t delay = index == 0
      ? kAdjacentTabPreloadInitialDelayNanoseconds
      : kAdjacentTabPreloadStepDelayNanoseconds;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
    if (generation != self->adjacentTabPreloadGeneration_ ||
        self->selectedTab_ != anchorTab ||
        self->isTerminating_) {
      return;
    }

    BabelBrowserTab* tabToPreload = tabsToPreload[index];
    [self createBrowserForTabIfNeeded:tabToPreload];
    [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                  anchorTab:anchorTab
                                 generation:generation
                                      index:index + 1];
  });
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  if (tab.identifier.length == 0) {
    return;
  }

  [recentlyUsedTabIdentifiers_ removeObject:tab.identifier];
  [recentlyUsedTabIdentifiers_ addObject:tab.identifier];
}

- (NSMutableSet<NSString*>*)protectedLiveBrowserTabIdentifiers {
  NSMutableSet<NSString*>* protectedIdentifiers = [NSMutableSet set];
  if (selectedTab_.identifier.length > 0) {
    [protectedIdentifiers addObject:selectedTab_.identifier];
  }

  for (BabelBrowserTab* tab in [self adjacentTabsToPreloadAroundTab:selectedTab_]) {
    if (tab.identifier.length > 0) {
      [protectedIdentifiers addObject:tab.identifier];
    }
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab.developerToolsVisible && tab.identifier.length > 0) {
        [protectedIdentifiers addObject:tab.identifier];
      }
    }
  }

  return protectedIdentifiers;
}

- (NSArray<BabelBrowserTab*>*)livePageBrowserTabsExcludingEvictions {
  NSMutableArray<BabelBrowserTab*>* liveTabs = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] &&
          ![evictingBrowserTabIdentifiers_ containsObject:tab.identifier ?: @""]) {
        [liveTabs addObject:tab];
      }
    }
  }
  return liveTabs;
}

- (BabelBrowserTab*)leastRecentlyUsedEvictableTabFromTabs:(NSArray<BabelBrowserTab*>*)liveTabs
                                     protectedIdentifiers:(NSSet<NSString*>*)protectedIdentifiers {
  for (BabelBrowserTab* tab in liveTabs) {
    if (![recentlyUsedTabIdentifiers_ containsObject:tab.identifier ?: @""] &&
        ![protectedIdentifiers containsObject:tab.identifier ?: @""]) {
      return tab;
    }
  }

  for (NSString* tabIdentifier in recentlyUsedTabIdentifiers_) {
    if ([protectedIdentifiers containsObject:tabIdentifier]) {
      continue;
    }

    for (BabelBrowserTab* tab in liveTabs) {
      if ([tab.identifier isEqualToString:tabIdentifier]) {
        return tab;
      }
    }
  }

  return nil;
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  CefRefPtr<CefBrowser> browser = [tab browser];
  if (!browser || tab.identifier.length == 0) {
    return;
  }

  [evictingBrowserTabIdentifiers_ addObject:tab.identifier];
  browser->GetHost()->CloseDevTools();
  browser->GetHost()->CloseBrowser(true);
}

- (void)enforceLivePageBrowserLimit {
  if (isTerminating_) {
    return;
  }

  NSMutableSet<NSString*>* protectedIdentifiers = [self protectedLiveBrowserTabIdentifiers];
  while (YES) {
    NSArray<BabelBrowserTab*>* liveTabs = [self livePageBrowserTabsExcludingEvictions];
    if (liveTabs.count <= kMaximumLivePageBrowsers) {
      return;
    }

    BabelBrowserTab* tabToEvict =
        [self leastRecentlyUsedEvictableTabFromTabs:liveTabs
                               protectedIdentifiers:protectedIdentifiers];
    if (!tabToEvict) {
      return;
    }

    [self closeBrowserForTabKeepingNativeTab:tabToEvict];
  }
}

- (void)selectTabFromItem:(BabelTabItemView*)tabItemView {
  for (BabelBrowserTab* tab in tabs_) {
    if ([tab.identifier isEqualToString:tabItemView.identifier]) {
      [self selectTab:tab];
      return;
    }
  }
}

- (void)dragTabFromItem:(BabelTabItemView*)tabItemView {
  if (!draggingTab_) {
    draggingTab_ = [self tabWithIdentifier:tabItemView.identifier];
  }

  BabelBrowserTab* tab = draggingTab_;
  if (!tab) {
    return;
  }

  NSEvent* currentEvent = NSApp.currentEvent;
  [self scheduleGroupSelectionForDraggingTabAtWindowPoint:currentEvent.locationInWindow];

  if ([self moveDraggingTabIfNeededToVisibleTabStripAtWindowPoint:currentEvent.locationInWindow]) {
    return;
  }

  if (![self isWindowPointInsideTabStrip:currentEvent.locationInWindow]) {
    return;
  }

  if (![tabs_ containsObject:tab]) {
    return;
  }

  NSUInteger currentIndex = [tabs_ indexOfObject:tab];
  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self tabInsertionIndexForTabStripX:tabStripPoint.x];
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  targetIndex = MIN(targetIndex, tabs_.count - 1);
  if (targetIndex == currentIndex) {
    return;
  }

  isReorderingTabs_ = YES;
  [tabs_ removeObjectAtIndex:currentIndex];
  [tabs_ insertObject:tab atIndex:targetIndex];
  [self layoutTabItemsSelectingLastTab:NO];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier {
  for (BabelBrowserGroup* group in groups_) {
    BabelBrowserTab* tab = [self tabWithIdentifier:identifier inGroup:group];
    if (tab) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if ([group.tabs containsObject:tab]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupAtWindowPoint:(NSPoint)windowPoint {
  NSPoint listPoint = [groupsListView_ convertPoint:windowPoint fromView:nil];
  if (!NSPointInRect(listPoint, groupsListView_.bounds)) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if (NSPointInRect(listPoint, group.groupItemView.frame)) {
      return group;
    }
  }
  return nil;
}

- (BOOL)isWindowPointInsideSidebar:(NSPoint)windowPoint {
  NSPoint sidebarPoint = [sidebarView_ convertPoint:windowPoint fromView:nil];
  return NSPointInRect(sidebarPoint, sidebarView_.bounds);
}

- (BOOL)isWindowPointInsideTabStrip:(NSPoint)windowPoint {
  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:windowPoint fromView:nil];
  return NSPointInRect(tabStripPoint, tabsItemsPanel_.bounds);
}

- (void)scheduleGroupSelectionForDraggingTabAtWindowPoint:(NSPoint)windowPoint {
  BabelBrowserGroup* group = [self groupAtWindowPoint:windowPoint];
  if (!group || group == selectedGroup_) {
    pendingTabDragHoverGroup_ = nil;
    tabDragHoverGeneration_++;
    return;
  }

  if (pendingTabDragHoverGroup_ == group) {
    return;
  }

  pendingTabDragHoverGroup_ = group;
  NSUInteger generation = ++tabDragHoverGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kTabDragGroupHoverDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != self->tabDragHoverGeneration_ ||
        !self->draggingTab_ ||
        self->pendingTabDragHoverGroup_ != group) {
      return;
    }

    NSPoint currentWindowPoint = [self.window convertPointFromScreen:NSEvent.mouseLocation];
    if ([self groupAtWindowPoint:currentWindowPoint] != group) {
      return;
    }

    [self selectGroup:group];
  });
}

- (BOOL)moveDraggingTabIfNeededToVisibleTabStripAtWindowPoint:(NSPoint)windowPoint {
  if (!draggingTab_ || ![self isWindowPointInsideTabStrip:windowPoint]) {
    return NO;
  }

  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  BabelBrowserGroup* destinationGroup = selectedGroup_;
  if (!sourceGroup || !destinationGroup || sourceGroup == destinationGroup) {
    return NO;
  }

  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:windowPoint fromView:nil];
  NSUInteger targetIndex = [self tabInsertionIndexForTabStripX:tabStripPoint.x];
  [self moveDraggingTabToGroup:destinationGroup insertionIndex:targetIndex selectMovedTab:YES];
  return YES;
}

- (void)moveDraggingTabToGroup:(BabelBrowserGroup*)destinationGroup
                insertionIndex:(NSUInteger)insertionIndex
                  selectMovedTab:(BOOL)selectMovedTab {
  if (!draggingTab_ || !destinationGroup) {
    return;
  }

  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  if (!sourceGroup) {
    return;
  }

  if (sourceGroup == destinationGroup) {
    NSUInteger currentIndex = [destinationGroup.tabs indexOfObject:draggingTab_];
    if (currentIndex == NSNotFound) {
      return;
    }
    NSUInteger targetIndex = MIN(insertionIndex, destinationGroup.tabs.count);
    if (targetIndex > currentIndex) {
      targetIndex--;
    }
    if (targetIndex == currentIndex) {
      return;
    }
    [destinationGroup.tabs removeObjectAtIndex:currentIndex];
    targetIndex = MIN(targetIndex, destinationGroup.tabs.count);
    [destinationGroup.tabs insertObject:draggingTab_ atIndex:targetIndex];
    isReorderingTabs_ = YES;
    [self layoutTabItemsSelectingLastTab:NO];
    return;
  }

  [sourceGroup.tabs removeObject:draggingTab_];
  if ([sourceGroup.selectedTabIdentifier isEqualToString:draggingTab_.identifier]) {
    sourceGroup.selectedTabIdentifier = sourceGroup.tabs.lastObject.identifier ?: @"";
  }

  NSUInteger targetIndex = MIN(insertionIndex, destinationGroup.tabs.count);
  [destinationGroup.tabs insertObject:draggingTab_ atIndex:targetIndex];
  destinationGroup.selectedTabIdentifier = draggingTab_.identifier;
  isReorderingTabs_ = YES;
  isDraggingTabAcrossGroups_ = YES;

  [self selectGroup:destinationGroup];
  if (selectMovedTab) {
    [self selectTab:draggingTab_];
  } else {
    [self layoutTabItemsSelectingLastTab:NO];
  }
}

- (NSUInteger)tabInsertionIndexForTabStripX:(CGFloat)x {
  if (tabs_.count == 0) {
    return 0;
  }

  for (NSUInteger index = 0; index < tabs_.count; index++) {
    BabelBrowserTab* tab = tabs_[index];
    if (x < NSMidX(tab.tabItemView.frame)) {
      return index;
    }
  }
  return tabs_.count;
}

- (void)finishDraggingTabFromItem:(BabelTabItemView*)tabItemView {
  NSEvent* currentEvent = NSApp.currentEvent;
  BabelBrowserGroup* dropGroup = [self groupAtWindowPoint:currentEvent.locationInWindow];
  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  if (draggingTab_ && dropGroup && dropGroup != sourceGroup) {
    [self moveDraggingTabToGroup:dropGroup
                  insertionIndex:dropGroup.tabs.count
                    selectMovedTab:YES];
  } else if (draggingTab_ && !dropGroup &&
             [self isWindowPointInsideSidebar:currentEvent.locationInWindow]) {
    NSString* groupName = [self nextManualGroupName];
    BabelBrowserGroup* group = [self createGroupWithName:groupName
                                              identifier:NSUUID.UUID.UUIDString];
    [self moveDraggingTabToGroup:group insertionIndex:0 selectMovedTab:YES];
  }

  pendingTabDragHoverGroup_ = nil;
  tabDragHoverGeneration_++;

  if (!isReorderingTabs_ && !isDraggingTabAcrossGroups_) {
    if (draggingTab_ && ![tabs_ containsObject:draggingTab_]) {
      [draggingTab_.tabItemView removeFromSuperview];
    }
    draggingTab_ = nil;
    [self layoutTabItemsSelectingLastTab:NO];
    return;
  }

  isReorderingTabs_ = NO;
  isDraggingTabAcrossGroups_ = NO;
  draggingTab_ = nil;
  [self layoutTabItemsSelectingLastTab:NO];
  [self saveGroupsState];
}

- (void)closeTabFromItem:(BabelTabItemView*)tabItemView {
  for (BabelBrowserTab* tab in [tabs_ copy]) {
    if (![tab.identifier isEqualToString:tabItemView.identifier]) {
      continue;
    }

    [self pushClosedTab:tab fromGroup:selectedGroup_];

    if (selectedGroup_.tabs.count <= 1) {
      if ([tab browser]) {
        [tab browser]->GetHost()->CloseDevTools();
      }
      [self hideDeveloperToolsForTab:tab];
      [self resetTabToDefaultPage:tab];
      return;
    }

    if ([tab browser]) {
      CefRefPtr<CefBrowser> browser = [tab browser];
      browser->GetHost()->CloseDevTools();
      [self removeSelectedGroupTab:tab];
      browser->GetHost()->CloseBrowser(true);
      return;
    }

    [self removeSelectedGroupTab:tab];
    return;
  }
}

- (void)pushClosedTab:(BabelBrowserTab*)tab fromGroup:(BabelBrowserGroup*)group {
  if (!tab || tab.urlString.length == 0 || !group) {
    return;
  }

  BabelClosedTab* closedTab = [[BabelClosedTab alloc] init];
  closedTab.urlString = tab.urlString;
  closedTab.requestedURLString = tab.requestedURLString ?: tab.urlString;
  closedTab.title = tab.title ?: tab.urlString;
  closedTab.groupIdentifier = group.identifier;
  closedTab.groupName = group.name ?: kDefaultGroupName;
  [closedTabs_ addObject:closedTab];
}

- (void)reopenLastClosedTab {
  if (closedTabs_.count == 0) {
    return;
  }

  [self reopenClosedTabAtIndex:closedTabs_.count - 1];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  if (closedTabIndex >= closedTabs_.count) {
    return;
  }

  BabelClosedTab* closedTab = closedTabs_[closedTabIndex];
  [closedTabs_ removeObjectAtIndex:closedTabIndex];

  BabelBrowserGroup* group = [self groupWithIdentifier:closedTab.groupIdentifier];
  if (!group) {
    NSString* groupName = closedTab.groupName.length > 0 ? closedTab.groupName : kDefaultGroupName;
    NSString* groupIdentifier = closedTab.groupIdentifier.length > 0
        ? closedTab.groupIdentifier
        : NSUUID.UUID.UUIDString;
    group = [self createGroupWithName:groupName identifier:groupIdentifier];
  }

  NSString* requestedURLString = closedTab.requestedURLString ?: closedTab.urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString] ?:
      closedTab.urlString;
  BabelBrowserTab* tab = [self makeTabForURL:navigationURLString
                                  identifier:nil
                                       title:closedTab.title ?: closedTab.urlString];
  tab.requestedURLString = requestedURLString;
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  NSString* defaultURLString = BabelChromeConfiguration.defaultURLString;
  tab.urlString = defaultURLString;
  tab.requestedURLString = defaultURLString;
  tab.title = defaultURLString;
  tab.tabItemView.title = [self compactTitleForString:defaultURLString];
  [self selectTab:tab];

  if ([tab browser]) {
    [tab browser]->GetMainFrame()->LoadURL(std::string(defaultURLString.UTF8String));
  }

  [self saveGroupsState];
}

- (void)selectNextTab {
  [self selectTabWithOffset:1];
}

- (void)selectPreviousTab {
  [self selectTabWithOffset:-1];
}

- (void)openURLStringInNewTab:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([self isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
  [self showMainWindow];
}

- (void)openURLStringInNewTab:(NSString*)urlString openerBrowser:(CefRefPtr<CefBrowser>)browser {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserTab* parentTab = [self tabForBrowser:browser];
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  if (parentTab) {
    for (BabelBrowserGroup* candidateGroup in groups_) {
      if ([candidateGroup.tabs containsObject:parentTab]) {
        group = candidateGroup;
        break;
      }
    }
  }

  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([self isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group parentTab:parentTab];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
  [self showMainWindow];
}

- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths {
  [self appendLocalDropLogLine:[NSString stringWithFormat:@"CEF drag enter paths=%@", paths ?: @[]]];
  if (!browser || paths.count == 0) {
    return;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  BOOL browserURLSupportsDrop = [self URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  if (!tab && selectedTab_ && [self tabSupportsLocalDropPaths:selectedTab_]) {
    tab = selectedTab_;
    [self appendLocalDropLogLine:[NSString stringWithFormat:
        @"CEF drag enter used selected tab fallback requestedURL=%@",
        tab.requestedURLString ?: tab.urlString ?: @""]];
  }
  if ((!tab || ![self tabSupportsLocalDropPaths:tab]) && !browserURLSupportsDrop) {
    [self appendLocalDropLogLine:@"CEF drag enter ignored because no drop-aware tab was found."];
    return;
  }

  [self markPendingLocalDropForBrowser:browser];

  NSMutableArray<NSString*>* cleanPaths = [NSMutableArray array];
  NSMutableArray<NSString*>* files = [NSMutableArray array];
  NSMutableArray<NSString*>* folders = [NSMutableArray array];
  NSFileManager* fileManager = NSFileManager.defaultManager;
  for (NSString* path in paths) {
    if (![path isKindOfClass:NSString.class] || path.length == 0) {
      continue;
    }

    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
      continue;
    }

    [cleanPaths addObject:path];
    if (isDirectory) {
      [folders addObject:path];
    } else {
      [files addObject:path];
    }
  }

  if (cleanPaths.count == 0) {
    return;
  }

  NSDictionary* payload = @{
    @"paths" : cleanPaths,
    @"files" : files,
    @"folders" : folders,
    @"source" : @"native"
  };
  NSData* payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  if (!payloadData) {
    return;
  }

  NSString* payloadJSON = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];
  if (payloadJSON.length == 0) {
    return;
  }

  [self installLocalDropBridgeForBrowser:browser payloadJSON:payloadJSON];
}

- (BOOL)pageContainerSupportsLocalDrop:(BabelPageContainerView*)container {
  if (!container) {
    return NO;
  }

  for (BabelBrowserTab* tab in tabs_) {
    if (tab.hostView == container) {
      BOOL supported = [self tabSupportsLocalDropPaths:tab];
      [self appendLocalDropLogLine:[NSString stringWithFormat:
          @"AppKit drag probe tab=%@ requestedURL=%@ supported=%@",
          tab.identifier ?: @"",
          tab.requestedURLString ?: tab.urlString ?: @"",
          supported ? @"YES" : @"NO"]];
      return supported;
    }
  }

  [self appendLocalDropLogLine:@"AppKit drag probe had no matching tab."];
  return NO;
}

- (void)pageContainerDidReceiveLocalDrop:(BabelPageContainerView*)container {
  NSArray<NSString*>* paths = [container localDropPaths];
  [self appendLocalDropLogLine:[NSString stringWithFormat:@"AppKit drop accepted paths=%@", paths ?: @[]]];
  [self browser:[container browser] didReceiveLocalDragPaths:paths];
}

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![self tabSupportsLocalDropPaths:tab]) {
    if (tab) {
      [self appendLocalDropLogLine:[NSString stringWithFormat:
          @"Load end did not install local drop bridge for requestedURL=%@",
          tab.requestedURLString ?: tab.urlString ?: @""]];
    }
    return;
  }

  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"Load end installing local drop bridge for requestedURL=%@",
      tab.requestedURLString ?: tab.urlString ?: @""]];
  [self installLocalDropBridgeForBrowser:browser payloadJSON:nil];
}

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return NO;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  BOOL tabSupportsDrop = tab && [self tabSupportsLocalDropPaths:tab];
  BOOL browserHasPendingDrop = [self hasPendingLocalDropForBrowser:browser];
  BOOL selectedTabSupportsDrop = selectedTab_ && [self tabSupportsLocalDropPaths:selectedTab_];
  BOOL currentURLSupportsDrop = [self URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  BOOL shouldSuppress = tabSupportsDrop || browserHasPendingDrop || selectedTabSupportsDrop || currentURLSupportsDrop;
  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"CEF file navigation suppression requestedURL=%@ tabSupports=%@ pendingDrop=%@ selectedSupports=%@ currentSupports=%@ suppress=%@",
      tab.requestedURLString ?: tab.urlString ?: @"",
      tabSupportsDrop ? @"YES" : @"NO",
      browserHasPendingDrop ? @"YES" : @"NO",
      selectedTabSupportsDrop ? @"YES" : @"NO",
      currentURLSupportsDrop ? @"YES" : @"NO",
      shouldSuppress ? @"YES" : @"NO"]];
  if (shouldSuppress) {
    [self clearPendingLocalDropForBrowser:browser];
  }
  return shouldSuppress;
}

- (void)installLocalDropBridgeForBrowser:(CefRefPtr<CefBrowser>)browser payloadJSON:(NSString*)payloadJSON {
  if (!browser) {
    return;
  }

  NSString* payloadAssignment = payloadJSON.length > 0
      ? [NSString stringWithFormat:@"window.__babelChromeLocalDropPayload=%@;", payloadJSON]
      : @"";
  NSString* script = [NSString stringWithFormat:
      @"(function(){"
       "%@"
       "if(!window.__babelChromeLocalDropBridgeInstalled){"
       "window.__babelChromeLocalDropBridgeInstalled=true;"
       "var hasLocalFiles=function(event){"
       "if(window.__babelChromeLocalDropPayload){return true;}"
       "var transfer=event.dataTransfer;"
       "if(!transfer){return false;}"
       "if(transfer.types&&Array.prototype.indexOf.call(transfer.types,'Files')>=0){return true;}"
       "return transfer.files&&transfer.files.length>0;"
       "};"
       "window.addEventListener('dragover',function(event){"
       "if(!hasLocalFiles(event)){return;}"
       "event.preventDefault();"
       "event.stopPropagation();"
       "},true);"
       "window.addEventListener('drop',function(event){"
       "if(!hasLocalFiles(event)){return;}"
       "event.preventDefault();"
       "event.stopPropagation();"
       "var detail=window.__babelChromeLocalDropPayload;"
       "if(!detail){return;}"
       "window.dispatchEvent(new CustomEvent('babelchrome:local-drop',{detail:detail}));"
       "window.__babelChromeLocalDropPayload=null;"
       "},true);"
       "}"
       "})();",
      payloadAssignment];

  browser->GetMainFrame()->ExecuteJavaScript(std::string(script.UTF8String),
                                             "babelchrome://local-drop-bridge",
                                             0);
}

- (void)appendLocalDropLogLine:(NSString*)line {
  NSURL* logURL = [BabelChromeConfiguration.applicationSupportDirectoryURL
      URLByAppendingPathComponent:@"local-drop.log"
                      isDirectory:NO];
  [NSFileManager.defaultManager createDirectoryAtURL:logURL.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  if (![NSFileManager.defaultManager fileExistsAtPath:logURL.path]) {
    [NSFileManager.defaultManager createFileAtPath:logURL.path contents:nil attributes:nil];
  }

  NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:logURL.path];
  if (!fileHandle) {
    NSLog(@"BabelChrome local drop: %@", line ?: @"");
    return;
  }

  NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
  NSString* timestamp = [formatter stringFromDate:NSDate.date];
  NSString* entry = [NSString stringWithFormat:@"%@ %@\n", timestamp, line ?: @""];
  [fileHandle seekToEndOfFile];
  [fileHandle writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
  [fileHandle closeFile];
}

- (NSNumber*)browserIdentifierForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return nil;
  }

  return @(browser->GetIdentifier());
}

- (NSString*)currentURLStringForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser || !browser->GetMainFrame()) {
    return @"";
  }

  return [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];
}

- (void)markPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return;
  }

  pendingLocalDropBrowserIdentifiers_[browserIdentifier] = NSDate.date;
  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"Marked pending local drop for browser=%@",
      browserIdentifier]];
}

- (BOOL)hasPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return NO;
  }

  NSDate* createdAt = pendingLocalDropBrowserIdentifiers_[browserIdentifier];
  if (!createdAt) {
    return NO;
  }

  if ([NSDate.date timeIntervalSinceDate:createdAt] > 10.0) {
    [pendingLocalDropBrowserIdentifiers_ removeObjectForKey:browserIdentifier];
    return NO;
  }

  return YES;
}

- (void)clearPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (browserIdentifier) {
    [pendingLocalDropBrowserIdentifiers_ removeObjectForKey:browserIdentifier];
  }
}

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab {
  if (!tab) {
    return NO;
  }

  if ([self URLStringSupportsLocalDropPaths:tab.requestedURLString]) {
    return YES;
  }

  return [self URLStringSupportsLocalDropPaths:tab.urlString];
}

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString {
  if (urlString.length == 0) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (!components) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (!snapshot || error) {
    return NO;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme.lowercaseString ?: @"";
  NSString* host = components.host.lowercaseString ?: @"";
  NSString* localModuleIdentifier = [self localServiceModuleIdentifierForURLComponents:components];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSArray* hooks = [module[@"hooks"] isKindOfClass:NSArray.class] ? module[@"hooks"] : @[];
    if (![hooks containsObject:@"drop.local-paths"]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (localModuleIdentifier.length > 0 && [moduleIdentifier isEqualToString:localModuleIdentifier]) {
      return YES;
    }

    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      if ([routeScheme.lowercaseString isEqualToString:scheme] && [routeHost.lowercaseString isEqualToString:host]) {
        return YES;
      }
    }
  }

  return NO;
}

- (NSString*)localServiceModuleIdentifierForURLComponents:(NSURLComponents*)components {
  NSString* scheme = components.scheme.lowercaseString ?: @"";
  NSString* host = components.host.lowercaseString ?: @"";
  if ((![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) ||
      ![host isEqualToString:@"127.0.0.1"]) {
    return nil;
  }

  NSArray<NSString*>* pathComponents = [components.path pathComponents];
  if (pathComponents.count < 3 || ![pathComponents[1] isEqualToString:@"module"]) {
    return nil;
  }

  return pathComponents[2];
}

- (NSString*)defaultGroupNameForModuleIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return nil;
  }

  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (!snapshot || error) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* identifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (![identifier isEqualToString:moduleIdentifier]) {
      continue;
    }

    NSString* defaultGroup = [module[@"defaultGroup"] isKindOfClass:NSString.class]
        ? [module[@"defaultGroup"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    return defaultGroup.length > 0 ? defaultGroup : nil;
  }

  return nil;
}

- (BabelBrowserGroup*)targetGroupForModuleIdentifier:(NSString*)moduleIdentifier
                                      fallbackGroup:(BabelBrowserGroup*)fallbackGroup {
  NSString* defaultGroupName = [self defaultGroupNameForModuleIdentifier:moduleIdentifier];
  if (defaultGroupName.length > 0) {
    return [self ensureGroupNamed:defaultGroupName];
  }

  return fallbackGroup ?: [self ensureGroupNamed:kDefaultGroupName];
}

- (void)openHistoryPage {
  [self openInternalPageWithURLString:kHistoryPageURLString
                                title:@"History"
                                 html:[self historyPageHTML]];
}

- (void)openSettingsPage {
  [self openSettingsPageForBrowser:nullptr];
}

- (void)openSettingsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kSettingsPageURLString
                                title:@"Settings"
                                 html:[self settingsPageHTML]
                              browser:browser];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier {
  [self openModuleSettingsPageForIdentifier:moduleIdentifier browser:nullptr];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier browser:(CefRefPtr<CefBrowser>)browser {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  NSString* urlString = [NSString stringWithFormat:@"babelchrome://settings/%@",
                                                   [self pathEscapedString:normalizedIdentifier]];
  [self openInternalPageWithURLString:urlString
                                title:@"Module Settings"
                                 html:[self moduleSettingsPageHTMLForIdentifier:normalizedIdentifier]
                              browser:browser];
}

- (void)openExtensionsPage {
  [self openExtensionsPageForBrowser:nullptr];
}

- (void)openExtensionsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kExtensionsPageURLString
                                title:@"Extensions"
                                 html:[self extensionsPageHTML]
                              browser:browser];
}

- (void)openModulesPage {
  [self openModulesPageForBrowser:nullptr];
}

- (void)openModulesPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kModulesPageURLString
                                title:@"Modules"
                                 html:[self modulesPageHTML]
                              browser:browser];
}

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier route:(NSString*)route {
  [self openPHPModuleWithIdentifier:moduleIdentifier
                              route:route
                    sourceURLString:nil
                 requestedURLString:[NSString stringWithFormat:@"babelchrome://modules/%@/%@",
                                                               moduleIdentifier ?: @"",
                                                               route.length > 0 ? route : @"index"]];
}

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier
                              route:(NSString*)route
                    sourceURLString:(NSString*)sourceURLString
                 requestedURLString:(NSString*)requestedURLString {
  NSError* error = nil;
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                                       route:route
                                                             sourceURLString:sourceURLString
                                                                       error:&error];
  if (!moduleURL) {
    [self showModuleActionAlertWithError:error];
    return;
  }

  BabelBrowserGroup* group = [self targetGroupForModuleIdentifier:moduleIdentifier
                                                    fallbackGroup:selectedGroup_];
  [self selectGroup:group];
  BabelBrowserTab* tab = [self createTabForURL:moduleURL.absoluteString
                                       inGroup:group
                                     parentTab:selectedTab_];
  tab.requestedURLString = requestedURLString.length > 0 ? requestedURLString : moduleURL.absoluteString;
  [self saveGroupsState];
  [self showMainWindow];
}

- (BOOL)openPHPModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* moduleRoute = [self moduleRouteForBabelChromeComponents:components error:&error];
  if (!moduleRoute) {
    if (error) {
      [self showModuleActionAlertWithError:error];
    }
    return NO;
  }

  NSString* moduleIdentifier =
      [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
  NSString* route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
  if (moduleIdentifier.length == 0 || route.length == 0) {
    return NO;
  }

  [self openPHPModuleWithIdentifier:moduleIdentifier
                              route:route
                    sourceURLString:urlString
                 requestedURLString:urlString];
  return YES;
}

- (void)importProjectLauncherJSONFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Load Project Launcher JSON";
  if ([panel runModal] != NSModalResponseOK) {
    [self appendLocalDropLogLine:@"Project Launcher JSON panel cancelled."];
    return;
  }

  NSString* path = panel.URL.path ?: @"";
  if (![path.pathExtension.lowercaseString isEqualToString:@"json"]) {
    [self appendLocalDropLogLine:[NSString stringWithFormat:@"Project Launcher JSON panel rejected path=%@", path]];
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Invalid Project Configuration";
    alert.informativeText = @"Please select a JSON project configuration file.";
    [alert runModal];
    return;
  }

  [self appendLocalDropLogLine:[NSString stringWithFormat:@"Project Launcher JSON panel selected path=%@", path]];
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:@"babelforge.project-launcher"
                                                                       route:@"index"
                                                             sourceURLString:nil
                                                                       error:nil];
  if (!moduleURL || path.length == 0) {
    [self appendLocalDropLogLine:@"Project Launcher JSON panel could not build module URL."];
    return;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:moduleURL resolvingAgainstBaseURL:NO];
  NSMutableArray<NSURLQueryItem*>* queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"action" value:@"importPath"]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"path" value:path]];
  components.queryItems = queryItems;

  BabelBrowserGroup* group = [self targetGroupForModuleIdentifier:@"babelforge.project-launcher"
                                                    fallbackGroup:selectedGroup_];
  [self selectGroup:group];
  BabelBrowserTab* tab = [self createTabForURL:components.URL.absoluteString
                                       inGroup:group
                                     parentTab:selectedTab_];
  tab.requestedURLString = @"babelchrome://project-launcher";
  [self saveGroupsState];
  [self showMainWindow];
}

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString {
  return [self handleInternalNavigationURLString:urlString browser:nullptr];
}

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString browser:(CefRefPtr<CefBrowser>)browser {
  if (browser && [self navigateBrowser:browser toInternalURLStringInSameTab:urlString]) {
    return YES;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (![components.scheme isEqualToString:@"babelchrome"]) {
    return NO;
  }

  NSString* commandName = components.host ?: @"";
  if ([commandName isEqualToString:@"settings"]) {
    NSString* moduleSettingsIdentifier = [self moduleSettingsIdentifierFromSettingsComponents:components];
    if (moduleSettingsIdentifier.length > 0) {
      BOOL markdownThemeDidChange = NO;
      for (NSURLQueryItem* item in components.queryItems) {
        if ([item.name isEqualToString:@"markdownTheme"] &&
            [self isSupportedMarkdownTheme:item.value] &&
            [[self normalizedModuleSettingsIdentifier:moduleSettingsIdentifier]
                isEqualToString:@"babelforge.markdown-viewer"]) {
          NSString* previousTheme = [self markdownTheme];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:kMarkdownThemeDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }
      }

      if (markdownThemeDidChange) {
        [self reloadMarkdownViewerTabsUsingCurrentTheme];
      }
      [self openModuleSettingsPageForIdentifier:moduleSettingsIdentifier browser:browser];
      return YES;
    }

    BOOL markdownThemeDidChange = NO;
    BOOL appearanceThemeDidChange = NO;
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"tabOpeningStrategy"] &&
          [self isSupportedTabOpeningStrategy:item.value]) {
        [NSUserDefaults.standardUserDefaults setObject:item.value
                                                forKey:kTabOpeningStrategyDefaultsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        break;
      }

      if (![item.name isEqualToString:@"addressSuggestions"] ||
          ![self isSupportedAddressSuggestionsMode:item.value]) {
        if ([item.name isEqualToString:@"markdownTheme"] &&
            [self isSupportedMarkdownTheme:item.value]) {
          NSString* previousTheme = [self markdownTheme];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:kMarkdownThemeDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }

        if ([item.name isEqualToString:@"appearanceTheme"] &&
            [BabelTheme.sharedTheme isSupportedAppearanceMode:item.value]) {
          NSString* previousTheme = [BabelTheme.sharedTheme appearanceMode];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:BabelThemeAppearanceDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          appearanceThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }
        continue;
      }

      [NSUserDefaults.standardUserDefaults setObject:item.value
                                              forKey:kAddressSuggestionsModeDefaultsKey];
      [NSUserDefaults.standardUserDefaults synchronize];
      break;
    }

    if (markdownThemeDidChange) {
      [self reloadMarkdownViewerTabsUsingCurrentTheme];
    }
    if (appearanceThemeDidChange) {
      [self applyThemeColors];
      [self layoutTabItemsSelectingLastTab:NO];
      [self layoutGroupItems];
    }
    [self openSettingsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"extensions"]) {
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"search"] && item.value.length > 0) {
        [self openChromeWebStoreSearchForQuery:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"addUnpacked"] && item.value.length > 0) {
        [self addUnpackedExtensionFromPanel];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"remove"] && item.value.length > 0) {
        [self removeUnpackedExtensionAtPath:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"disableProfile"] && item.value.length > 0) {
        [self setProfileExtensionWithIdentifier:item.value enabled:NO];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"enableProfile"] && item.value.length > 0) {
        [self setProfileExtensionWithIdentifier:item.value enabled:YES];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"removeProfile"] && item.value.length > 0) {
        [self removeProfileExtensionWithIdentifier:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"restart"] && item.value.length > 0) {
        [self restartApplication];
        return YES;
      }
    }

    [self openExtensionsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"modules"]) {
    BOOL didRequestUpdateInstall = NO;
    NSMutableArray<NSString*>* updateIdentifiers = [NSMutableArray array];
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"installSelectedUpdates"] && item.value.length > 0) {
        didRequestUpdateInstall = YES;
      }
      if ([item.name isEqualToString:@"installUpdates"] && item.value.length > 0) {
        didRequestUpdateInstall = YES;
        [updateIdentifiers addObject:item.value];
      }
    }
    if (didRequestUpdateInstall) {
      [self installPHPModuleUpdatesWithIdentifiers:updateIdentifiers];
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"installZip"] && item.value.length > 0) {
        [self installPHPModuleZipFromPanel];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"configureUpdateURL"] && item.value.length > 0) {
        [self configureModuleUpdateURLFromPrompt];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"configureUpdateLocal"] && item.value.length > 0) {
        [self configureModuleUpdateLocalDirectoryFromPanel];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"checkUpdates"] && item.value.length > 0) {
        [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                      title:@"Module Updates"
                                       html:[self moduleUpdatesPageHTML]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"installUpdate"] && item.value.length > 0) {
        [self installPHPModuleUpdateWithIdentifier:item.value];
        [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                      title:@"Module Updates"
                                       html:[self moduleUpdatesPageHTML]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"enable"] && item.value.length > 0) {
        [self setPHPModuleWithIdentifier:item.value enabled:YES];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"disable"] && item.value.length > 0) {
        [self setPHPModuleWithIdentifier:item.value enabled:NO];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"remove"] && item.value.length > 0) {
        [self removePHPModuleWithIdentifier:item.value];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"module"] && item.value.length > 0) {
        NSString* urlString = [NSString stringWithFormat:@"babelchrome://modules?module=%@",
                                                         [self queryEscapedString:item.value]];
        [self openInternalPageWithURLString:urlString
                                      title:@"Module"
                                       html:[self moduleDetailsPageHTMLForIdentifier:item.value]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"open"] && item.value.length > 0) {
        NSString* route = @"index";
        for (NSURLQueryItem* routeItem in components.queryItems) {
          if ([routeItem.name isEqualToString:@"route"] && routeItem.value.length > 0) {
            route = routeItem.value;
            break;
          }
        }
        [self openPHPModuleWithIdentifier:item.value route:route];
        return YES;
      }
    }

    [self openModulesPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"project-launcher"]) {
    if ([components.path isEqualToString:@"/import-config"]) {
      [self importProjectLauncherJSONFromPanel];
      return YES;
    }
  }

  if ([commandName isEqualToString:@"history"]) {
    for (NSURLQueryItem* item in components.queryItems) {
      if (![item.name isEqualToString:@"reopen"] || item.value.length == 0) {
        continue;
      }

      NSInteger closedTabIndex = item.value.integerValue;
      if (closedTabIndex >= 0) {
        [self reopenClosedTabAtIndex:(NSUInteger)closedTabIndex];
      }
      return YES;
    }

    [self openHistoryPage];
    return YES;
  }

  if ([commandName isEqualToString:@"open"]) {
    NSURL* commandURL = [NSURL URLWithString:urlString];
    if (commandURL) {
      [self openBabelChromeCommandURL:commandURL];
    } else {
      [self openCompactBabelChromeCommandString:urlString];
    }
    return YES;
  }

  if ([self isStableViewerURLString:urlString]) {
    [self navigateSelectedTabToViewerURLString:urlString];
    return YES;
  }

  if ([self openPHPModuleURLString:urlString]) {
    return YES;
  }

  return NO;
}

- (void)navigateSelectedTabToViewerURLString:(NSString*)urlString {
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  if (!selectedTab_) {
    BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
    tab.requestedURLString = requestedURLString;
    [self saveGroupsState];
    return;
  }

  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  } else {
    [self selectTab:selectedTab_];
  }

  [self saveGroupsState];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html {
  [self openInternalPageWithURLString:internalURLString
                                title:title
                                 html:html
                              browser:nullptr];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser {
  if (browser) {
    BabelBrowserTab* targetTab = [self tabForBrowser:browser];
    if (targetTab) {
      NSString* dataURLString = [self dataURLStringForHTML:html];
      targetTab.urlString = dataURLString;
      targetTab.requestedURLString = internalURLString;
      targetTab.title = title;
      targetTab.tabItemView.title = [self compactTitleForString:title];
      browser->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
      [self selectTab:targetTab];
      [self showMainWindow];
      [self saveGroupsState];
      return;
    }
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  BabelBrowserTab* existingTab = [self tabWithURLString:internalURLString inGroup:group];
  NSString* dataURLString = [self dataURLStringForHTML:html];
  if (existingTab) {
    existingTab.urlString = dataURLString;
    existingTab.requestedURLString = internalURLString;
    existingTab.title = title;
    existingTab.tabItemView.title = [self compactTitleForString:title];
    [self selectTab:existingTab];
    if ([existingTab browser]) {
      [existingTab browser]->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
    }
    [self showMainWindow];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [self makeTabForURL:dataURLString identifier:nil title:title];
  tab.requestedURLString = internalURLString;
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (NSString*)dataURLStringForHTML:(NSString*)html {
  NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
  NSString* encodedHTML = [data base64EncodedStringWithOptions:0];
  return [NSString stringWithFormat:@"data:text/html;charset=utf-8;base64,%@", encodedHTML];
}

- (NSString*)historyPageHTML {
  NSMutableString* body = [NSMutableString string];
  [body appendString:@"<h1>History</h1>"];
  [body appendString:@"<h2>Open Tabs</h2><ul>"];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [body appendFormat:@"<li><span>%@</span><small>%@</small><em>%@</em></li>",
                         [self htmlEscapedString:title],
                         [self htmlEscapedString:tab.requestedURLString ?: tab.urlString],
                         [self htmlEscapedString:group.name ?: kDefaultGroupName]];
    }
  }
  [body appendString:@"</ul>"];

  [body appendString:@"<h2>Recently Closed Tabs</h2>"];
  if (closedTabs_.count == 0) {
    [body appendString:@"<p class='empty'>No recently closed tab.</p>"];
  } else {
    [body appendString:@"<ul>"];
    for (NSInteger index = (NSInteger)closedTabs_.count - 1; index >= 0; index--) {
      BabelClosedTab* closedTab = closedTabs_[(NSUInteger)index];
      NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
      [body appendFormat:
          @"<li><span>%@</span><small>%@</small><em>%@</em>"
           "<div class='actions'><a class='smallButton' href='babelchrome://history?reopen=%ld'>Re-open</a></div></li>",
          [self htmlEscapedString:title],
          [self htmlEscapedString:closedTab.requestedURLString ?: closedTab.urlString],
          [self htmlEscapedString:closedTab.groupName ?: kDefaultGroupName],
          (long)index];
    }
    [body appendString:@"</ul>"];
  }
  return [self internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTML {
  NSString* strategy = [self tabOpeningStrategy];
  NSString* addressSuggestionsMode = [self addressSuggestionsMode];
  NSString* appearanceTheme = [BabelTheme.sharedTheme appearanceMode];
  NSString* body = [NSString stringWithFormat:
      @"<h1>Settings</h1>"
       "<section><a class='primaryButton' data-can-open-menu='true' href='babelchrome://extensions'>Extensions</a>"
       " <a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules'>PHP Modules</a></section>"
       "<section>"
       "<h2>General</h2>"
       "<dl>"
       "<dt>Default page</dt><dd>%@</dd>"
       "<dt>Application theme</dt><dd>%@</dd>"
       "<dt>Tab opening strategy</dt><dd>%@</dd>"
       "<dt>Address suggestions</dt><dd>%@</dd>"
       "<dt>Groups file</dt><dd>Stored in the BabelChrome application support folder.</dd>"
       "<dt>Developer Tools docking</dt><dd>The last selected dock mode is saved automatically.</dd>"
       "</dl>"
       "</section>",
      [self htmlEscapedString:BabelChromeConfiguration.defaultURLString],
      [self settingsAppearanceThemeHTML:appearanceTheme],
      [self settingsTabOpeningStrategyHTML:strategy],
      [self settingsAddressSuggestionsHTML:addressSuggestionsMode]];
  return [self internalPageHTMLWithTitle:@"Settings" body:body];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  if ([normalizedIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    NSString* body = [NSString stringWithFormat:
        @"<h1>Markdown Viewer Settings</h1>"
         "<section>"
         "<p class='note'>These settings belong to the Markdown Viewer module, not to BabelChrome itself.</p>"
         "<dl>"
         "<dt>Markdown theme</dt><dd>%@</dd>"
         "</dl>"
         "</section>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self settingsMarkdownThemeHTML:[self markdownTheme] settingsURLString:@"babelchrome://settings/babelforge.markdown-viewer"]];
    return [self internalPageHTMLWithTitle:@"Markdown Viewer Settings" body:body];
  }

  NSString* moduleName = [self moduleNameForIdentifier:normalizedIdentifier] ?: normalizedIdentifier;
  NSString* body = [NSString stringWithFormat:
      @"<h1>%@ Settings</h1>"
       "<section>"
       "<p class='empty'>This module does not expose native BabelChrome settings yet.</p>"
       "</section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName]];
  return [self internalPageHTMLWithTitle:[NSString stringWithFormat:@"%@ Settings", moduleName] body:body];
}

- (NSString*)extensionsPageHTML {
  NSArray<NSString*>* extensionPaths = [self installedExtensionPaths];
  NSArray<NSDictionary*>* profileExtensions = [self profileInstalledExtensions];
  NSMutableString* profileListHTML = [NSMutableString string];
  if (profileExtensions.count == 0) {
    [profileListHTML appendString:@"<p class='empty'>No Chrome profile extension was found.</p>"];
  } else {
    [profileListHTML appendString:@"<ul>"];
    for (NSDictionary* extension in profileExtensions) {
      NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
          ? extension[@"id"]
          : @"";
      BOOL enabled = [extension[@"enabled"] boolValue];
      NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
      NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
      NSString* status = [self profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                 enabled:enabled];
      NSString* restartHTML = [self profileExtensionRequiresRestart:extensionIdentifier]
          ? @"<a class='smallButton primarySmallButton' href='babelchrome://extensions?restart=1'>Restart</a>"
          : @"";
      [profileListHTML appendFormat:
          @"<li><span>%@</span><small>%@ - ID: %@ - Version: %@ - %@</small>"
           "<div class='actions'>%@<a class='smallButton' href='babelchrome://extensions?%@=%@'>%@</a>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?removeProfile=%@' title='Remove'>%@<span>Remove</span></a></div></li>",
          [self htmlEscapedString:extension[@"name"]],
          [self htmlEscapedString:status],
          [self htmlEscapedString:extensionIdentifier],
          [self htmlEscapedString:extension[@"version"]],
          [self htmlEscapedString:extension[@"path"]],
          restartHTML,
          toggleAction,
          [self queryEscapedString:extensionIdentifier],
          toggleLabel,
          [self queryEscapedString:extensionIdentifier],
          [self trashIconHTML]];
    }
    [profileListHTML appendString:@"</ul>"];
  }

  NSMutableString* unpackedListHTML = [NSMutableString string];
  if (extensionPaths.count == 0) {
    [unpackedListHTML appendString:@"<p class='empty'>No unpacked extension is configured.</p>"];
  } else {
    [unpackedListHTML appendString:@"<ul>"];
    for (NSString* extensionPath in extensionPaths) {
      NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
      BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
      NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
      [unpackedListHTML appendFormat:
          @"<li><span>%@</span><small>%@</small><div class='actions'>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?remove=%@' title='Remove'>%@<span>Remove</span></a>"
           "</div></li>",
          [self htmlEscapedString:extensionPath.lastPathComponent],
          [self htmlEscapedString:[NSString stringWithFormat:@"%@ - %@", status, extensionPath]],
          [self queryEscapedString:extensionPath],
          [self trashIconHTML]];
    }
    [unpackedListHTML appendString:@"</ul>"];
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>Extensions</h1>"
       "<section>"
       "<h2>Chrome Web Store</h2>"
       "<form method='get' action='babelchrome://extensions' class='searchForm'>"
       "<input type='search' name='search' placeholder='Search extensions' autofocus>"
       "<button type='submit'>Search</button>"
       "</form>"
       "</section>"
       "<section>"
       "<h2>Chrome Profile Extensions</h2>"
       "<p class='note'>Extensions installed by Chromium in the BabelChrome profile are listed here. Disable and Enable changes are applied on the next BabelChrome restart.</p>"
       "%@"
       "</section>"
       "<section>"
       "<h2>Unpacked Extensions</h2>"
       "<p class='note'>BabelChrome loads configured unpacked extension folders at startup. Changes require restarting BabelChrome.</p>"
       "<p><a class='primaryButton' href='babelchrome://extensions?addUnpacked=1'>Add unpacked extension folder</a></p>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      profileListHTML,
      unpackedListHTML];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}

- (NSString*)modulesPageHTML {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* updateURLString = [self moduleUpdateURLString];
  NSString* updateLocalDirectory = [self moduleUpdateLocalDirectoryPath];
  NSString* updateURLLabel = updateURLString.length > 0 ? updateURLString : @"Not configured";
  NSString* updateLocalLabel = updateLocalDirectory.length > 0 ? updateLocalDirectory : @"Not configured";
  NSMutableString* moduleListHTML = [NSMutableString string];
  if (error) {
    [moduleListHTML appendFormat:@"<p class='empty'>%@</p>",
                                 [self htmlEscapedString:error.localizedDescription]];
  } else if (modules.count == 0) {
    [moduleListHTML appendString:@"<p class='empty'>No PHP module is registered.</p>"];
  } else {
    [moduleListHTML appendString:@"<ul class='stripedList moduleList'>"];
    for (NSDictionary* module in modules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* moduleVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSString* moduleDescription =
          [module[@"description"] isKindOfClass:NSString.class] ? module[@"description"] : @"";
      BOOL enabled = [module[@"enabled"] boolValue];
      BOOL hasIsolatedVendor = [module[@"hasIsolatedVendor"] boolValue];
      NSString* settingsRoute =
          [module[@"settingsRoute"] isKindOfClass:NSString.class] ? module[@"settingsRoute"] : @"";
      BOOL hasSettingsPage = settingsRoute.length > 0 && ![settingsRoute isEqualToString:@"babelchrome://modules"];
      NSString* enabledLabel = enabled ? @"Enabled" : @"Disabled";
      NSString* vendorLabel = hasIsolatedVendor ? @"Bundled vendor" : @"No bundled vendor";
      NSString* versionLabel = [NSString stringWithFormat:@"Installed %@", moduleVersion];
      NSString* detailsActionHTML = @"";
      NSString* settingsActionHTML = @"";
      NSString* toggleActionHTML = @"";
      NSString* removeActionHTML = @"";
      if (moduleIdentifier.length > 0) {
        detailsActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' data-can-open-menu='true' href='babelchrome://modules?module=%@'>Details</a>",
            [self queryEscapedString:moduleIdentifier]];
      }
      if (hasSettingsPage) {
        settingsActionHTML = [NSString stringWithFormat:@"<a class='smallButton' data-can-open-menu='true' href='%@'>Settings</a>",
                                                        [self htmlEscapedString:settingsRoute]];
      }
      if (moduleIdentifier.length > 0) {
        NSString* toggleAction = enabled ? @"disable" : @"enable";
        NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
        toggleActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' href='babelchrome://modules?%@=%@'>%@</a>",
            toggleAction,
            [self queryEscapedString:moduleIdentifier],
            toggleLabel];
        removeActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton dangerButton iconTextButton' href='babelchrome://modules?remove=%@' title='Remove'>%@<span>Remove</span></a>",
            [self queryEscapedString:moduleIdentifier],
            [self trashIconHTML]];
      }

      [moduleListHTML appendFormat:
          @"<li class='moduleItem'>"
           "<div class='moduleText'><span>%@</span><small>%@ - %@ - %@ - %@</small><em>%@</em>"
           "<p class='note'>%@</p></div>"
           "<div class='moduleButtons'>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "</div>"
           "</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:versionLabel],
          @"User-installed",
          [self htmlEscapedString:enabledLabel],
          [self htmlEscapedString:vendorLabel],
          [self htmlEscapedString:moduleDescription],
          detailsActionHTML,
          settingsActionHTML,
          toggleActionHTML,
          removeActionHTML];
    }
    [moduleListHTML appendString:@"</ul>"];
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>PHP Modules</h1>"
       "<section>"
       "<h2>Installed Modules</h2>"
       "<div class='buttonRow'>"
       "<a class='primaryButton' href='babelchrome://modules?installZip=1'>Install or Update Module Zip</a>"
       "<a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules?checkUpdates=1'>Check Updates</a>"
       "<details class='gearMenu'>"
       "<summary title='Update source settings' aria-label='Update source settings'>%@</summary>"
       "<div class='gearMenuPanel'>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateURL=1'>Set Update URL</a>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateLocal=1'>Set Local Update Folder</a>"
       "</div>"
       "</details>"
       "</div>"
       "<dl>"
       "<dt>Update URL</dt><dd>%@</dd>"
       "<dt>Local update folder</dt><dd>%@</dd>"
       "</dl>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      [self resourceSVGIconHTMLNamed:@"settings-gear" fallback:@"&#9881;"],
      [self htmlEscapedString:updateURLLabel],
      [self htmlEscapedString:updateLocalLabel],
      moduleListHTML];
  return [self internalPageHTMLWithTitle:@"Modules" body:body];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSDictionary* selectedModule = nil;
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if ([currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      selectedModule = module;
      break;
    }
  }

  if (error) {
    NSString* body = [NSString stringWithFormat:@"<h1>Module</h1><p class='empty'>%@</p>",
                                                [self htmlEscapedString:error.localizedDescription]];
    return [self internalPageHTMLWithTitle:@"Module" body:body];
  }

  if (!selectedModule) {
    NSString* body = [NSString stringWithFormat:
        @"<h1>Module</h1><p class='empty'>Module <code>%@</code> is not installed.</p>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self htmlEscapedString:moduleIdentifier ?: @""]];
    return [self internalPageHTMLWithTitle:@"Module" body:body];
  }

  NSString* moduleName = [selectedModule[@"name"] isKindOfClass:NSString.class] ? selectedModule[@"name"] : moduleIdentifier;
  NSString* moduleVersion = [selectedModule[@"version"] isKindOfClass:NSString.class] ? selectedModule[@"version"] : @"";
  NSString* moduleType = [selectedModule[@"type"] isKindOfClass:NSString.class] ? selectedModule[@"type"] : @"";
  NSString* moduleDescription =
      [selectedModule[@"description"] isKindOfClass:NSString.class] ? selectedModule[@"description"] : @"";
  BOOL enabled = [selectedModule[@"enabled"] boolValue];
  BOOL hasIsolatedVendor = [selectedModule[@"hasIsolatedVendor"] boolValue];
  NSDictionary* requirements =
      [selectedModule[@"requirements"] isKindOfClass:NSDictionary.class] ? selectedModule[@"requirements"] : @{};
  NSString* phpRequirement =
      [requirements[@"php"] isKindOfClass:NSString.class] ? requirements[@"php"] : @"";
  NSArray* routes = [selectedModule[@"routes"] isKindOfClass:NSArray.class] ? selectedModule[@"routes"] : @[];
  NSArray* fileTypes = [selectedModule[@"fileTypes"] isKindOfClass:NSArray.class] ? selectedModule[@"fileTypes"] : @[];
  NSArray* hooks = [selectedModule[@"hooks"] isKindOfClass:NSArray.class] ? selectedModule[@"hooks"] : @[];

  NSMutableString* routesHTML = [NSMutableString string];
  for (NSDictionary* route in routes) {
    if (![route isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
    NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
    NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
    if (routeScheme.length == 0 || routeHost.length == 0 || routeHandler.length == 0) {
      continue;
    }

    BOOL routeCanOpenDirectly = [routeScheme isEqualToString:@"babelchrome"] &&
        ![routeHost isEqualToString:@"server"];
    NSString* actionHTML = enabled && routeCanOpenDirectly
        ? [NSString stringWithFormat:@"<a class='smallButton' href='babelchrome://modules?open=%@&route=%@'>Open route</a>",
                                     [self queryEscapedString:moduleIdentifier ?: @""],
                                     [self queryEscapedString:routeHandler]]
        : @"";
    [routesHTML appendFormat:
        @"<li><code>%@://%@</code><span>&rarr;</span><code>%@</code>%@</li>",
        [self htmlEscapedString:routeScheme],
        [self htmlEscapedString:routeHost],
        [self htmlEscapedString:routeHandler],
        actionHTML];
  }

  NSMutableString* tagsHTML = [NSMutableString string];
  for (NSString* fileType in fileTypes) {
    if ([fileType isKindOfClass:NSString.class] && fileType.length > 0) {
      [tagsHTML appendFormat:@"<code>.%@</code>", [self htmlEscapedString:fileType]];
    }
  }
  for (NSString* hook in hooks) {
    if ([hook isKindOfClass:NSString.class] && hook.length > 0 &&
        ![self isInternalModuleCapability:hook]) {
      [tagsHTML appendFormat:@"<code>%@</code>", [self htmlEscapedString:hook]];
    }
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>%@</h1>"
       "<section>"
       "<p class='note'>%@</p>"
       "<dl>"
       "<dt>Identifier</dt><dd><code>%@</code></dd>"
       "<dt>Version</dt><dd>%@</dd>"
       "<dt>Type</dt><dd>%@</dd>"
       "<dt>Status</dt><dd>%@</dd>"
       "<dt>PHP</dt><dd><code>%@</code></dd>"
       "<dt>Vendor</dt><dd>%@</dd>"
       "</dl>"
       "</section>"
       "<section><h2>Routes</h2><ul>%@</ul></section>"
       "<section><h2>Capabilities</h2><div class='routeList'>%@</div></section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName],
      [self htmlEscapedString:moduleDescription],
      [self htmlEscapedString:moduleIdentifier ?: @""],
      [self htmlEscapedString:moduleVersion],
      [self htmlEscapedString:moduleType],
      enabled ? @"Enabled" : @"Disabled",
      [self htmlEscapedString:phpRequirement],
      hasIsolatedVendor ? @"Own vendor" : @"No module vendor",
      routesHTML.length > 0 ? routesHTML : @"<li>No route declared.</li>",
      tagsHTML.length > 0 ? tagsHTML : @"<span class='empty'>No capability declared.</span>"];

  return [self internalPageHTMLWithTitle:moduleName body:body];
}

- (NSString*)moduleUpdatesPageHTML {
  NSDictionary* updateResult = [self moduleUpdateReleaseManifestResult];
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSString* sourceLabel = [updateResult[@"sourceLabel"] isKindOfClass:NSString.class]
      ? updateResult[@"sourceLabel"]
      : @"No source";
  NSString* errorMessage = [updateResult[@"error"] isKindOfClass:NSString.class] ? updateResult[@"error"] : @"";
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  NSDictionary* releaseModulesByIdentifier = [self releaseModulesByIdentifier:releaseModules];

  NSError* snapshotError = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&snapshotError];
  NSArray* installedModules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];

  NSMutableString* rowsHTML = [NSMutableString string];
  NSUInteger updateCount = 0;
  if (snapshotError) {
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>",
                           [self htmlEscapedString:snapshotError.localizedDescription]];
  } else if (manifest.count == 0) {
    NSString* message = errorMessage.length > 0
        ? errorMessage
        : @"Configure an update URL or a local update folder containing module zips.";
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>", [self htmlEscapedString:message]];
  } else if (installedModules.count == 0) {
    [rowsHTML appendString:@"<p class='empty'>No installed module was found.</p>"];
  } else {
    NSMutableString* updateRowsHTML = [NSMutableString string];
    for (NSDictionary* module in installedModules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* installedVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSDictionary* releaseModule = releaseModulesByIdentifier[moduleIdentifier];
      NSString* availableVersion =
          [releaseModule[@"version"] isKindOfClass:NSString.class] ? releaseModule[@"version"] : @"";
      NSString* status = @"Not found in update source";
      NSString* actionHTML = @"";
      if (availableVersion.length > 0) {
        NSComparisonResult comparison = [self compareVersion:availableVersion toVersion:installedVersion];
        if (comparison == NSOrderedDescending) {
          status = @"Update available";
          actionHTML = [NSString stringWithFormat:
              @"<label class='updateCheckbox'><input class='updateItemCheckbox' type='checkbox' name='installUpdates' value='%@'> Update</label>",
              [self queryEscapedString:moduleIdentifier]];
          updateCount++;
        } else if (comparison == NSOrderedSame) {
          status = @"Up to date";
        } else {
          status = @"Installed version is newer";
        }
      }

      NSString* wrappedActionsHTML = actionHTML.length > 0
          ? [NSString stringWithFormat:@"<div class='actions'>%@</div>", actionHTML]
          : @"";
      if (actionHTML.length == 0) {
        continue;
      }

      [updateRowsHTML appendFormat:
          @"<li><span>%@</span><small>%@ - Installed %@ - Available %@</small><em>%@</em>%@</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:installedVersion.length > 0 ? installedVersion : @"Unknown"],
          [self htmlEscapedString:availableVersion.length > 0 ? availableVersion : @"None"],
          [self htmlEscapedString:status],
          wrappedActionsHTML];
    }
    if (updateCount == 0) {
      [rowsHTML appendString:@"<p class='empty'>No update available.</p>"];
    } else {
      [rowsHTML appendFormat:
          @"<form class='updatesForm' action='babelchrome://modules' method='get'>"
           "<input type='hidden' name='installSelectedUpdates' value='1'>"
           "<div class='updatesToolbar'>"
           "<label><input id='selectAllUpdates' type='checkbox'> Select all</label>"
           "<button class='primaryButton' type='submit'>Install Updates</button>"
           "</div>"
           "<ul class='stripedList updateList'>%@</ul>"
           "</form>",
          updateRowsHTML];
    }
  }

  NSString* updateURLString = [self moduleUpdateURLString];
  NSString* localDirectory = [self moduleUpdateLocalDirectoryPath];
  NSString* updateScriptHTML = updateCount > 0
      ? @"<script>"
         "const selectAllUpdates=document.getElementById('selectAllUpdates');"
         "if(selectAllUpdates){selectAllUpdates.addEventListener('change',()=>{"
         "document.querySelectorAll('.updateItemCheckbox').forEach((checkbox)=>{checkbox.checked=selectAllUpdates.checked;});"
         "});}"
         "</script>"
      : @"";
  NSString* body = [NSString stringWithFormat:
      @"<h1>Module Updates</h1>"
       "<section>"
       "<h2>Source</h2>"
       "<dl>"
       "<dt>Used source</dt><dd>%@</dd>"
       "<dt>URL source</dt><dd>%@</dd>"
       "<dt>Local fallback</dt><dd>%@</dd>"
       "</dl>"
       "</section>"
       "<section>"
       "<h2>Available Updates</h2>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></div>"
       "%@",
      [self htmlEscapedString:sourceLabel],
      [self htmlEscapedString:updateURLString.length > 0 ? updateURLString : @"Not configured"],
      [self htmlEscapedString:localDirectory.length > 0 ? localDirectory : @"Not configured"],
      rowsHTML,
      updateScriptHTML];
  return [self internalPageHTMLWithTitle:@"Module Updates" body:body];
}

- (void)configureModuleUpdateURLFromPrompt {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Module Update URL";
  alert.informativeText =
      @"Enter either the direct modules-release-manifest.json URL or a base URL containing that file.";
  [alert addButtonWithTitle:@"Save"];
  [alert addButtonWithTitle:@"Cancel"];
  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 520, 28)];
  textField.stringValue = [self moduleUpdateURLString];
  alert.accessoryView = textField;
  if ([alert runModal] != NSAlertFirstButtonReturn) {
    return;
  }

  NSString* value = [textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (value.length == 0) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kModuleUpdateURLDefaultsKey];
  } else {
    [NSUserDefaults.standardUserDefaults setObject:value forKey:kModuleUpdateURLDefaultsKey];
  }
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)configureModuleUpdateLocalDirectoryFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Choose Module Update Folder";
  NSString* currentPath = [self moduleUpdateLocalDirectoryPath];
  if (currentPath.length > 0) {
    panel.directoryURL = [NSURL fileURLWithPath:currentPath];
  }
  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* path = panel.URL.path ?: @"";
  if (path.length == 0) {
    return;
  }

  [NSUserDefaults.standardUserDefaults setObject:path forKey:kModuleUpdateLocalDirectoryDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)installPHPModuleUpdateWithIdentifier:(NSString*)moduleIdentifier {
  [self installPHPModuleUpdatesWithIdentifiers:moduleIdentifier.length > 0 ? @[moduleIdentifier] : @[]];
}

- (void)installPHPModuleUpdatesWithIdentifiers:(NSArray<NSString*>*)moduleIdentifiers {
  if (moduleIdentifiers.count == 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{NSLocalizedDescriptionKey : @"Select at least one module update to install."}]];
    return;
  }

  NSDictionary* updateResult = [self moduleUpdateReleaseManifestResult];
  BOOL didInstallAtLeastOneModule = NO;
  NSMutableSet<NSString*>* seenModuleIdentifiers = [NSMutableSet set];
  NSMutableArray<NSString*>* errors = [NSMutableArray array];

  for (NSString* moduleIdentifier in moduleIdentifiers) {
    NSString* trimmedModuleIdentifier =
        [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedModuleIdentifier.length == 0 || [seenModuleIdentifiers containsObject:trimmedModuleIdentifier]) {
      continue;
    }
    [seenModuleIdentifiers addObject:trimmedModuleIdentifier];

    NSDictionary* releaseModule = [self releaseModuleWithIdentifier:trimmedModuleIdentifier updateResult:updateResult];
    if (!releaseModule) {
      [errors addObject:[NSString stringWithFormat:@"%@: update was not found.", trimmedModuleIdentifier]];
      continue;
    }

    NSError* error = nil;
    NSString* zipPath = [self resolvedUpdateZipPathForReleaseModule:releaseModule
                                                       updateResult:updateResult
                                                              error:&error];
    if (zipPath.length == 0) {
      NSString* message = error.localizedDescription ?: @"Unable to resolve the update zip.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    NSDictionary* response = [BabelLocalServiceHost.sharedHost installModuleZipAtPath:zipPath error:&error];
    if (!response) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (didInstallAtLeastOneModule) {
    [self refreshBabelChromeFileTypeCapabilities];
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:2
                        userInfo:@{NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]}]];
  }
}

- (NSDictionary*)moduleUpdateReleaseManifestResult {
  NSString* updateURLString = [self moduleUpdateURLString];
  NSError* urlError = nil;
  if (updateURLString.length > 0) {
    NSDictionary* result = [self releaseManifestResultFromURLString:updateURLString error:&urlError];
    if (result) {
      return result;
    }
  }

  NSString* localDirectory = [self moduleUpdateLocalDirectoryPath];
  if (localDirectory.length > 0) {
    NSError* error = nil;
    NSDictionary* result = [self releaseManifestResultFromLocalPath:localDirectory error:&error];
    if (result) {
      return result;
    }
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"Local fallback: %@", localDirectory],
      @"error" : error.localizedDescription ?: @"Unable to read the local update folder."
    };
  }

  if (updateURLString.length > 0) {
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"URL: %@", updateURLString],
      @"error" : urlError.localizedDescription ?: @"Unable to read the update URL and no local fallback is configured."
    };
  }

  return @{
    @"sourceLabel" : @"No source configured",
    @"error" : @"Configure an update URL or a local update folder."
  };
}

- (NSDictionary*)releaseManifestResultFromURLString:(NSString*)urlString error:(NSError**)error {
  NSURL* manifestURL = [self moduleUpdateManifestURLForURLString:urlString];
  if (!manifestURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"The configured update URL is invalid."}];
    }
    return nil;
  }

  NSData* data = [NSData dataWithContentsOfURL:manifestURL options:0 error:error];
  if (!data) {
    return nil;
  }

  NSDictionary* manifest = [self releaseManifestFromData:data error:error];
  if (!manifest) {
    return nil;
  }

  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"url",
    @"sourceLabel" : manifestURL.absoluteString ?: @"URL",
    @"baseURL" : [manifestURL URLByDeletingLastPathComponent].absoluteString ?: @""
  };
}

- (NSDictionary*)releaseManifestResultFromLocalPath:(NSString*)path error:(NSError**)error {
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:6
                               userInfo:@{NSLocalizedDescriptionKey : @"The local update source must be a folder containing module zips."}];
    }
    return nil;
  }

  NSArray* directoryEntries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:error];
  if (!directoryEntries) {
    return nil;
  }

  NSDictionary* cachedIndex = [self moduleUpdateLocalIndex];
  NSDictionary* cachedItems = [cachedIndex[@"items"] isKindOfClass:NSDictionary.class] ? cachedIndex[@"items"] : @{};
  NSMutableDictionary* nextCachedItems = [NSMutableDictionary dictionary];
  NSMutableDictionary* latestModulesByIdentifier = [NSMutableDictionary dictionary];

  for (NSString* entryName in directoryEntries) {
    if (![entryName isKindOfClass:NSString.class] || ![entryName.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      continue;
    }

    NSString* zipPath = [path stringByAppendingPathComponent:entryName];
    NSDictionary* releaseModule = [self releaseModuleFromLocalZipAtPath:zipPath
                                                               fileName:entryName
                                                            cachedItems:cachedItems];
    if (!releaseModule) {
      continue;
    }

    nextCachedItems[zipPath] = releaseModule;
    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length == 0) {
      continue;
    }

    NSDictionary* currentModule = latestModulesByIdentifier[moduleIdentifier];
    if (!currentModule || [self shouldPreferReleaseModule:releaseModule overReleaseModule:currentModule]) {
      latestModulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  [self writeModuleUpdateLocalIndex:@{
    @"version" : @1,
    @"items" : nextCachedItems
  }];

  NSArray* modules = [latestModulesByIdentifier.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* leftModule,
                                                                                                         NSDictionary* rightModule) {
    NSString* leftIdentifier = [leftModule[@"id"] isKindOfClass:NSString.class] ? leftModule[@"id"] : @"";
    NSString* rightIdentifier = [rightModule[@"id"] isKindOfClass:NSString.class] ? rightModule[@"id"] : @"";
    return [leftIdentifier compare:rightIdentifier options:NSCaseInsensitiveSearch];
  }];
  if (modules.count == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:7
                               userInfo:@{NSLocalizedDescriptionKey : @"No valid module zip was found in the local update folder."}];
    }
    return nil;
  }

  NSDictionary* manifest = @{
    @"generatedAt" : [NSDate.date descriptionWithLocale:nil],
    @"modules" : modules
  };
  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"local",
    @"sourceLabel" : [NSString stringWithFormat:@"Local folder: %@", path],
    @"basePath" : path
  };
}

- (NSDictionary*)releaseModuleFromLocalZipAtPath:(NSString*)zipPath
                                        fileName:(NSString*)fileName
                                     cachedItems:(NSDictionary*)cachedItems {
  NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:zipPath error:nil];
  NSDate* modificationDate = [attributes[NSFileModificationDate] isKindOfClass:NSDate.class]
      ? attributes[NSFileModificationDate]
      : NSDate.distantPast;
  NSNumber* fileSize = [attributes[NSFileSize] isKindOfClass:NSNumber.class] ? attributes[NSFileSize] : @0;
  NSNumber* modifiedAt = @((NSInteger)floor(modificationDate.timeIntervalSince1970));

  NSDictionary* cachedItem = [cachedItems[zipPath] isKindOfClass:NSDictionary.class] ? cachedItems[zipPath] : nil;
  if (cachedItem &&
      [cachedItem[@"filemtime"] isEqual:modifiedAt] &&
      [cachedItem[@"size"] isEqual:fileSize] &&
      [cachedItem[@"id"] isKindOfClass:NSString.class] &&
      [cachedItem[@"version"] isKindOfClass:NSString.class]) {
    return cachedItem;
  }

  NSError* manifestError = nil;
  NSDictionary* moduleManifest = [self moduleManifestFromZipAtPath:zipPath error:&manifestError];
  if (!moduleManifest) {
    NSLog(@"Unable to read module update zip manifest at %@: %@", zipPath, manifestError.localizedDescription);
    return nil;
  }

  NSString* moduleIdentifier = [moduleManifest[@"id"] isKindOfClass:NSString.class] ? moduleManifest[@"id"] : @"";
  NSString* moduleVersion = [moduleManifest[@"version"] isKindOfClass:NSString.class] ? moduleManifest[@"version"] : @"";
  if (moduleIdentifier.length == 0 || moduleVersion.length == 0) {
    NSLog(@"Skipping module update zip without id or version: %@", zipPath);
    return nil;
  }

  NSString* moduleName = [moduleManifest[@"name"] isKindOfClass:NSString.class] ? moduleManifest[@"name"] : moduleIdentifier;
  NSMutableDictionary* releaseModule = [NSMutableDictionary dictionaryWithDictionary:moduleManifest];
  releaseModule[@"id"] = moduleIdentifier;
  releaseModule[@"name"] = moduleName;
  releaseModule[@"version"] = moduleVersion;
  releaseModule[@"zip"] = fileName ?: zipPath.lastPathComponent;
  releaseModule[@"path"] = zipPath;
  releaseModule[@"filemtime"] = modifiedAt;
  releaseModule[@"size"] = fileSize;
  return releaseModule;
}

- (BOOL)shouldPreferReleaseModule:(NSDictionary*)candidateModule overReleaseModule:(NSDictionary*)currentModule {
  NSString* candidateVersion = [candidateModule[@"version"] isKindOfClass:NSString.class] ? candidateModule[@"version"] : @"";
  NSString* currentVersion = [currentModule[@"version"] isKindOfClass:NSString.class] ? currentModule[@"version"] : @"";
  NSComparisonResult versionComparison = [self compareVersion:candidateVersion toVersion:currentVersion];
  if (versionComparison == NSOrderedDescending) {
    return YES;
  }
  if (versionComparison == NSOrderedAscending) {
    return NO;
  }

  NSNumber* candidateModifiedAt = [candidateModule[@"filemtime"] isKindOfClass:NSNumber.class] ? candidateModule[@"filemtime"] : @0;
  NSNumber* currentModifiedAt = [currentModule[@"filemtime"] isKindOfClass:NSNumber.class] ? currentModule[@"filemtime"] : @0;
  return [candidateModifiedAt compare:currentModifiedAt] == NSOrderedDescending;
}

- (NSDictionary*)moduleManifestFromZipAtPath:(NSString*)zipPath error:(NSError**)error {
  NSData* manifestData = [self dataFromZipAtPath:zipPath innerPath:@"manifest.json" error:nil];
  if (!manifestData) {
    manifestData = [self dataFromZipAtPath:zipPath innerPath:@"*/manifest.json" error:error];
  }
  if (!manifestData) {
    return nil;
  }

  return [self releaseManifestFromData:manifestData error:error];
}

- (NSData*)dataFromZipAtPath:(NSString*)zipPath innerPath:(NSString*)innerPath error:(NSError**)error {
  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
  task.arguments = @[@"-p", zipPath, innerPath];

  NSPipe* outputPipe = [NSPipe pipe];
  NSPipe* errorPipe = [NSPipe pipe];
  task.standardOutput = outputPipe;
  task.standardError = errorPipe;

  NSError* launchError = nil;
  if (![task launchAndReturnError:&launchError]) {
    if (error) {
      *error = launchError;
    }
    return nil;
  }

  NSData* outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
  NSData* errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (task.terminationStatus != 0 || outputData.length == 0) {
    if (error) {
      NSString* unzipError = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:8
                               userInfo:@{NSLocalizedDescriptionKey : unzipError.length > 0
                                                                    ? unzipError
                                                                    : @"Unable to extract manifest.json from the module zip."}];
    }
    return nil;
  }

  return outputData;
}

- (NSDictionary*)moduleUpdateLocalIndex {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSData* data = [NSData dataWithContentsOfFile:indexPath];
  if (!data) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (void)writeModuleUpdateLocalIndex:(NSDictionary*)index {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSString* indexDirectory = indexPath.stringByDeletingLastPathComponent;
  [NSFileManager.defaultManager createDirectoryAtPath:indexDirectory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
  if (data) {
    [data writeToFile:indexPath options:NSDataWritingAtomic error:nil];
  }
}

- (NSDictionary*)releaseManifestFromData:(NSData*)data error:(NSError**)error {
  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest is not a JSON object."}];
    }
    return nil;
  }

  return decoded;
}

- (NSDictionary*)releaseModulesByIdentifier:(NSArray*)releaseModules {
  NSMutableDictionary* modulesByIdentifier = [NSMutableDictionary dictionary];
  for (NSDictionary* releaseModule in releaseModules) {
    if (![releaseModule isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length > 0) {
      modulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  return modulesByIdentifier;
}

- (NSDictionary*)releaseModuleWithIdentifier:(NSString*)moduleIdentifier updateResult:(NSDictionary*)updateResult {
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  return [self releaseModulesByIdentifier:releaseModules][moduleIdentifier ?: @""];
}

- (NSString*)resolvedUpdateZipPathForReleaseModule:(NSDictionary*)releaseModule
                                      updateResult:(NSDictionary*)updateResult
                                             error:(NSError**)error {
  NSString* zipName = [releaseModule[@"zip"] isKindOfClass:NSString.class] ? releaseModule[@"zip"] : @"";
  if (zipName.length == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest entry does not declare a zip file."}];
    }
    return @"";
  }

  NSString* sourceKind = [updateResult[@"sourceKind"] isKindOfClass:NSString.class] ? updateResult[@"sourceKind"] : @"";
  if ([sourceKind isEqualToString:@"local"]) {
    NSString* basePath = [updateResult[@"basePath"] isKindOfClass:NSString.class] ? updateResult[@"basePath"] : @"";
    NSString* zipPath = [basePath stringByAppendingPathComponent:zipName];
    if ([NSFileManager.defaultManager fileExistsAtPath:zipPath]) {
      return zipPath;
    }
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Update zip not found: %@", zipPath]}];
    }
    return @"";
  }

  NSString* baseURLString = [updateResult[@"baseURL"] isKindOfClass:NSString.class] ? updateResult[@"baseURL"] : @"";
  NSURL* baseURL = [NSURL URLWithString:baseURLString];
  NSURL* zipURL = [NSURL URLWithString:zipName relativeToURL:baseURL];
  if (!zipURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey : @"The update zip URL is invalid."}];
    }
    return @"";
  }

  NSData* data = [NSData dataWithContentsOfURL:zipURL options:0 error:error];
  if (!data) {
    return @"";
  }

  NSString* targetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:zipName.lastPathComponent];
  if (![data writeToFile:targetPath options:NSDataWritingAtomic error:error]) {
    return @"";
  }

  return targetPath;
}

- (NSURL*)moduleUpdateManifestURLForURLString:(NSString*)urlString {
  NSString* trimmedString =
      [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedString.length == 0) {
    return nil;
  }

  NSURL* sourceURL = [NSURL URLWithString:trimmedString];
  if (!sourceURL.scheme.length) {
    return nil;
  }

  if ([sourceURL.path.lastPathComponent isEqualToString:@"modules-release-manifest.json"] ||
      [sourceURL.pathExtension.lowercaseString isEqualToString:@"json"]) {
    return sourceURL;
  }

  NSString* separator = [trimmedString hasSuffix:@"/"] ? @"" : @"/";
  return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@modules-release-manifest.json",
                                                         trimmedString,
                                                         separator]];
}

- (NSString*)moduleUpdateLocalIndexPath {
  return [BabelChromeConfiguration.applicationSupportDirectoryURL.path stringByAppendingPathComponent:kModuleUpdateLocalIndexFilename];
}

- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion {
  return [leftVersion compare:rightVersion options:NSNumericSearch];
}

- (NSString*)moduleUpdateURLString {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateURLDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSString*)moduleUpdateLocalDirectoryPath {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateLocalDirectoryDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSDictionary*)moduleRouteForBabelChromeComponents:(NSURLComponents*)components
                                               error:(NSError**)error {
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:error];
  if (!snapshot) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme ?: @"";
  NSString* host = components.host ?: @"";
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
      if ([routeScheme isEqualToString:scheme] && [routeHost isEqualToString:host] &&
          moduleIdentifier.length > 0 && routeHandler.length > 0) {
        return @{
          @"moduleIdentifier" : moduleIdentifier,
          @"route" : routeHandler
        };
      }
    }
  }

  return nil;
}

- (void)refreshBabelChromeFileTypeCapabilities {
  if (browserClient_) {
    browserClient_->RefreshFileTypesHeaderValue();
  }
}

- (void)installPHPModuleZipFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;
  panel.title = @"Install PHP Modules";
  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  BOOL didInstallAtLeastOneModule = NO;
  NSMutableArray<NSString*>* errors = [NSMutableArray array];
  for (NSURL* url in panel.URLs) {
    if (![url.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      [errors addObject:[NSString stringWithFormat:@"%@: selected package must be a zip archive.",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file"]];
      continue;
    }

    NSError* error = nil;
    NSDictionary* response = [BabelLocalServiceHost.sharedHost installModuleZipAtPath:url.path
                                                                                error:&error];
    if (!response) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file",
                                                   message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (didInstallAtLeastOneModule) {
    [self refreshBabelChromeFileTypeCapabilities];
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{
                          NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]
                        }]];
    return;
  }
}

- (void)setPHPModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled {
  NSError* error = nil;
  NSDictionary* response = [BabelLocalServiceHost.sharedHost setModuleWithIdentifier:moduleIdentifier
                                                                             enabled:enabled
                                                                               error:&error];
  if (!response) {
    [self showModuleActionAlertWithError:error];
    return;
  }

  [self refreshBabelChromeFileTypeCapabilities];
}

- (void)removePHPModuleWithIdentifier:(NSString*)moduleIdentifier {
  NSAlert* confirmation = [[NSAlert alloc] init];
  confirmation.messageText = @"Remove PHP Module";
  confirmation.informativeText =
      [NSString stringWithFormat:@"Remove module \"%@\" from BabelChrome?", moduleIdentifier ?: @""];
  [confirmation addButtonWithTitle:@"Remove"];
  [confirmation addButtonWithTitle:@"Cancel"];
  confirmation.alertStyle = NSAlertStyleWarning;
  if ([confirmation runModal] != NSAlertFirstButtonReturn) {
    return;
  }

  NSError* error = nil;
  NSDictionary* response = [BabelLocalServiceHost.sharedHost removeModuleWithIdentifier:moduleIdentifier
                                                                                  error:&error];
  if (!response) {
    [self showModuleActionAlertWithError:error];
    return;
  }

  [self refreshBabelChromeFileTypeCapabilities];
}

- (void)showModuleActionAlertWithError:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Manage PHP Module";
  alert.informativeText = error.localizedDescription ?: @"The module operation failed.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

- (NSString*)userModulesDirectoryPath {
  NSArray<NSURL*>* applicationSupportURLs =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask];
  NSURL* baseURL = applicationSupportURLs.firstObject;
  if (!baseURL) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"BabelChrome/Modules"];
  }

  return [[baseURL URLByAppendingPathComponent:@"BabelForge/BabelChrome/Modules"
                                   isDirectory:YES] path];
}

- (NSString*)settingsTabOpeningStrategyHTML:(NSString*)selectedStrategy {
  NSString* originalClass = [selectedStrategy isEqualToString:kTabOpeningStrategyAppend]
      ? @"option selected"
      : @"option";
  NSString* childClusterClass = [selectedStrategy isEqualToString:kTabOpeningStrategyChildCluster]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Original</strong><span>New tabs open at the end of the tab bar.</span></a>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Parent group</strong><span>New tabs opened from a page stay next to their parent tab.</span></a>"
       "</div>",
      originalClass,
      kTabOpeningStrategyAppend,
      childClusterClass,
      kTabOpeningStrategyChildCluster];
}

- (NSString*)settingsAddressSuggestionsHTML:(NSString*)selectedMode {
  NSString* localClass = [selectedMode isEqualToString:kAddressSuggestionsModeLocal]
      ? @"option selected"
      : @"option";
  NSString* googleClass = [selectedMode isEqualToString:kAddressSuggestionsModeGoogle]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local only</strong><span>Use open tabs and recently closed tabs only.</span></a>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local + Google</strong><span>Also ask Google Suggest while typing.</span></a>"
       "</div>",
      localClass,
      kAddressSuggestionsModeLocal,
      googleClass,
      kAddressSuggestionsModeGoogle];
}

- (NSString*)settingsAppearanceThemeHTML:(NSString*)selectedTheme {
  NSDictionary<NSString*, NSString*>* labels = @{
    BabelThemeAppearanceSystem : @"System",
    BabelThemeAppearanceLight : @"Light",
    BabelThemeAppearanceDark : @"Dark",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    BabelThemeAppearanceSystem : @"Follow the current macOS appearance.",
    BabelThemeAppearanceLight : @"Always use BabelChrome light colors.",
    BabelThemeAppearanceDark : @"Always use BabelChrome dark colors.",
  };
  NSArray<NSString*>* themes = @[
    BabelThemeAppearanceSystem,
    BabelThemeAppearanceLight,
    BabelThemeAppearanceDark
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='babelchrome://settings?appearanceTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme {
  return [self settingsMarkdownThemeHTML:selectedTheme settingsURLString:@"babelchrome://settings"];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme settingsURLString:(NSString*)settingsURLString {
  NSDictionary<NSString*, NSString*>* labels = @{
    kMarkdownThemeGitHubLight : @"GitHub Light",
    kMarkdownThemeGitHubDark : @"GitHub Dark",
    kMarkdownThemeReader : @"Reader",
    kMarkdownThemeCompact : @"Compact",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    kMarkdownThemeGitHubLight : @"Default technical documentation style.",
    kMarkdownThemeGitHubDark : @"Dark technical documentation style.",
    kMarkdownThemeReader : @"Wider reading rhythm for long documents.",
    kMarkdownThemeCompact : @"Denser rendering for reference documents.",
  };
  NSArray<NSString*>* themes = @[
    kMarkdownThemeGitHubLight,
    kMarkdownThemeGitHubDark,
    kMarkdownThemeReader,
    kMarkdownThemeCompact
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='%@?markdownTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        [self htmlEscapedString:settingsURLString ?: @"babelchrome://settings"],
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
}

- (NSString*)moduleSettingsIdentifierFromSettingsComponents:(NSURLComponents*)components {
  NSString* path = components.path ?: @"";
  if ([path hasPrefix:@"/"]) {
    path = [path substringFromIndex:1];
  }
  if (path.length > 0) {
    return path;
  }

  NSString* fragment = components.fragment ?: @"";
  if (fragment.length > 0) {
    return fragment;
  }

  return @"";
}

- (NSString*)normalizedModuleSettingsIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier =
      [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
  if (normalizedIdentifier.length == 0) {
    return @"";
  }

  if ([normalizedIdentifier containsString:@"."]) {
    return normalizedIdentifier;
  }

  return [@"babelforge." stringByAppendingString:normalizedIdentifier];
}

- (NSString*)moduleNameForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (error) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (![currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      continue;
    }

    return [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : currentIdentifier;
  }

  return nil;
}

- (NSArray<NSString*>*)installedExtensionPaths {
  NSArray* extensionPaths =
      [NSUserDefaults.standardUserDefaults arrayForKey:BabelChromeConfiguration.extensionPathsDefaultsKey];
  if (![extensionPaths isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* stringPaths = [NSMutableArray array];
  for (NSString* extensionPath in extensionPaths) {
    if ([extensionPath isKindOfClass:NSString.class] && extensionPath.length > 0) {
      [stringPaths addObject:extensionPath];
    }
  }
  return stringPaths;
}

- (NSArray<NSDictionary*>*)profileInstalledExtensions {
  NSURL* extensionsDirectoryURL = [[BabelChromeConfiguration.profileDirectoryURL
      URLByAppendingPathComponent:@"Default" isDirectory:YES]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES];
  NSMutableDictionary<NSString*, NSDictionary*>* extensionsByIdentifier = [NSMutableDictionary dictionary];
  [self collectProfileExtensionsFromDirectory:extensionsDirectoryURL
                                      enabled:YES
                       extensionsByIdentifier:extensionsByIdentifier];
  [self collectProfileExtensionsFromDirectory:BabelChromeConfiguration.profileExtensionBackupDirectoryURL
                                      enabled:NO
                       extensionsByIdentifier:extensionsByIdentifier];
  for (NSString* disabledIdentifier in [self disabledProfileExtensionIdentifiers]) {
    if (extensionsByIdentifier[disabledIdentifier]) {
      continue;
    }
    extensionsByIdentifier[disabledIdentifier] = @{
      @"id": disabledIdentifier,
      @"name": disabledIdentifier,
      @"version": @"Missing package",
      @"path": @"The extension package is missing from the Chromium profile. Reinstall it from the Chrome Web Store.",
      @"enabled": @NO
    };
  }
  NSMutableArray<NSDictionary*>* extensions = [NSMutableArray arrayWithArray:extensionsByIdentifier.allValues];
  [extensions sortUsingDescriptors:@[
    [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]
  ]];
  return extensions;
}

- (void)collectProfileExtensionsFromDirectory:(NSURL*)extensionsDirectoryURL
                                      enabled:(BOOL)enabled
                       extensionsByIdentifier:(NSMutableDictionary<NSString*, NSDictionary*>*)extensionsByIdentifier {
  NSArray<NSURL*>* extensionIdentifierURLs =
      [NSFileManager.defaultManager contentsOfDirectoryAtURL:extensionsDirectoryURL
                                  includingPropertiesForKeys:nil
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
  for (NSURL* extensionIdentifierURL in extensionIdentifierURLs) {
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:extensionIdentifierURL.path
                                            isDirectory:&isDirectory] ||
        !isDirectory) {
      continue;
    }

    NSArray<NSURL*>* versionURLs =
        [NSFileManager.defaultManager contentsOfDirectoryAtURL:extensionIdentifierURL
                                    includingPropertiesForKeys:nil
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:nil];
    NSURL* latestVersionURL = [self latestExtensionVersionURLFromURLs:versionURLs];
    if (!latestVersionURL) {
      continue;
    }

    NSDictionary* manifest = [self extensionManifestAtURL:
        [latestVersionURL URLByAppendingPathComponent:@"manifest.json" isDirectory:NO]];
    if (!manifest) {
      continue;
    }

    NSString* name = [self extensionNameFromManifest:manifest extensionURL:latestVersionURL];
    NSString* version = [manifest[@"version"] isKindOfClass:NSString.class] ? manifest[@"version"] : @"";
    NSString* identifier = extensionIdentifierURL.lastPathComponent ?: @"";
    extensionsByIdentifier[identifier] = @{
      @"id": identifier,
      @"name": name.length > 0 ? name : identifier,
      @"version": version.length > 0 ? version : latestVersionURL.lastPathComponent ?: @"",
      @"path": latestVersionURL.path ?: @"",
      @"enabled": @(enabled && [self profileExtensionWithIdentifierIsEnabled:identifier])
    };
  }
}

- (NSURL*)latestExtensionVersionURLFromURLs:(NSArray<NSURL*>*)versionURLs {
  NSArray<NSURL*>* sortedURLs = [versionURLs sortedArrayUsingComparator:^NSComparisonResult(
      NSURL* firstURL,
      NSURL* secondURL) {
    return [secondURL.lastPathComponent compare:firstURL.lastPathComponent
                                        options:NSNumericSearch];
  }];
  for (NSURL* versionURL in sortedURLs) {
    BOOL isDirectory = NO;
    NSString* manifestPath = [[versionURL URLByAppendingPathComponent:@"manifest.json"
                                                           isDirectory:NO] path];
    if ([NSFileManager.defaultManager fileExistsAtPath:versionURL.path isDirectory:&isDirectory] &&
        isDirectory &&
        [NSFileManager.defaultManager fileExistsAtPath:manifestPath]) {
      return versionURL;
    }
  }
  return nil;
}

- (NSDictionary*)extensionManifestAtURL:(NSURL*)manifestURL {
  NSData* data = [NSData dataWithContentsOfURL:manifestURL];
  if (!data) {
    return nil;
  }

  id manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [manifest isKindOfClass:NSDictionary.class] ? manifest : nil;
}

- (NSString*)extensionNameFromManifest:(NSDictionary*)manifest extensionURL:(NSURL*)extensionURL {
  NSString* name = [manifest[@"name"] isKindOfClass:NSString.class] ? manifest[@"name"] : @"";
  if (![name hasPrefix:@"__MSG_"] || ![name hasSuffix:@"__"]) {
    return name;
  }

  NSString* messageKey = [name substringWithRange:NSMakeRange(6, name.length - 8)];
  NSString* defaultLocale = [manifest[@"default_locale"] isKindOfClass:NSString.class]
      ? manifest[@"default_locale"]
      : @"en";
  NSString* localizedName = [self localizedExtensionMessageForKey:messageKey
                                                           locale:defaultLocale
                                                     extensionURL:extensionURL];
  return localizedName.length > 0 ? localizedName : name;
}

- (NSString*)localizedExtensionMessageForKey:(NSString*)messageKey
                                      locale:(NSString*)locale
                                extensionURL:(NSURL*)extensionURL {
  NSURL* messagesURL = [[[extensionURL URLByAppendingPathComponent:@"_locales"
                                                       isDirectory:YES]
      URLByAppendingPathComponent:locale isDirectory:YES]
      URLByAppendingPathComponent:@"messages.json" isDirectory:NO];
  NSData* data = [NSData dataWithContentsOfURL:messagesURL];
  if (!data) {
    return @"";
  }

  id messages = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![messages isKindOfClass:NSDictionary.class]) {
    return @"";
  }

  NSDictionary* message = messages[messageKey];
  if (![message isKindOfClass:NSDictionary.class] ||
      ![message[@"message"] isKindOfClass:NSString.class]) {
    return @"";
  }
  return message[@"message"];
}

- (NSURL*)profilePreferencesFileURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Preferences" isDirectory:NO];
}

- (NSURL*)profileSecurePreferencesFileURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Secure Preferences" isDirectory:NO];
}

- (NSURL*)profileExtensionDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [[[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                         isDirectory:YES]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES]
      URLByAppendingPathComponent:extensionIdentifier isDirectory:YES];
}

- (NSURL*)profileExtensionBackupDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [BabelChromeConfiguration.profileExtensionBackupDirectoryURL
      URLByAppendingPathComponent:extensionIdentifier isDirectory:YES];
}

- (NSURL*)disabledProfileExtensionsDirectoryURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Disabled Extensions" isDirectory:YES];
}

- (NSURL*)disabledProfileExtensionDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [[self disabledProfileExtensionsDirectoryURL] URLByAppendingPathComponent:extensionIdentifier
                                                                       isDirectory:YES];
}

- (NSDictionary*)profilePreferencesDictionaryAtURL:(NSURL*)preferencesURL {
  NSData* data = [NSData dataWithContentsOfURL:preferencesURL];
  if (!data) {
    return @{};
  }

  id preferences = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [preferences isKindOfClass:NSDictionary.class] ? preferences : @{};
}

- (NSMutableDictionary*)mutableProfilePreferencesDictionaryAtURL:(NSURL*)preferencesURL {
  NSData* data = [NSData dataWithContentsOfURL:preferencesURL];
  if (!data) {
    return [NSMutableDictionary dictionary];
  }

  id preferences = [NSJSONSerialization JSONObjectWithData:data
                                                   options:NSJSONReadingMutableContainers
                                                     error:nil];
  return [preferences isKindOfClass:NSMutableDictionary.class]
      ? preferences
      : [NSMutableDictionary dictionary];
}

- (BOOL)saveProfilePreferencesDictionary:(NSDictionary*)preferences toURL:(NSURL*)preferencesURL {
  if (preferences.count == 0) {
    return NO;
  }

  NSData* data = [NSJSONSerialization dataWithJSONObject:preferences options:0 error:nil];
  if (!data) {
    return NO;
  }

  return [data writeToURL:preferencesURL atomically:YES];
}

- (BOOL)profileExtensionWithIdentifierIsEnabled:(NSString*)extensionIdentifier {
  if ([[self disabledProfileExtensionIdentifiers] containsObject:extensionIdentifier]) {
    return NO;
  }

  NSDictionary* preferences = [self profilePreferencesDictionaryAtURL:[self profilePreferencesFileURL]];
  NSNumber* state = [self profileExtensionStateForIdentifier:extensionIdentifier
                                                 preferences:preferences];
  if (state) {
    return state.integerValue != 0;
  }

  return YES;
}

- (NSNumber*)profileExtensionStateForIdentifier:(NSString*)extensionIdentifier
                                    preferences:(NSDictionary*)preferences {
  NSDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  NSDictionary* settings = [extensions[@"settings"] isKindOfClass:NSDictionary.class]
      ? extensions[@"settings"]
      : nil;
  NSDictionary* extensionSettings = [settings[extensionIdentifier] isKindOfClass:NSDictionary.class]
      ? settings[extensionIdentifier]
      : nil;
  NSNumber* state = [extensionSettings[@"state"] isKindOfClass:NSNumber.class]
      ? extensionSettings[@"state"]
      : nil;
  return state;
}

- (BOOL)isValidProfileExtensionIdentifier:(NSString*)extensionIdentifier {
  if (extensionIdentifier.length == 0) {
    return NO;
  }

  NSCharacterSet* invalidCharacters =
      [[NSCharacterSet alphanumericCharacterSet] invertedSet];
  return [extensionIdentifier rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound;
}

- (void)setProfileExtensionWithIdentifier:(NSString*)extensionIdentifier enabled:(BOOL)enabled {
  if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
    return;
  }

  if (!enabled) {
    [self backupProfileExtensionWithIdentifier:extensionIdentifier];
  }
  [self saveProfileExtensionWithIdentifier:extensionIdentifier disabled:!enabled];
  [self savePendingProfileExtensionRestartStateForIdentifier:extensionIdentifier
                                                     enabled:enabled];
  [self setProfileExtensionPreferenceStateWithIdentifier:extensionIdentifier
                                                 enabled:enabled
                                          preferencesURL:[self profilePreferencesFileURL]
                                      createMissingEntry:YES];
}

- (void)restoreProfileExtensionsMovedByOlderVersions {
  NSFileManager* fileManager = NSFileManager.defaultManager;
  NSURL* disabledExtensionsURL = [self disabledProfileExtensionsDirectoryURL];
  NSArray<NSURL*>* disabledExtensionURLs =
      [fileManager contentsOfDirectoryAtURL:disabledExtensionsURL
                 includingPropertiesForKeys:nil
                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                      error:nil];
  for (NSURL* disabledExtensionURL in disabledExtensionURLs) {
    NSString* extensionIdentifier = disabledExtensionURL.lastPathComponent;
    if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
      continue;
    }

    NSURL* activeExtensionURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
    if ([fileManager fileExistsAtPath:activeExtensionURL.path]) {
      continue;
    }

    [fileManager createDirectoryAtURL:[activeExtensionURL URLByDeletingLastPathComponent]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
    [fileManager moveItemAtURL:disabledExtensionURL
                         toURL:activeExtensionURL
                         error:nil];
  }
}

- (void)backupProfileExtensionWithIdentifier:(NSString*)extensionIdentifier {
  NSURL* extensionDirectoryURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* backupDirectoryURL = [self profileExtensionBackupDirectoryURLForIdentifier:extensionIdentifier];
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:extensionDirectoryURL.path
                                         isDirectory:&isDirectory] ||
      !isDirectory) {
    return;
  }

  [NSFileManager.defaultManager createDirectoryAtURL:[backupDirectoryURL URLByDeletingLastPathComponent]
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  [NSFileManager.defaultManager removeItemAtURL:backupDirectoryURL error:nil];
  [NSFileManager.defaultManager copyItemAtURL:extensionDirectoryURL
                                        toURL:backupDirectoryURL
                                        error:nil];
}

- (NSArray<NSString*>*)disabledProfileExtensionIdentifiers {
  NSArray* identifiers = [NSUserDefaults.standardUserDefaults
      arrayForKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey];
  if (![identifiers isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* validIdentifiers = [NSMutableArray array];
  for (NSString* identifier in identifiers) {
    if ([identifier isKindOfClass:NSString.class] &&
        [self isValidProfileExtensionIdentifier:identifier]) {
      [validIdentifiers addObject:identifier];
    }
  }
  return validIdentifiers;
}

- (void)saveProfileExtensionWithIdentifier:(NSString*)extensionIdentifier disabled:(BOOL)disabled {
  NSMutableArray<NSString*>* identifiers = [[self disabledProfileExtensionIdentifiers] mutableCopy];
  if (disabled && ![identifiers containsObject:extensionIdentifier]) {
    [identifiers addObject:extensionIdentifier];
  }
  if (!disabled) {
    [identifiers removeObject:extensionIdentifier];
  }

  [NSUserDefaults.standardUserDefaults setObject:identifiers
                                          forKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (NSDictionary*)pendingProfileExtensionRestartStates {
  NSDictionary* states = [NSUserDefaults.standardUserDefaults
      dictionaryForKey:BabelChromeConfiguration.pendingProfileExtensionRestartStatesDefaultsKey];
  return [states isKindOfClass:NSDictionary.class] ? states : @{};
}

- (void)savePendingProfileExtensionRestartStateForIdentifier:(NSString*)extensionIdentifier
                                                    enabled:(BOOL)enabled {
  NSMutableDictionary* states = [[self pendingProfileExtensionRestartStates] mutableCopy];
  states[extensionIdentifier] = enabled ? @"enable" : @"disable";
  [NSUserDefaults.standardUserDefaults setObject:states
                                          forKey:[BabelChromeConfiguration
                                                     pendingProfileExtensionRestartStatesDefaultsKey]];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)clearPendingProfileExtensionRestartStates {
  [NSUserDefaults.standardUserDefaults removeObjectForKey:[BabelChromeConfiguration
                                                              pendingProfileExtensionRestartStatesDefaultsKey]];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (BOOL)profileExtensionRequiresRestart:(NSString*)extensionIdentifier {
  return [self pendingProfileExtensionRestartStates][extensionIdentifier] != nil;
}

- (NSString*)profileExtensionStatusLabelForIdentifier:(NSString*)extensionIdentifier
                                              enabled:(BOOL)enabled {
  NSString* pendingState = [self pendingProfileExtensionRestartStates][extensionIdentifier];
  if ([pendingState isEqualToString:@"enable"]) {
    return @"Enabled after restart";
  }
  if ([pendingState isEqualToString:@"disable"]) {
    return @"Disabled after restart";
  }
  return enabled ? @"Enabled" : @"Disabled";
}

- (void)setProfileExtensionPreferenceStateWithIdentifier:(NSString*)extensionIdentifier
                                                enabled:(BOOL)enabled
                                         preferencesURL:(NSURL*)preferencesURL
                                     createMissingEntry:(BOOL)createMissingEntry {
  NSMutableDictionary* preferences = [self mutableProfilePreferencesDictionaryAtURL:preferencesURL];
  NSMutableDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSMutableDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  if (!extensions) {
    if (!createMissingEntry) {
      return;
    }
    extensions = [NSMutableDictionary dictionary];
    preferences[@"extensions"] = extensions;
  }

  NSMutableDictionary* settings = [extensions[@"settings"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"settings"]
      : nil;
  if (!settings) {
    if (!createMissingEntry) {
      return;
    }
    settings = [NSMutableDictionary dictionary];
    extensions[@"settings"] = settings;
  }

  NSMutableDictionary* extensionSettings =
      [settings[extensionIdentifier] isKindOfClass:NSMutableDictionary.class]
          ? settings[extensionIdentifier]
          : nil;
  if (!extensionSettings) {
    if (!createMissingEntry) {
      return;
    }
    extensionSettings = [NSMutableDictionary dictionary];
    settings[extensionIdentifier] = extensionSettings;
  }

  extensionSettings[@"state"] = enabled ? @1 : @0;
  extensionSettings[@"disable_reasons"] = enabled ? @[] : @[ @1 ];
  [self saveProfilePreferencesDictionary:preferences toURL:preferencesURL];
}

- (void)removeProfileExtensionWithIdentifier:(NSString*)extensionIdentifier {
  if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
    return;
  }

  NSURL* extensionDirectoryURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* disabledExtensionDirectoryURL =
      [self disabledProfileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* backupExtensionDirectoryURL =
      [self profileExtensionBackupDirectoryURLForIdentifier:extensionIdentifier];
  [NSFileManager.defaultManager removeItemAtURL:extensionDirectoryURL error:nil];
  [NSFileManager.defaultManager removeItemAtURL:disabledExtensionDirectoryURL error:nil];
  [NSFileManager.defaultManager removeItemAtURL:backupExtensionDirectoryURL error:nil];
  [self saveProfileExtensionWithIdentifier:extensionIdentifier disabled:NO];
  [self removeProfileExtensionReferencesWithIdentifier:extensionIdentifier
                                           preferences:[self profilePreferencesFileURL]];
  [self removeProfileExtensionReferencesWithIdentifier:extensionIdentifier
                                           preferences:[self profileSecurePreferencesFileURL]];
}

- (void)removeProfileExtensionReferencesWithIdentifier:(NSString*)extensionIdentifier
                                           preferences:(NSURL*)preferencesURL {
  NSMutableDictionary* preferences = [self mutableProfilePreferencesDictionaryAtURL:preferencesURL];
  if (preferences.count == 0) {
    return;
  }

  NSMutableDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSMutableDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  NSMutableDictionary* settings = [extensions[@"settings"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"settings"]
      : nil;
  [settings removeObjectForKey:extensionIdentifier];

  NSMutableDictionary* commands = [extensions[@"commands"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"commands"]
      : nil;
  for (NSString* commandName in commands.allKeys.copy) {
    NSDictionary* command = [commands[commandName] isKindOfClass:NSDictionary.class]
        ? commands[commandName]
        : nil;
    if ([command[@"extension"] isEqualToString:extensionIdentifier]) {
      [commands removeObjectForKey:commandName];
    }
  }

  NSMutableDictionary* installSignature =
      [extensions[@"install_signature"] isKindOfClass:NSMutableDictionary.class]
          ? extensions[@"install_signature"]
          : nil;
  [self removeProfileExtensionIdentifier:extensionIdentifier
                         fromMutableArray:installSignature[@"ids"]];
  [self removeProfileExtensionIdentifier:extensionIdentifier
                         fromMutableArray:installSignature[@"invalid_ids"]];

  NSMutableDictionary* updateClientData =
      [preferences[@"updateclientdata"] isKindOfClass:NSMutableDictionary.class]
          ? preferences[@"updateclientdata"]
          : nil;
  NSMutableDictionary* updateClientApps =
      [updateClientData[@"apps"] isKindOfClass:NSMutableDictionary.class]
          ? updateClientData[@"apps"]
          : nil;
  [updateClientApps removeObjectForKey:extensionIdentifier];

  [self saveProfilePreferencesDictionary:preferences toURL:preferencesURL];
}

- (void)removeProfileExtensionIdentifier:(NSString*)extensionIdentifier
                        fromMutableArray:(id)mutableArray {
  if (![mutableArray isKindOfClass:NSMutableArray.class]) {
    return;
  }

  [mutableArray removeObject:extensionIdentifier];
}

- (void)saveInstalledExtensionPaths:(NSArray<NSString*>*)extensionPaths {
  [NSUserDefaults.standardUserDefaults setObject:extensionPaths
                                          forKey:BabelChromeConfiguration.extensionPathsDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)addUnpackedExtensionFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.prompt = @"Add";
  panel.message = @"Choose an unpacked Chrome extension folder containing manifest.json.";

  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* extensionPath = panel.URL.path;
  NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
  if (![NSFileManager.defaultManager fileExistsAtPath:manifestPath]) {
    [self showExtensionFolderMissingManifestAlert:extensionPath];
    return;
  }

  NSMutableArray<NSString*>* extensionPaths = [[self installedExtensionPaths] mutableCopy];
  if (![extensionPaths containsObject:extensionPath]) {
    [extensionPaths addObject:extensionPath];
  }
  [self saveInstalledExtensionPaths:extensionPaths];
}

- (void)removeUnpackedExtensionAtPath:(NSString*)extensionPath {
  NSMutableArray<NSString*>* extensionPaths = [[self installedExtensionPaths] mutableCopy];
  [extensionPaths removeObject:extensionPath];
  [self saveInstalledExtensionPaths:extensionPaths];
}

- (void)openChromeWebStoreSearchForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedQuery.length == 0) {
    return;
  }

  NSString* urlString = [NSString stringWithFormat:@"https://chromewebstore.google.com/search/%@",
                                                   [self pathEscapedString:trimmedQuery]];
  [self openURLStringInNewTab:urlString];
}

- (void)showExtensionFolderMissingManifestAlert:(NSString*)extensionPath {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Invalid Extension Folder";
  alert.informativeText = [NSString stringWithFormat:@"The selected folder does not contain manifest.json:\n%@",
                                                     extensionPath ?: @""];
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

- (void)showLocalServiceStartupAlert:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Start Local Viewer";
  alert.informativeText = error.localizedDescription ?: @"BabelChrome could not start the local file viewer service.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

- (NSString*)queryEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)pathEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLPathAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)shellQuotedString:(NSString*)value {
  return [NSString stringWithFormat:@"'%@'",
                                    [value stringByReplacingOccurrencesOfString:@"'"
                                                                     withString:@"'\\''"]];
}

- (NSString*)trashIconHTML {
  return @"<svg class='buttonIcon' viewBox='0 0 24 24' aria-hidden='true'>"
          "<path d='M9 3h6l1 2h4v2H4V5h4l1-2z'/>"
          "<path d='M6 9h12l-1 12H7L6 9zm4 2v8h2v-8h-2zm4 0v8h2v-8h-2z'/>"
          "</svg>";
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  NSString* resourcePath = [NSBundle.mainBundle pathForResource:resourceName ofType:@"svg"];
  if (resourcePath.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSError* error = nil;
  NSString* iconHTML = [NSString stringWithContentsOfFile:resourcePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (error || iconHTML.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSMutableString* normalizedIconHTML = [NSMutableString stringWithString:iconHTML];
  [normalizedIconHTML replaceOccurrencesOfString:@"<svg "
                                      withString:@"<svg class='buttonIcon gearIcon' aria-hidden='true' "
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];
  [normalizedIconHTML replaceOccurrencesOfString:@"fill=\"#17345a\""
                                      withString:@"fill=\"currentColor\""
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];

  return normalizedIconHTML;
}

- (BOOL)isInternalModuleCapability:(NSString*)capability {
  static NSSet<NSString*>* internalCapabilities = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    internalCapabilities = [NSSet setWithArray:@[
      @"app.did-start",
      @"app.will-quit",
      @"drop.local-paths",
      @"settings.section.register"
    ]];
  });

  return [internalCapabilities containsObject:capability ?: @""];
}

- (BOOL)internalPagesUseDarkTheme {
  NSString* mode = [BabelTheme.sharedTheme appearanceMode];
  if ([mode isEqualToString:BabelThemeAppearanceDark]) {
    return YES;
  }

  if ([mode isEqualToString:BabelThemeAppearanceLight]) {
    return NO;
  }

  NSAppearanceName name = [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[
    NSAppearanceNameAqua,
    NSAppearanceNameDarkAqua
  ]];
  return [name isEqualToString:NSAppearanceNameDarkAqua];
}

- (void)restartApplication {
  NSString* bundlePath = NSBundle.mainBundle.bundlePath;
  if (bundlePath.length == 0) {
    [self requestApplicationTermination];
    return;
  }

  int processIdentifier = NSProcessInfo.processInfo.processIdentifier;
  NSString* script = [NSString stringWithFormat:
      @"while /bin/kill -0 %d 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open %@",
      processIdentifier,
      [self shellQuotedString:bundlePath]];

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/nohup"];
  task.arguments = @[@"/bin/sh", @"-c", script];
  NSFileHandle* nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  if (nullHandle) {
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;
  }
  [task launchAndReturnError:nil];
  [self requestApplicationTermination];
}

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  NSString* bodyClass = [self internalPagesUseDarkTheme] ? @"dark" : @"light";
  return [NSString stringWithFormat:
      @"<!doctype html><html><head><meta charset='utf-8'>"
       "<title>%@</title>"
       "<style>"
       "body{font:14px -apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;margin:0;color:#1f2933;background:#f7f8fa;}"
       "main{max-width:920px;margin:0 auto;padding:34px 42px;}"
       "h1{font-size:30px;margin:0 0 24px;}h2{font-size:16px;margin:28px 0 12px;color:#44515f;}"
       "ul{list-style:none;margin:0;padding:0;border:1px solid #d8dde3;border-radius:8px;background:white;overflow:hidden;}"
       "li{display:grid;grid-template-columns:minmax(160px,1fr) minmax(260px,2fr) minmax(180px,auto);gap:18px;padding:12px 14px;border-top:1px solid #eef1f4;align-items:center;}"
       "li:first-child{border-top:0;}span{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}"
       "small{color:#526171;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}em{color:#7a8794;font-style:normal;text-align:right;}"
       "dl{display:grid;grid-template-columns:180px 1fr;gap:12px 18px;background:white;border:1px solid #d8dde3;border-radius:8px;padding:18px;}"
       "dt{font-weight:700;}dd{margin:0;color:#526171;}"
       ".options{display:grid;grid-template-columns:repeat(2,minmax(180px,1fr));gap:10px;}"
       ".option{display:block;text-decoration:none;color:#243447;border:1px solid #d8dde3;border-radius:8px;padding:12px;background:#f9fafb;cursor:pointer;}"
       ".option strong{display:block;margin-bottom:5px;color:#172533;}.option span{display:block;color:#526171;line-height:1.35;}"
       ".option.selected{border-color:#1473e6;background:#edf5ff;box-shadow:inset 0 0 0 1px #1473e6;}"
       ".stripedList li:nth-child(odd){background:#fff;}.stripedList li:nth-child(even){background:#f3f8ff;}"
       ".primaryButton,.smallButton,button{display:inline-flex;align-items:center;justify-content:center;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;text-decoration:none;font-weight:700;min-height:32px;padding:0 12px;cursor:pointer;}"
       ".primaryButton{background:#1473e6;border-color:#1473e6;color:#fff;}.smallButton{min-height:26px;font-size:12px;}"
       ".primarySmallButton{border-color:#1473e6;background:#1473e6;color:#fff;}"
       ".buttonRow{display:flex;align-items:center;gap:8px;flex-wrap:wrap;}"
       ".gearMenu{position:relative;}.gearMenu summary{display:inline-flex;align-items:center;justify-content:center;width:54px;min-height:38px;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;cursor:pointer;list-style:none;}"
       ".gearMenu summary::-webkit-details-marker{display:none;}.gearMenuPanel{position:absolute;z-index:10;right:0;top:46px;display:grid;gap:8px;min-width:190px;padding:10px;background:#fff;border:1px solid #d8dde3;border-radius:8px;box-shadow:0 10px 28px rgba(20,32,45,.18);}"
       ".updatesForm{display:grid;gap:10px;}.updatesToolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:10px 12px;}"
       ".updatesToolbar label,.updateCheckbox{display:inline-flex;align-items:center;gap:7px;font-weight:700;color:#243447;cursor:pointer;}.updateList input{cursor:pointer;}"
       ".moduleList .moduleItem{grid-template-columns:minmax(0,1fr) 230px;gap:18px;align-items:center;}"
       ".moduleText{min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:5px 14px;align-items:center;}"
       ".moduleText span,.moduleText small{min-width:0;}.moduleText span,.moduleText small{display:block;}.moduleText em{text-align:left;}"
       ".moduleText .note{grid-column:1 / -1;margin:0;}"
       ".moduleButtons{display:grid;grid-template-columns:repeat(2,minmax(92px,1fr));gap:8px;align-content:center;}"
       ".moduleButtonCell{min-height:26px;}.moduleButtonCell .smallButton{width:100%%;box-sizing:border-box;}"
       ".bottomButtonRow{display:flex;justify-content:flex-start;margin-top:14px;}"
       "li>.note{grid-column:1 / 3;margin:0;}"
       "li>.actions{grid-column:3;grid-row:1 / span 2;}"
       ".actions{display:flex;align-items:center;justify-content:flex-end;gap:8px;min-width:0;flex-wrap:wrap;}"
       ".routeList{grid-column:1 / 3;display:flex;align-items:center;gap:7px;flex-wrap:wrap;min-width:0;}"
       ".routeList code{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;background:#f1f5f9;border:1px solid #d8dde3;border-radius:6px;padding:3px 6px;color:#273849;}"
       ".routeList span{color:#7a8794;font-weight:700;}"
       ".dangerButton{border-color:#f0b9b9;color:#8a1f1f;background:#fff8f8;}.iconTextButton{gap:6px;}"
       ".buttonIcon{width:14px;height:14px;fill:currentColor;flex:0 0 auto;}.gearIcon{width:24px;height:24px;}"
       ".searchForm{display:grid;grid-template-columns:minmax(220px,1fr) auto;gap:10px;max-width:620px;}"
       "input{font:inherit;border:1px solid #c7d0db;border-radius:7px;padding:8px 10px;background:#fff;}"
       ".note,.empty{color:#526171;line-height:1.45;}.empty{background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:14px;}"
       "body.dark{color:#e7edf5;background:#15171a;}"
       "body.dark h2{color:#c8d3df;}"
       "body.dark ul,body.dark dl,body.dark .empty{background:#1e2227;border-color:#343b44;}"
       "body.dark li{border-top-color:#2d333b;}"
       "body.dark small,body.dark dd,body.dark .note,body.dark .empty{color:#aeb8c4;}"
       "body.dark em,body.dark .routeList span{color:#8f9ba8;}"
       "body.dark .option{color:#dbe5f0;border-color:#343b44;background:#20252b;}"
       "body.dark .option strong{color:#f4f7fb;}body.dark .option span{color:#aeb8c4;}"
       "body.dark .option.selected{border-color:#5ea1ff;background:#193149;box-shadow:inset 0 0 0 1px #5ea1ff;}"
       "body.dark .stripedList li:nth-child(odd){background:#1e2227;}body.dark .stripedList li:nth-child(even){background:#202a35;}"
       "body.dark .primaryButton,body.dark .smallButton,body.dark button{border-color:#46515d;background:#242a31;color:#f4f7fb;}"
       "body.dark .primaryButton,body.dark .primarySmallButton{background:#2f7de1;border-color:#2f7de1;color:#fff;}"
       "body.dark .gearMenu summary,body.dark .gearMenuPanel,body.dark .updatesToolbar{border-color:#343b44;background:#1e2227;color:#f4f7fb;}"
       "body.dark .gearMenuPanel{box-shadow:0 10px 28px rgba(0,0,0,.32);}body.dark .updatesToolbar label,body.dark .updateCheckbox{color:#dbe5f0;}"
       "body.dark .dangerButton{border-color:#7f3a43;color:#ffb6bf;background:#321d22;}"
       "body.dark input{background:#1e2227;border-color:#46515d;color:#f4f7fb;}"
       "body.dark .routeList code{background:#20252b;border-color:#343b44;color:#dbe5f0;}"
       "</style></head><body class='%@'><main>%@</main>"
       "<script>"
       "document.addEventListener('click',(event)=>{"
       "document.querySelectorAll('.gearMenu[open]').forEach((menu)=>{"
       "if(!menu.contains(event.target)){menu.removeAttribute('open');}"
       "});"
       "});"
       "document.addEventListener('keydown',(event)=>{"
       "if(event.key==='Escape'){document.querySelectorAll('.gearMenu[open]').forEach((menu)=>menu.removeAttribute('open'));}"
       "});"
       "document.addEventListener('contextmenu',(event)=>{"
       "const control=event.target.closest('a.smallButton,a.primaryButton,a.option,button,summary');"
       "if(control&&control.dataset.canOpenMenu!=='true'){event.preventDefault();}"
       "},true);"
       "</script></body></html>",
      [self htmlEscapedString:title],
      bodyClass,
      body ?: @""];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* escapedString = [NSMutableString stringWithString:value ?: @""];
  [escapedString replaceOccurrencesOfString:@"&"
                                 withString:@"&amp;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"<"
                                 withString:@"&lt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@">"
                                 withString:@"&gt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"\""
                                 withString:@"&quot;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  return escapedString;
}

- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab {
  return [tab.requestedURLString isEqualToString:kHistoryPageURLString] ||
         [tab.requestedURLString isEqualToString:kSettingsPageURLString] ||
         [tab.requestedURLString isEqualToString:kExtensionsPageURLString] ||
         [tab.requestedURLString isEqualToString:kModulesPageURLString];
}

- (void)openDeveloperToolsForSelectedTab {
  if (!selectedTab_ || ![selectedTab_ browser]) {
    return;
  }

  [self openDeveloperToolsForBrowser:[selectedTab_ browser] x:0 y:0];
}

- (void)openDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser x:(int)x y:(int)y {
  if (![self canOpenDeveloperToolsForBrowser:browser]) {
    return;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab) {
    return;
  }

  tab.developerToolsVisible = YES;
  tab.developerToolsPanelView.hidden = tab != selectedTab_;
  [self layoutBrowserViewsForTab:tab];

  [self loadDeveloperToolsForTab:tab inspectingBrowser:browser];
}

- (BOOL)canOpenDeveloperToolsForSelectedTab {
  if (!selectedTab_ || ![selectedTab_ browser]) {
    return NO;
  }
  return [self canOpenDeveloperToolsForBrowser:[selectedTab_ browser]];
}

- (BOOL)canOpenDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  return tab && !tab.developerToolsVisible && ![tab developerToolsBrowser];
}

- (BOOL)canOpenViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSURL* sourceURL = [self viewerSourceFileURLForBrowser:browser];
  return sourceURL && [NSFileManager.defaultManager fileExistsAtPath:sourceURL.path];
}

- (void)openViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSURL* sourceURL = [self viewerSourceFileURLForBrowser:browser];
  if (!sourceURL) {
    return;
  }

  [NSWorkspace.sharedWorkspace openURL:sourceURL];
}

- (void)revealViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSURL* sourceURL = [self viewerSourceFileURLForBrowser:browser];
  if (!sourceURL) {
    return;
  }

  [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ sourceURL ]];
}

- (NSURL*)viewerSourceFileURLForBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  NSString* requestedURLString = tab.requestedURLString ?: @"";
  if (![self isStableViewerURLString:requestedURLString] ||
      ![[self sourceKindForStableViewerURLString:requestedURLString] isEqualToString:@"file"]) {
    return nil;
  }

  NSURL* sourceURL = [self sourceURLForViewerURLString:requestedURLString];
  return sourceURL.isFileURL ? sourceURL : nil;
}

- (void)closeDeveloperToolsFromButton:(NSButton*)sender {
  BabelBrowserTab* tab = [self tabForDeveloperToolsControl:sender];
  [self closeDeveloperToolsForTab:tab];
}

- (void)changeDeveloperToolsDockFromButton:(NSButton*)sender {
  NSString* dockMode = [self developerToolsDockModeForTag:sender.tag];
  if (dockMode.length == 0) {
    return;
  }

  developerToolsDockMode_ = dockMode;
  [NSUserDefaults.standardUserDefaults setObject:dockMode
                                          forKey:kDeveloperToolsDockModeDefaultsKey];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)resizeDeveloperToolsFromHandle:(BabelDeveloperToolsResizeHandleView*)sender {
  NSRect bounds = pagesPanel_.bounds;
  CGFloat axisLength = [self developerToolsDockModeIsHorizontal]
      ? bounds.size.height
      : bounds.size.width;
  if (axisLength <= 0.0) {
    return;
  }

  CGFloat signedDelta = sender.dragDelta;
  if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeTop] ||
      [developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeRight]) {
    signedDelta = -signedDelta;
  }

  developerToolsSizeRatio_ = MIN(0.78, MAX(0.20, developerToolsSizeRatio_ +
                                                    (signedDelta / axisLength)));
  [NSUserDefaults.standardUserDefaults setDouble:developerToolsSizeRatio_
                                          forKey:kDeveloperToolsSizeRatioDefaultsKey];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)toggleSidebarCollapsed:(id)sender {
  if (!sidebarCollapsed_) {
    [self saveExpandedSidebarWidth:sidebarView_.frame.size.width];
  }
  CGFloat targetWidth = sidebarCollapsed_ ? [self restoredExpandedSidebarWidth] : kSidebarCollapsedWidth;
  sidebarCollapsed_ = !sidebarCollapsed_;
  [NSUserDefaults.standardUserDefaults setBool:sidebarCollapsed_
                                        forKey:kSidebarCollapsedDefaultsKey];
  [splitView_ setPosition:targetWidth ofDividerAtIndex:0];
  [self layoutInterfaceForCurrentSplitViewSize];
  [splitView_ setNeedsDisplay:YES];
  [sidebarView_ setNeedsDisplay:YES];
  [rightView_ setNeedsDisplay:YES];
}

- (BabelBrowserTab*)tabForDeveloperToolsControl:(NSView*)control {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([control isDescendantOf:tab.developerToolsPanelView]) {
        return tab;
      }
    }
  }
  return nil;
}

- (NSString*)developerToolsDockModeForTag:(NSInteger)tag {
  if (tag == kDeveloperToolsDockTagLeft) {
    return kDeveloperToolsDockModeLeft;
  }
  if (tag == kDeveloperToolsDockTagRight) {
    return kDeveloperToolsDockModeRight;
  }
  if (tag == kDeveloperToolsDockTagTop) {
    return kDeveloperToolsDockModeTop;
  }
  if (tag == kDeveloperToolsDockTagBottom) {
    return kDeveloperToolsDockModeBottom;
  }
  return nil;
}

- (NSString*)restoredDeveloperToolsDockMode {
  NSString* mode = [NSUserDefaults.standardUserDefaults stringForKey:kDeveloperToolsDockModeDefaultsKey];
  NSSet<NSString*>* allowedModes = [NSSet setWithObjects:kDeveloperToolsDockModeBottom,
                                                        kDeveloperToolsDockModeTop,
                                                        kDeveloperToolsDockModeLeft,
                                                        kDeveloperToolsDockModeRight,
                                                        nil];
  return [allowedModes containsObject:mode] ? mode : kDeveloperToolsDockModeBottom;
}

- (CGFloat)restoredDeveloperToolsSizeRatio {
  double ratio = [NSUserDefaults.standardUserDefaults doubleForKey:kDeveloperToolsSizeRatioDefaultsKey];
  if (ratio <= 0.0) {
    return 0.38;
  }
  return MIN(0.78, MAX(0.20, ratio));
}

- (BOOL)developerToolsDockModeIsHorizontal {
  return [developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeBottom] ||
         [developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeTop];
}

- (void)navigateSelectedTabBack {
  if (!selectedTab_ || ![selectedTab_ browser] || ![selectedTab_ browser]->CanGoBack()) {
    return;
  }

  [selectedTab_ browser]->GoBack();
}

- (void)navigateSelectedTabForward {
  if (!selectedTab_ || ![selectedTab_ browser] || ![selectedTab_ browser]->CanGoForward()) {
    return;
  }

  [selectedTab_ browser]->GoForward();
}

- (void)reloadSelectedTab {
  if (!selectedTab_ || ![selectedTab_ browser]) {
    return;
  }

  NSString* requestedURLString =
      [self stableServerReloadURLStringForTab:selectedTab_] ?: selectedTab_.requestedURLString;
  if ([self isStableBabelChromeURLString:requestedURLString]) {
    NSString* navigationURLString =
        [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
    if (navigationURLString.length > 0) {
      selectedTab_.requestedURLString = requestedURLString;
      selectedTab_.urlString = navigationURLString;
      selectedTab_.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      [self saveGroupsState];
      return;
    }
  }

  [selectedTab_ browser]->Reload();
}

- (void)reloadSelectedTabFromButton:(id)sender {
  [self reloadSelectedTab];
}

- (void)reloadSelectedTabIgnoringCache {
  if (!selectedTab_ || ![selectedTab_ browser]) {
    return;
  }

  CefRefPtr<CefBrowser> browser = [selectedTab_ browser];
  NSString* requestedURLString =
      [self stableServerReloadURLStringForTab:selectedTab_] ?: selectedTab_.requestedURLString;
  if ([self isStableBabelChromeURLString:requestedURLString]) {
    NSString* navigationURLString =
        [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
    if (navigationURLString.length > 0) {
      selectedTab_.requestedURLString = requestedURLString;
      selectedTab_.urlString = navigationURLString;
      browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      [self saveGroupsState];
    }
  }

  CefRefPtr<CefRequestContext> requestContext = browser->GetHost()->GetRequestContext();
  if (requestContext) {
    requestContext->ClearHttpCache(new BabelReloadIgnoreCacheCallback(browser));
    return;
  }

  browser->ReloadIgnoreCache();
}

- (void)reloadMarkdownViewerTabsUsingCurrentTheme {
  for (BabelBrowserTab* tab in tabs_) {
    if (![[self resolvedViewerKindForStableViewerURLString:tab.requestedURLString] isEqualToString:@"markdown"]) {
      continue;
    }

    NSString* navigationURLString = [self viewerURLStringForSupportedURLString:tab.requestedURLString];
    if (navigationURLString.length == 0) {
      continue;
    }

    tab.urlString = navigationURLString;
    if ([tab browser]) {
      tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
    }
  }

  [self saveGroupsState];
}

- (void)selectTabWithOffset:(NSInteger)offset {
  if (!selectedTab_ || tabs_.count < 2) {
    return;
  }

  NSUInteger currentIndex = [tabs_ indexOfObject:selectedTab_];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSInteger tabCount = (NSInteger)tabs_.count;
  NSInteger nextIndex = ((NSInteger)currentIndex + offset + tabCount) % tabCount;
  [self selectTab:tabs_[(NSUInteger)nextIndex] deferringBrowserCreation:YES];
}

- (void)selectTab:(BabelBrowserTab*)tab {
  [self selectTab:tab deferringBrowserCreation:NO];
}

- (void)selectTab:(BabelBrowserTab*)tab deferringBrowserCreation:(BOOL)deferringBrowserCreation {
  selectedTab_ = tab;
  linkStatusBarView_.hidden = YES;
  selectedGroup_.selectedTabIdentifier = tab.identifier;
  [self touchRecentlyUsedTab:tab];
  for (BabelBrowserTab* currentTab in tabs_) {
    currentTab.hostView.hidden = currentTab != tab;
    currentTab.developerToolsPanelView.hidden = currentTab != tab ||
                                                !currentTab.developerToolsVisible;
    currentTab.tabItemView.selected = currentTab == tab;
    [self layoutBrowserViewsForTab:currentTab];
  }
  [self updateAddressBarForTab:tab];
  [self updateWindowTitleForSelectedTab];
  [self layoutTabItemsSelectingLastTab:NO];
  if (isRestoringSession_) {
    needsInitialRestoredBrowserCreation_ = YES;
    [self saveGroupsState];
    return;
  }

  if (!isTerminating_) {
    if (deferringBrowserCreation) {
      [self scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
    } else {
      ++deferredBrowserCreationGeneration_;
      [self createBrowserForTabIfNeeded:tab];
      [self scheduleAdjacentTabPreloadForSelectedTab];
    }
  }
  [self saveGroupsState];
}

- (void)updateWindowTitleForSelectedTab {
  NSString* pageTitle = selectedTab_.title.length > 0 ? selectedTab_.title : selectedTab_.urlString;
  if (pageTitle.length == 0) {
    self.window.title = BabelChromeConfiguration.applicationName;
    return;
  }

  self.window.title = [NSString stringWithFormat:@"%@ - %@",
                                                 BabelChromeConfiguration.applicationName,
                                                 pageTitle];
}

- (NSString*)displayURLStringForTab:(BabelBrowserTab*)tab {
  if ([self isInternalPageTab:tab]) {
    return tab.requestedURLString ?: @"";
  }

  NSString* urlString = tab.requestedURLString ?: tab.urlString ?: @"";
  return [self displayURLStringForStableViewerURLString:urlString];
}

- (NSDictionary*)addressBadgeForTab:(BabelBrowserTab*)tab {
  NSString* urlString = tab.requestedURLString ?: tab.urlString ?: @"";
  if (![self isStableViewerURLString:urlString]) {
    return nil;
  }

  NSURL* badgeURL = [NSURL URLWithString:urlString];
  NSDictionary* badge = [BabelLocalServiceHost.sharedHost addressBadgeForURL:badgeURL];
  NSString* badgeText = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  if (badgeText.length == 0) {
    return nil;
  }

  return badge;
}

- (NSColor*)colorFromHexString:(NSString*)hexString fallbackColor:(NSColor*)fallbackColor {
  NSString* normalizedHex = [hexString ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([normalizedHex hasPrefix:@"#"]) {
    normalizedHex = [normalizedHex substringFromIndex:1];
  }

  if (normalizedHex.length != 6) {
    return fallbackColor;
  }

  unsigned int colorValue = 0;
  NSScanner* scanner = [NSScanner scannerWithString:normalizedHex];
  if (![scanner scanHexInt:&colorValue]) {
    return fallbackColor;
  }

  CGFloat red = ((colorValue >> 16) & 0xff) / 255.0;
  CGFloat green = ((colorValue >> 8) & 0xff) / 255.0;
  CGFloat blue = (colorValue & 0xff) / 255.0;

  return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}

- (void)layoutAddressTextFieldContent {
  NSRect bounds = addressTextFieldContainer_.bounds;
  BOOL hasBadge = !viewerBadgeLabel_.hidden;
  CGFloat badgeWidth = hasBadge ? 30.0 : 0.0;
  CGFloat leftInset = 8.0;
  CGFloat horizontalGap = hasBadge ? 8.0 : 0.0;
  CGFloat textX = leftInset + badgeWidth + horizontalGap;

  viewerBadgeLabel_.frame = NSMakeRect(leftInset,
                                       6.0,
                                       badgeWidth,
                                       MAX(0.0, bounds.size.height - 12.0));
  urlTextField_.frame = NSMakeRect(textX,
                                   4.0,
                                   MAX(0.0, bounds.size.width - textX - 8.0),
                                   MAX(0.0, bounds.size.height - 8.0));
}

- (void)setAddressBadge:(NSDictionary*)badge {
  NSString* normalizedBadgeString = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  BOOL hasBadge = normalizedBadgeString.length > 0;
  NSString* textColorString = [badge[@"textColor"] isKindOfClass:NSString.class] ? badge[@"textColor"] : @"#ffffff";
  NSString* backgroundColorString = [badge[@"backgroundColor"] isKindOfClass:NSString.class] ? badge[@"backgroundColor"] : @"#000000";
  NSString* settingsRoute = [badge[@"settingsRoute"] isKindOfClass:NSString.class] ? badge[@"settingsRoute"] : @"";
  viewerBadgeLabel_.hidden = !hasBadge;
  viewerBadgeLabel_.settingsRoute = hasBadge ? settingsRoute : @"";
  [viewerBadgeLabel_ configureWithText:normalizedBadgeString
                             textColor:[self colorFromHexString:textColorString fallbackColor:NSColor.whiteColor]
                       backgroundColor:[self colorFromHexString:backgroundColorString fallbackColor:NSColor.clearColor]];
  [self layoutAddressTextFieldContent];
}

- (void)openAddressBadgeSettingsFromMenu:(NSMenuItem*)sender {
  NSString* settingsRoute = [sender.representedObject isKindOfClass:NSString.class]
      ? sender.representedObject
      : @"";
  if (settingsRoute.length == 0) {
    return;
  }

  [self handleInternalNavigationURLString:settingsRoute];
}

- (void)updateAddressBarForTab:(BabelBrowserTab*)tab {
  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:[self addressBadgeForTab:tab]];
  urlTextField_.stringValue = [self displayURLStringForTab:tab];
}

- (void)clearAddressBar {
  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:nil];
  urlTextField_.stringValue = @"";
}

- (NSString*)addressFieldNavigationString {
  NSString* addressString = urlTextField_.stringValue ?: @"";
  if (!selectedTab_) {
    return addressString;
  }

  NSString* displayedURLString = [self displayURLStringForTab:selectedTab_];
  NSString* actualURLString = selectedTab_.requestedURLString ?: selectedTab_.urlString ?: @"";
  if (displayedURLString.length > 0 &&
      actualURLString.length > 0 &&
      [addressString isEqualToString:displayedURLString]) {
    return actualURLString;
  }

  return addressString;
}

- (void)attachCreatedBrowser:(CefRefPtr<CefBrowser>)browser {
  if (browser->IsPopup()) {
    [self attachCreatedPopupBrowser:browser];
    return;
  }

  if (pendingDeveloperToolsTab_) {
    BabelBrowserTab* tab = pendingDeveloperToolsTab_;
    pendingDeveloperToolsTab_ = nil;
    [tab setDeveloperToolsBrowser:browser];
    [tab.developerToolsHostView setBrowser:browser];
    [tab.developerToolsHostView layoutSubtreeIfNeeded];
    return;
  }

  BabelBrowserTab* tab = pendingTabs_.firstObject;
  if (tab) {
    [pendingTabs_ removeObjectAtIndex:0];
  }

  if (!tab) {
    return;
  }

  [tab setBrowser:browser];
  [tab.hostView setBrowser:browser];
  [tab.hostView layoutSubtreeIfNeeded];
  [self enforceLivePageBrowserLimit];
}

- (void)attachCreatedPopupBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = pendingDeveloperToolsTab_;
  pendingDeveloperToolsTab_ = nil;
  if (!tab) {
    return;
  }

  [tab setDeveloperToolsBrowser:browser];
  [tab.developerToolsHostView setBrowser:browser];
  [self reparentDeveloperToolsBrowser:browser intoTab:tab];
  [self layoutBrowserViewsForTab:tab];
}

- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab developerToolsBrowser] && [tab developerToolsBrowser]->IsSame(browser)) {
        [self hideDeveloperToolsForTab:tab];
        return;
      }
    }
  }

  if (browser->IsPopup()) {
    return;
  }

  BabelBrowserTab* tabToRemove = nil;
  BabelBrowserGroup* groupToSelect = nil;
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tabToRemove = tab;
        groupToSelect = group;
        break;
      }
    }
    if (tabToRemove) {
      break;
    }
  }

  if (!tabToRemove) {
    return;
  }

  if ([evictingBrowserTabIdentifiers_ containsObject:tabToRemove.identifier ?: @""]) {
    [evictingBrowserTabIdentifiers_ removeObject:tabToRemove.identifier ?: @""];
    [tabToRemove setBrowser:nullptr];
    [tabToRemove.hostView setBrowser:nullptr];
    return;
  }

  if (groupToSelect && groupToSelect != selectedGroup_) {
    [self selectGroup:groupToSelect];
  }
  [self removeTab:tabToRemove];

  if (isTerminating_ && [self totalTabCount] == 0) {
    CefQuitMessageLoop();
  }
}

- (void)removeSelectedGroupTab:(BabelBrowserTab*)tab {
  [self removeTab:tab fromGroup:selectedGroup_ allowSelection:YES];
}

- (void)removeTab:(BabelBrowserTab*)tab {
  [self removeSelectedGroupTab:tab];
}

- (void)removeTab:(BabelBrowserTab*)tab
        fromGroup:(BabelBrowserGroup*)group
   allowSelection:(BOOL)allowSelection {
  [self closeDeveloperToolsForTab:tab];
  [tab.tabItemView removeFromSuperview];
  [tab.hostView removeFromSuperview];
  [tab.developerToolsPanelView removeFromSuperview];
  [group.tabs removeObject:tab];
  if (group == selectedGroup_) {
    [tabs_ removeObject:tab];
  }
  [pendingTabs_ removeObject:tab];
  [recentlyUsedTabIdentifiers_ removeObject:tab.identifier ?: @""];
  [evictingBrowserTabIdentifiers_ removeObject:tab.identifier ?: @""];

  if (allowSelection && selectedTab_ == tab) {
    selectedTab_ = tabs_.lastObject;
    if (selectedTab_) {
      [self selectTab:selectedTab_];
    } else {
      [self clearAddressBar];
    }
  }

  if (group == selectedGroup_) {
    [self layoutTabItemsSelectingLastTab:NO];
  }
  [self saveGroupsState];
}

- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
                inspectingBrowser:(CefRefPtr<CefBrowser>)browser {
  int port = BabelChromeConfiguration.remoteDebuggingPort;
  NSString* inspectedURLString =
      [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString* targetIdentifier =
        [self developerToolsTargetIdentifierForURLString:inspectedURLString port:port];
    NSString* developerToolsURLString =
        [self developerToolsURLStringForTargetIdentifier:targetIdentifier port:port];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (![self tabForBrowser:browser]) {
        return;
      }

      if ([tab developerToolsBrowser]) {
        [tab developerToolsBrowser]->GetMainFrame()->LoadURL(
            std::string(developerToolsURLString.UTF8String));
        return;
      }

      [self createDeveloperToolsBrowserForTab:tab urlString:developerToolsURLString];
    });
  });
}

- (NSString*)developerToolsURLStringForTargetIdentifier:(NSString*)targetIdentifier
                                                  port:(int)port {
  if (!targetIdentifier) {
    return @"data:text/html,<html><body style='font-family:-apple-system;padding:24px'>"
        "Unable to find the inspected page in the local DevTools target list.</body></html>";
  }

  return [NSString stringWithFormat:
      @"http://127.0.0.1:%d/devtools/inspector.html?ws=127.0.0.1:%d/devtools/page/%@&panel=console",
      port,
      port,
      targetIdentifier];
}

- (void)createDeveloperToolsBrowserForTab:(BabelBrowserTab*)tab
                                urlString:(NSString*)urlString {
  pendingDeveloperToolsTab_ = tab;

  CefWindowInfo windowInfo;
  NSRect bounds = tab.developerToolsHostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.developerToolsHostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings settings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(urlString.UTF8String),
                                settings,
                                nullptr,
                                nullptr);
}

- (NSString*)developerToolsTargetIdentifierForURLString:(NSString*)inspectedURLString
                                                  port:(int)port {
  NSURL* targetsURL = [NSURL URLWithString:
      [NSString stringWithFormat:@"http://127.0.0.1:%d/json/list", port]];
  for (NSUInteger attempt = 0; attempt < 10; attempt++) {
    NSData* data = [NSData dataWithContentsOfURL:targetsURL];
    if (!data) {
      [NSThread sleepForTimeInterval:0.1];
      continue;
    }

    NSError* error = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![payload isKindOfClass:NSArray.class]) {
      [NSThread sleepForTimeInterval:0.1];
      continue;
    }

    NSArray* targets = (NSArray*)payload;
    NSString* fallbackIdentifier = nil;
    for (NSDictionary* target in targets) {
      if (![target isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* type = target[@"type"];
      NSString* urlString = target[@"url"];
      NSString* identifier = target[@"id"];
      if (![type isEqualToString:@"page"] ||
          ![identifier isKindOfClass:NSString.class] ||
          ![urlString isKindOfClass:NSString.class] ||
          [self shouldIgnoreDeveloperToolsTargetURLString:urlString port:port]) {
        continue;
      }

      fallbackIdentifier = identifier;
      if ([urlString isEqualToString:inspectedURLString]) {
        return identifier;
      }
    }

    if (fallbackIdentifier) {
      return fallbackIdentifier;
    }

    [NSThread sleepForTimeInterval:0.1];
  }

  return nil;
}

- (BOOL)shouldIgnoreDeveloperToolsTargetURLString:(NSString*)urlString port:(int)port {
  if ([urlString hasPrefix:@"data:text/html"]) {
    return YES;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  NSInteger targetPort = components.port.integerValue;

  return [components.host isEqualToString:@"127.0.0.1"] &&
         targetPort == port &&
         ([path hasPrefix:@"/devtools/"] || [path isEqualToString:@"/json/list"]);
}

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  [tab setDeveloperToolsBrowser:nullptr];
  [tab.developerToolsHostView setBrowser:nullptr];
  tab.developerToolsSourceWindow = nil;
  tab.developerToolsVisible = NO;
  tab.developerToolsPanelView.hidden = YES;

  NSArray<NSView*>* subviews = [tab.developerToolsHostView.subviews copy];
  for (NSView* subview in subviews) {
    [subview removeFromSuperview];
  }

  [self layoutBrowserViewsForTab:tab];
}

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  CefRefPtr<CefBrowser> developerToolsBrowser = [tab developerToolsBrowser];
  if (developerToolsBrowser) {
    developerToolsBrowser->GetHost()->CloseBrowser(true);
  }
  [self hideDeveloperToolsForTab:tab];
}

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab {
  NSView* developerToolsView = (__bridge NSView*)browser->GetHost()->GetWindowHandle();
  if (!developerToolsView || !tab.developerToolsHostView) {
    return;
  }

  NSWindow* sourceWindow = developerToolsView.window;
  [developerToolsView removeFromSuperview];
  [tab.developerToolsHostView addSubview:developerToolsView];
  developerToolsView.frame = tab.developerToolsHostView.bounds;
  developerToolsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = tab != selectedTab_;

  if (sourceWindow && sourceWindow != self.window) {
    tab.developerToolsSourceWindow = sourceWindow;
    [self hideExternalDeveloperToolsWindow:sourceWindow];
  }
}

- (void)hideExternalDeveloperToolsWindow:(NSWindow*)window {
  if (!window || window == self.window) {
    return;
  }

  [window setReleasedWhenClosed:NO];
  [window setIgnoresMouseEvents:YES];
  [window setHasShadow:NO];
  [window setAlphaValue:0.0];
  [window setOpaque:NO];
  [window setFrame:NSMakeRect(-20000.0, -20000.0, 1.0, 1.0) display:NO];
  [window orderOut:nil];

  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.0];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.2];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.8];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:1.6];
}

- (void)scheduleExternalDeveloperToolsWindowHide:(NSWindow*)window
                                      afterDelay:(NSTimeInterval)delay {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    [window setAlphaValue:0.0];
    [window setFrame:NSMakeRect(-20000.0, -20000.0, 1.0, 1.0) display:NO];
    [window orderOut:nil];
  });
}

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  NSRect bounds = pagesPanel_.bounds;
  if (!tab.developerToolsVisible) {
    tab.hostView.frame = bounds;
    tab.developerToolsPanelView.frame = NSZeroRect;
    return;
  }

  CGFloat developerToolsHeight = [self developerToolsHeightForBounds:bounds];
  CGFloat developerToolsWidth = [self developerToolsWidthForBounds:bounds];

  if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeTop]) {
    tab.hostView.frame = NSMakeRect(0,
                                    0,
                                    bounds.size.width,
                                    MAX(0.0, bounds.size.height - developerToolsHeight));
    tab.developerToolsPanelView.frame = NSMakeRect(0,
                                                   bounds.size.height - developerToolsHeight,
                                                   bounds.size.width,
                                                   developerToolsHeight);
  } else if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeLeft]) {
    tab.developerToolsPanelView.frame = NSMakeRect(0,
                                                   0,
                                                   developerToolsWidth,
                                                   bounds.size.height);
    tab.hostView.frame = NSMakeRect(developerToolsWidth,
                                    0,
                                    MAX(0.0, bounds.size.width - developerToolsWidth),
                                    bounds.size.height);
  } else if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeRight]) {
    tab.hostView.frame = NSMakeRect(0,
                                    0,
                                    MAX(0.0, bounds.size.width - developerToolsWidth),
                                    bounds.size.height);
    tab.developerToolsPanelView.frame = NSMakeRect(bounds.size.width - developerToolsWidth,
                                                   0,
                                                   developerToolsWidth,
                                                   bounds.size.height);
  } else {
    tab.developerToolsPanelView.frame = NSMakeRect(0,
                                                   0,
                                                   bounds.size.width,
                                                   developerToolsHeight);
    tab.hostView.frame = NSMakeRect(0,
                                    developerToolsHeight,
                                    bounds.size.width,
                                    MAX(0.0, bounds.size.height - developerToolsHeight));
  }

  [self layoutDeveloperToolsPanelForTab:tab];
  [tab.hostView layoutSubtreeIfNeeded];
  [tab.developerToolsPanelView layoutSubtreeIfNeeded];
}

- (CGFloat)developerToolsHeightForBounds:(NSRect)bounds {
  CGFloat maximumHeight = MAX(160.0, bounds.size.height - 180.0);
  return MIN(MAX(180.0, bounds.size.height * developerToolsSizeRatio_), maximumHeight);
}

- (CGFloat)developerToolsWidthForBounds:(NSRect)bounds {
  CGFloat maximumWidth = MAX(260.0, bounds.size.width - 360.0);
  return MIN(MAX(320.0, bounds.size.width * developerToolsSizeRatio_), maximumWidth);
}

- (void)layoutDeveloperToolsPanelForTab:(BabelBrowserTab*)tab {
  NSRect panelBounds = tab.developerToolsPanelView.bounds;
  CGFloat toolbarHeight = MIN(kDeveloperToolsToolbarHeight, panelBounds.size.height);
  tab.developerToolsToolbarView.frame = NSMakeRect(0,
                                                   MAX(0.0, panelBounds.size.height - toolbarHeight),
                                                   panelBounds.size.width,
                                                   toolbarHeight);
  if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeTop]) {
    tab.developerToolsResizeHandleView.frame =
        NSMakeRect(0, 0, panelBounds.size.width, kDeveloperToolsResizeHandleThickness);
  } else if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeLeft]) {
    tab.developerToolsResizeHandleView.frame =
        NSMakeRect(MAX(0.0, panelBounds.size.width - kDeveloperToolsResizeHandleThickness),
                   0,
                   kDeveloperToolsResizeHandleThickness,
                   panelBounds.size.height);
  } else if ([developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeRight]) {
    tab.developerToolsResizeHandleView.frame =
        NSMakeRect(0, 0, kDeveloperToolsResizeHandleThickness, panelBounds.size.height);
  } else {
    tab.developerToolsResizeHandleView.frame =
        NSMakeRect(0,
                   MAX(0.0, panelBounds.size.height - kDeveloperToolsResizeHandleThickness),
                   panelBounds.size.width,
                   kDeveloperToolsResizeHandleThickness);
  }
  [tab.developerToolsResizeHandleView.window invalidateCursorRectsForView:tab.developerToolsResizeHandleView];
  tab.developerToolsHostView.frame = NSMakeRect(0,
                                                0,
                                                panelBounds.size.width,
                                                MAX(0.0, panelBounds.size.height - toolbarHeight));
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView
                               positioned:NSWindowBelow
                               relativeTo:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView
                               positioned:NSWindowAbove
                               relativeTo:nil];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView
                               positioned:NSWindowAbove
                               relativeTo:nil];
  [tab.developerToolsHostView layoutSubtreeIfNeeded];
}

- (BOOL)shouldPropagateBrowserClose {
  return isTerminating_;
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        BOOL isGeneratedTitle = [title hasPrefix:@"data:"] || [title containsString:@"data:text"];
        tab.title = title.length > 0 && !isGeneratedTitle ? title : tab.urlString;
        tab.tabItemView.title = [self compactTitleForString:tab.title];
        [self saveGroupsState];
        if (tab == selectedTab_) {
          [self updateWindowTitleForSelectedTab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        if ([urlString hasPrefix:@"data:"]) {
          return;
        }

        tab.urlString = urlString;
        if ([self isStableServerURLString:tab.requestedURLString]) {
          tab.requestedURLString = [self stableServerReloadURLStringForTab:tab];
        } else if (![self isStableBabelChromeURLString:tab.requestedURLString] ||
                   ![self isLocalServiceRuntimeURLString:urlString]) {
          tab.requestedURLString = urlString;
        }
        NSNumber* browserIdentifier = @([tab browser]->GetIdentifier());
        NSArray<NSString*>* pendingRefreshURLStrings =
            pendingRefreshURLStringsByBrowserIdentifier_[browserIdentifier];
        if (pendingRefreshURLStrings.count > 0 &&
            ![self isLocalServiceModuleURLString:urlString]) {
          [pendingRefreshURLStringsByBrowserIdentifier_ removeObjectForKey:browserIdentifier];
          [self reloadRequestedURLStrings:pendingRefreshURLStrings excludingTab:tab];
        }
        NSArray<NSString*>* directRefreshURLStrings =
            [self refreshURLStringsForStableURLString:urlString];
        if (directRefreshURLStrings.count > 0) {
          [self reloadRequestedURLStrings:directRefreshURLStrings excludingTab:tab];
        }
        [self saveGroupsState];
        if (tab == selectedTab_ && !urlTextField_.currentEditor) {
          [self updateAddressBarForTab:tab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || tab != selectedTab_) {
    return;
  }

  NSString* displayedStatusText = statusText ?: @"";
  linkStatusBarLabel_.stringValue = displayedStatusText;
  linkStatusBarView_.hidden = displayedStatusText.length == 0;
  if (!linkStatusBarView_.hidden) {
    [rightView_ addSubview:linkStatusBarView_
                positioned:NSWindowAbove
                relativeTo:pagesPanel_];
  }
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  NSPasteboard* pasteboard = NSPasteboard.generalPasteboard;
  [pasteboard clearContents];
  [pasteboard setString:urlString forType:NSPasteboardTypeString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  if (!faviconImage) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tab.faviconImage = faviconImage;
        tab.tabItemView.faviconImage = faviconImage;
        [self cacheFaviconImage:faviconImage forURLString:tab.urlString];
        return;
      }
    }
  }
}

- (void)cacheFaviconImage:(NSImage*)faviconImage forURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0 || !faviconImage) {
    return;
  }

  faviconImagesByOrigin_[originKey] = faviconImage;
  [self saveFaviconStore];
}

- (NSImage*)faviconImageForURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0) {
    return nil;
  }

  return faviconImagesByOrigin_[originKey];
}

- (NSString*)faviconOriginKeyForURLString:(NSString*)urlString {
  if (urlString.length == 0 ||
      [urlString hasPrefix:@"babelchrome://"] ||
      [urlString hasPrefix:@"data:"] ||
      [urlString hasPrefix:@"view-source:"]) {
    return nil;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (components.scheme.length == 0 || components.host.length == 0) {
    return nil;
  }

  NSString* scheme = components.scheme.lowercaseString;
  NSString* host = components.host.lowercaseString;
  if (components.port) {
    return [NSString stringWithFormat:@"%@://%@:%@", scheme, host, components.port];
  }

  return [NSString stringWithFormat:@"%@://%@", scheme, host];
}

- (void)restoreFaviconStore {
  NSData* data = [NSData dataWithContentsOfURL:BabelChromeConfiguration.faviconStoreFileURL];
  if (data.length == 0) {
    return;
  }

  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSDictionary* icons = [state isKindOfClass:NSDictionary.class] ? state[@"icons"] : nil;
  if (![icons isKindOfClass:NSDictionary.class]) {
    return;
  }

  for (NSString* originKey in icons) {
    NSString* base64Icon = icons[originKey];
    if (![originKey isKindOfClass:NSString.class] ||
        ![base64Icon isKindOfClass:NSString.class]) {
      continue;
    }

    NSData* iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
    NSImage* iconImage = [[NSImage alloc] initWithData:iconData];
    if (!iconImage) {
      continue;
    }

    iconImage.size = NSMakeSize(16.0, 16.0);
    faviconImagesByOrigin_[originKey] = iconImage;
  }
}

- (void)saveFaviconStore {
  NSMutableDictionary<NSString*, NSString*>* encodedIcons = [NSMutableDictionary dictionary];
  for (NSString* originKey in faviconImagesByOrigin_) {
    NSString* base64Icon = [self PNGBase64StringForImage:faviconImagesByOrigin_[originKey]];
    if (base64Icon.length == 0) {
      continue;
    }

    encodedIcons[originKey] = base64Icon;
  }

  NSDictionary* state = @{@"icons": encodedIcons};
  NSURL* storeURL = BabelChromeConfiguration.faviconStoreFileURL;
  [NSFileManager.defaultManager createDirectoryAtURL:storeURL.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:state
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [data writeToURL:storeURL atomically:YES];
}

- (NSString*)PNGBase64StringForImage:(NSImage*)image {
  NSData* TIFFData = image.TIFFRepresentation;
  if (TIFFData.length == 0) {
    return nil;
  }

  NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:TIFFData];
  NSData* PNGData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                           properties:@{}];
  return [PNGData base64EncodedStringWithOptions:0];
}

- (void)navigateFromAddressField:(id)sender {
  if (!selectedTab_) {
    return;
  }

  [self hideOmniboxSuggestions];
  NSString* urlString = [self normalizedURLStringFromAddress:[self addressFieldNavigationString]];
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([self isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      [self updateAddressBarForTab:selectedTab_];
      return;
    }
    navigationURLString = urlString;
  }
  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
    [self saveGroupsState];
    return;
  }

  [self selectTab:selectedTab_];
  [self saveGroupsState];
}

- (void)closeSelectedTab {
  if (!selectedTab_) {
    return;
  }

  [self closeTabFromItem:selectedTab_.tabItemView];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (notification.object == urlTextField_) {
    [self hideOmniboxSuggestions];
  }

  NSNumber* movement = notification.userInfo[@"NSTextMovement"];
  if (movement.integerValue == NSReturnTextMovement) {
    [self navigateFromAddressField:notification.object];
  }
}

- (void)controlTextDidChange:(NSNotification*)notification {
  if (notification.object != urlTextField_) {
    return;
  }

  [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
}

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
doCommandBySelector:(SEL)commandSelector {
  if (control != urlTextField_) {
    return NO;
  }

  if (commandSelector == @selector(moveDown:)) {
    [self selectNextOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(moveUp:)) {
    [self selectPreviousOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(insertNewline:)) {
    if ([self acceptSelectedOmniboxSuggestion]) {
      return YES;
    }
    [self navigateFromAddressField:control];
    return YES;
  }

  if (commandSelector == @selector(cancelOperation:)) {
    [self hideOmniboxSuggestions];
    urlTextField_.stringValue = selectedTab_ ? [self displayURLStringForTab:selectedTab_] : @"";
    return YES;
  }

  return NO;
}

- (void)updateOmniboxSuggestionsForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [omniboxSuggestions_ removeAllObjects];
  selectedOmniboxSuggestionIndex_ = -1;
  ++googleSuggestGeneration_;

  if (trimmedQuery.length == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  NSMutableSet<NSString*>* seenSuggestionKeys = [NSMutableSet set];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab] ||
          (![self omniboxQuery:trimmedQuery matchesTitle:tab.title urlString:tab.urlString] &&
           ![self omniboxQuery:trimmedQuery matchesTitle:tab.title urlString:tab.requestedURLString])) {
        continue;
      }

      [self addOmniboxSuggestionWithTitle:tab.title
                                urlString:tab.urlString ?: tab.requestedURLString
                                groupName:group.name
                            tabIdentifier:tab.identifier
                                    action:@"focus-tab"
                                  seenKeys:seenSuggestionKeys];
      if (omniboxSuggestions_.count >= kOmniboxSuggestionMaximumCount) {
        [self showOmniboxSuggestions];
        [self scheduleGoogleSuggestionsForQuery:trimmedQuery generation:googleSuggestGeneration_];
        return;
      }
    }
  }

  for (NSInteger index = (NSInteger)closedTabs_.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs_[(NSUInteger)index];
    if (![self omniboxQuery:trimmedQuery matchesTitle:closedTab.title urlString:closedTab.urlString] &&
        ![self omniboxQuery:trimmedQuery matchesTitle:closedTab.title urlString:closedTab.requestedURLString]) {
      continue;
    }

    [self addOmniboxSuggestionWithTitle:closedTab.title
                              urlString:closedTab.urlString ?: closedTab.requestedURLString
                              groupName:closedTab.groupName
                          tabIdentifier:nil
                                  action:@"navigate"
                                seenKeys:seenSuggestionKeys];
    if (omniboxSuggestions_.count >= kOmniboxSuggestionMaximumCount) {
      break;
    }
  }

  [self showOmniboxSuggestions];
  [self scheduleGoogleSuggestionsForQuery:trimmedQuery generation:googleSuggestGeneration_];
}

- (BOOL)omniboxQuery:(NSString*)query matchesTitle:(NSString*)title urlString:(NSString*)urlString {
  NSString* normalizedQuery = query.lowercaseString;
  return [[title ?: @"" lowercaseString] containsString:normalizedQuery] ||
         [[urlString ?: @"" lowercaseString] containsString:normalizedQuery];
}

- (void)scheduleGoogleSuggestionsForQuery:(NSString*)query generation:(NSUInteger)generation {
  if (![self googleSuggestEnabled] || query.length < 2) {
    return;
  }

  NSArray<NSString*>* cachedSuggestions = googleSuggestCache_[query.lowercaseString];
  if (cachedSuggestions) {
    [self appendGoogleSuggestions:cachedSuggestions forQuery:query generation:generation];
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kGoogleSuggestDebounceDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != self->googleSuggestGeneration_ ||
        ![query isEqualToString:self->urlTextField_.stringValue]) {
      return;
    }

    [self fetchGoogleSuggestionsForQuery:query generation:generation];
  });
}

- (void)fetchGoogleSuggestionsForQuery:(NSString*)query generation:(NSUInteger)generation {
  NSURL* url = [self googleSuggestURLForQuery:query];
  if (!url) {
    return;
  }

  NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.timeoutIntervalForRequest = 1.5;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
  NSURLSessionDataTask* task =
      [session dataTaskWithURL:url
             completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
    if (error || data.length == 0) {
      [session finishTasksAndInvalidate];
      return;
    }

    NSArray<NSString*>* suggestions = [self googleSuggestionsFromData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
      self->googleSuggestCache_[query.lowercaseString] = suggestions ?: @[];
      [self appendGoogleSuggestions:suggestions ?: @[]
                            forQuery:query
                         generation:generation];
    });
    [session finishTasksAndInvalidate];
  }];
  [task resume];
}

- (NSURL*)googleSuggestURLForQuery:(NSString*)query {
  NSString* encodedQuery = [self googleQueryEscapedString:query];
  if (encodedQuery.length == 0) {
    return nil;
  }

  NSString* urlString =
      [NSString stringWithFormat:@"https://suggestqueries.google.com/complete/search?client=firefox&q=%@",
                                 encodedQuery];
  return [NSURL URLWithString:urlString];
}

- (NSString*)googleQueryEscapedString:(NSString*)query {
  NSMutableCharacterSet* allowedCharacters = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
  [allowedCharacters removeCharactersInString:@"&+=?"];
  return [query stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (NSArray<NSString*>*)googleSuggestionsFromData:(NSData*)data {
  NSError* error = nil;
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error || ![json isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSArray* root = (NSArray*)json;
  if (root.count < 2 || ![root[1] isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* suggestions = [NSMutableArray array];
  for (id value in (NSArray*)root[1]) {
    if (![value isKindOfClass:NSString.class] || [suggestions containsObject:value]) {
      continue;
    }
    [suggestions addObject:value];
  }
  return suggestions;
}

- (void)appendGoogleSuggestions:(NSArray<NSString*>*)suggestions
                       forQuery:(NSString*)query
                    generation:(NSUInteger)generation {
  if (generation != googleSuggestGeneration_ ||
      ![query isEqualToString:urlTextField_.stringValue] ||
      ![self googleSuggestEnabled]) {
    return;
  }

  NSMutableSet<NSString*>* seenSuggestionKeys = [NSMutableSet set];
  for (NSDictionary* suggestion in omniboxSuggestions_) {
    NSString* action = suggestion[@"action"] ?: @"";
    NSString* key = [NSString stringWithFormat:@"%@|%@", action, suggestion[@"url"] ?: @""];
    [seenSuggestionKeys addObject:key];
  }

  for (NSString* suggestion in suggestions) {
    if (omniboxSuggestions_.count >= kOmniboxSuggestionMaximumCount) {
      break;
    }

    [self addOmniboxSuggestionWithTitle:suggestion
                              urlString:[self googleSearchURLStringForQuery:suggestion]
                              groupName:@"Google Search"
                          tabIdentifier:nil
                                  action:@"google-search"
                                seenKeys:seenSuggestionKeys];
  }

  [self showOmniboxSuggestions];
}

- (NSString*)googleSearchURLStringForQuery:(NSString*)query {
  NSString* encodedQuery = [self googleQueryEscapedString:query];
  return [@"https://www.google.com/search?q=" stringByAppendingString:(encodedQuery ?: @"")];
}

- (void)addOmniboxSuggestionWithTitle:(NSString*)title
                            urlString:(NSString*)urlString
                            groupName:(NSString*)groupName
                        tabIdentifier:(NSString*)tabIdentifier
                                action:(NSString*)action
                              seenKeys:(NSMutableSet<NSString*>*)seenKeys {
  if (urlString.length == 0) {
    return;
  }

  NSString* key = [NSString stringWithFormat:@"%@|%@", action ?: @"", tabIdentifier ?: urlString];
  if ([seenKeys containsObject:key]) {
    return;
  }

  [seenKeys addObject:key];
  NSMutableDictionary* suggestion = [@{
    @"title": title.length > 0 ? title : urlString,
    @"url": urlString,
    @"group": groupName.length > 0 ? groupName : kDefaultGroupName,
    @"tabId": tabIdentifier ?: @"",
    @"action": action ?: @"navigate"
  } mutableCopy];
  NSImage* faviconImage = [self faviconImageForSuggestionTitle:title urlString:urlString];
  if (faviconImage) {
    suggestion[@"icon"] = faviconImage;
  }
  [omniboxSuggestions_ addObject:suggestion];
}

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title urlString:(NSString*)urlString {
  NSImage* faviconImage = [self faviconImageForURLString:urlString];
  if (faviconImage) {
    return faviconImage;
  }

  NSString* normalizedTitle = [self normalizedFaviconLookupString:title];
  if (normalizedTitle.length == 0) {
    return nil;
  }

  for (NSString* originKey in faviconImagesByOrigin_) {
    NSString* host = [NSURLComponents componentsWithString:originKey].host.lowercaseString;
    if (host.length == 0) {
      continue;
    }

    NSString* normalizedHost = [self normalizedFaviconHostString:host];
    if (normalizedHost.length > 0 &&
        ([normalizedTitle isEqualToString:normalizedHost] ||
         [normalizedTitle hasPrefix:[normalizedHost stringByAppendingString:@" "]])) {
      return faviconImagesByOrigin_[originKey];
    }
  }

  return nil;
}

- (NSString*)normalizedFaviconLookupString:(NSString*)string {
  NSString* lowercaseString = string.lowercaseString ?: @"";
  NSCharacterSet* charactersToKeep =
      [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789 "];
  NSMutableString* normalizedString = [NSMutableString string];
  BOOL previousWasSpace = YES;
  for (NSUInteger index = 0; index < lowercaseString.length; index++) {
    unichar character = [lowercaseString characterAtIndex:index];
    if (![charactersToKeep characterIsMember:character]) {
      continue;
    }

    if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character]) {
      if (!previousWasSpace) {
        [normalizedString appendString:@" "];
      }
      previousWasSpace = YES;
      continue;
    }

    [normalizedString appendFormat:@"%C", character];
    previousWasSpace = NO;
  }

  return [normalizedString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString*)normalizedFaviconHostString:(NSString*)host {
  NSString* normalizedHost = host.lowercaseString ?: @"";
  if ([normalizedHost hasPrefix:@"www."]) {
    normalizedHost = [normalizedHost substringFromIndex:4];
  }

  NSArray<NSString*>* parts = [normalizedHost componentsSeparatedByString:@"."];
  return parts.count > 0 ? parts.firstObject : normalizedHost;
}

- (void)showOmniboxSuggestions {
  if (omniboxSuggestions_.count == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  [omniboxSuggestionsPanel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  omniboxSuggestionsPanel_.hidden = NO;
  [self layoutInterfaceForCurrentSplitViewSize];

  CGFloat panelWidth = omniboxSuggestionsPanel_.bounds.size.width;
  CGFloat panelHeight = omniboxSuggestionsPanel_.bounds.size.height;
  for (NSUInteger index = 0; index < omniboxSuggestions_.count; index++) {
    NSDictionary* suggestion = omniboxSuggestions_[index];
    BabelOmniboxSuggestionRowView* row =
        [[BabelOmniboxSuggestionRowView alloc] initWithFrame:
            NSMakeRect(0,
                       panelHeight - (kOmniboxSuggestionRowHeight * (index + 1)),
                       panelWidth,
                       kOmniboxSuggestionRowHeight)];
    row.target = self;
    row.action = @selector(selectOmniboxSuggestionFromRow:);
    row.tag = (NSInteger)index;
    row.suggestionHighlighted = (NSInteger)index == selectedOmniboxSuggestionIndex_;
    NSImage* iconImage = [suggestion[@"icon"] isKindOfClass:NSImage.class] ? suggestion[@"icon"] : nil;
    [row configureWithTitle:suggestion[@"title"]
                   subtitle:[NSString stringWithFormat:@"%@ - %@",
                                                       suggestion[@"group"],
                                                       suggestion[@"url"]]
                  iconImage:iconImage];
    [omniboxSuggestionsPanel_ addSubview:row];
  }
}

- (void)hideOmniboxSuggestions {
  [omniboxSuggestions_ removeAllObjects];
  selectedOmniboxSuggestionIndex_ = -1;
  omniboxSuggestionsPanel_.hidden = YES;
  [omniboxSuggestionsPanel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)selectNextOmniboxSuggestion {
  if (omniboxSuggestions_.count == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if (omniboxSuggestions_.count == 0) {
    return;
  }

  selectedOmniboxSuggestionIndex_ =
      (selectedOmniboxSuggestionIndex_ + 1) % (NSInteger)omniboxSuggestions_.count;
  [self refreshOmniboxSuggestionHighlight];
}

- (void)selectPreviousOmniboxSuggestion {
  if (omniboxSuggestions_.count == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if (omniboxSuggestions_.count == 0) {
    return;
  }

  selectedOmniboxSuggestionIndex_ = selectedOmniboxSuggestionIndex_ <= 0
      ? (NSInteger)omniboxSuggestions_.count - 1
      : selectedOmniboxSuggestionIndex_ - 1;
  [self refreshOmniboxSuggestionHighlight];
}

- (void)refreshOmniboxSuggestionHighlight {
  for (NSView* view in omniboxSuggestionsPanel_.subviews) {
    if (![view isKindOfClass:BabelOmniboxSuggestionRowView.class]) {
      continue;
    }

    BabelOmniboxSuggestionRowView* row = (BabelOmniboxSuggestionRowView*)view;
    row.suggestionHighlighted = row.tag == selectedOmniboxSuggestionIndex_;
  }
}

- (void)selectOmniboxSuggestionFromRow:(BabelOmniboxSuggestionRowView*)row {
  selectedOmniboxSuggestionIndex_ = row.tag;
  [self acceptSelectedOmniboxSuggestion];
}

- (BOOL)acceptSelectedOmniboxSuggestion {
  if (selectedOmniboxSuggestionIndex_ < 0 ||
      selectedOmniboxSuggestionIndex_ >= (NSInteger)omniboxSuggestions_.count) {
    return NO;
  }

  NSDictionary* suggestion = omniboxSuggestions_[(NSUInteger)selectedOmniboxSuggestionIndex_];
  NSString* action = suggestion[@"action"];
  if ([action isEqualToString:@"focus-tab"]) {
    NSString* tabIdentifier = suggestion[@"tabId"];
    for (BabelBrowserGroup* group in groups_) {
      BabelBrowserTab* tab = [self tabWithIdentifier:tabIdentifier inGroup:group];
      if (!tab) {
        continue;
      }

      [self hideOmniboxSuggestions];
      [self selectGroup:group];
      [self selectTab:tab];
      [self showMainWindow];
      return YES;
    }
  }

  NSString* urlString = suggestion[@"url"];
  if (urlString.length == 0) {
    return NO;
  }

  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:nil];
  urlTextField_.stringValue = urlString;
  [self hideOmniboxSuggestions];
  [self navigateFromAddressField:urlTextField_];
  return YES;
}

- (NSString*)normalizedURLStringFromAddress:(NSString*)address {
  NSString* trimmedAddress = [address stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedAddress.length == 0) {
    return BabelChromeConfiguration.defaultURLString;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:trimmedAddress];
  if (components.scheme.length > 0) {
    return trimmedAddress;
  }

  if ([trimmedAddress containsString:@"."] || [trimmedAddress hasPrefix:@"localhost"]) {
    return [@"https://" stringByAppendingString:trimmedAddress];
  }

  NSString* encodedQuery =
      [trimmedAddress stringByAddingPercentEncodingWithAllowedCharacters:
                          NSCharacterSet.URLQueryAllowedCharacterSet];
  return [@"https://www.google.com/search?q=" stringByAppendingString:(encodedQuery ?: @"")];
}

- (NSString*)compactTitleForString:(NSString*)value {
  if (value.length <= 28) {
    return value;
  }
  return [[value substringToIndex:25] stringByAppendingString:@"..."];
}

- (void)layoutTabItemsSelectingLastTab:(BOOL)selectLastTab {
  CGFloat availableWidth = tabsItemsPanel_.bounds.size.width;
  NSUInteger tabCount = tabs_.count;
  NSColor* accentColor = [self accentColorForGroup:selectedGroup_];
  CGFloat activeWidth = tabCount > 1 ? MIN(kTabActiveWidth, availableWidth) :
                                       MIN(kTabNormalWidth, availableWidth);
  CGFloat inactiveWidth = kTabNormalWidth;

  if (tabCount > 1) {
    CGFloat spacingWidth = kTabSpacing * (CGFloat)(tabCount - 1);
    CGFloat activeMaximumWidth = availableWidth - spacingWidth -
                                 (kTabMinimumWidth * (CGFloat)(tabCount - 1));
    activeWidth = MIN(availableWidth, MAX(kTabNormalWidth, MIN(kTabActiveWidth, activeMaximumWidth)));

    CGFloat inactiveAvailableWidth = MAX(0.0, availableWidth - activeWidth - spacingWidth);
    inactiveWidth = inactiveAvailableWidth / (CGFloat)(tabCount - 1);
    inactiveWidth = MIN(kTabNormalWidth, inactiveWidth);
    if (inactiveWidth < kTabMinimumWidth) {
      inactiveWidth = MAX(18.0, inactiveWidth);
    }
  }

  CGFloat x = 0.0;
  for (BabelBrowserTab* tab in tabs_) {
    CGFloat tabWidth = tab == selectedTab_ ? activeWidth : inactiveWidth;
    tab.tabItemView.accentColor = accentColor;
    tab.tabItemView.frame = NSMakeRect(x, 1.0, tabWidth, kTabHeight);
    x += tabWidth + kTabSpacing;
  }
}

- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group {
  NSArray<NSColor*>* palette = [BabelTheme.sharedTheme colorListForToken:@"group.accentPalette"
                                                                    view:rootView_ ?: self.window.contentView];
  if (palette.count == 0) {
    palette = @[NSColor.controlAccentColor];
  }

  NSUInteger groupIndex = [groups_ indexOfObject:group];
  if (groupIndex == NSNotFound) {
    return palette.firstObject;
  }
  return palette[groupIndex % palette.count];
}

- (void)layoutGroupItems {
  CGFloat y = 0.0;
  CGFloat width = MAX(0.0, groupsListView_.bounds.size.width);
  for (BabelBrowserGroup* group in groups_) {
    group.groupItemView.accentColor = [self accentColorForGroup:group];
    group.groupItemView.collapsed = sidebarCollapsed_;
    group.groupItemView.frame = NSMakeRect(0, y, width, 30);
    y += 34.0;
  }
}

- (NSUInteger)totalTabCount {
  NSUInteger tabCount = 0;
  for (BabelBrowserGroup* group in groups_) {
    tabCount += group.tabs.count;
  }
  return tabCount;
}

- (CGFloat)sidebarWidth {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [self normalizedExpandedSidebarWidth:expandedSidebarWidth_];
}

- (CGFloat)restoredExpandedSidebarWidth {
  double storedWidth = [NSUserDefaults.standardUserDefaults doubleForKey:kSidebarWidthDefaultsKey];
  CGFloat width = storedWidth > 0.0 ? (CGFloat)storedWidth : kSidebarInitialWidth;
  return [self normalizedExpandedSidebarWidth:width];
}

- (CGFloat)normalizedExpandedSidebarWidth:(CGFloat)width {
  return MIN(kSidebarMaximumWidth, MAX([self minimumExpandedSidebarWidth], width));
}

- (void)saveExpandedSidebarWidth:(CGFloat)width {
  expandedSidebarWidth_ = [self normalizedExpandedSidebarWidth:width];
  [NSUserDefaults.standardUserDefaults setDouble:expandedSidebarWidth_ forKey:kSidebarWidthDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (CGFloat)minimumExpandedSidebarWidth {
  CGFloat titleWidth = sidebarTitle_ ? [sidebarTitle_ intrinsicContentSize].width : 0.0;
  return kSidebarHeaderLeadingInset + kSidebarHeaderButtonSize + kSidebarHeaderButtonGap +
      titleWidth + kSidebarHeaderButtonGap + kSidebarHeaderButtonSize + kSidebarHeaderTrailingInset;
}

- (CGFloat)targetSidebarWidth {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [self normalizedExpandedSidebarWidth:expandedSidebarWidth_];
}

- (void)restoreMainWindowFrame {
  NSString* frameString =
      [NSUserDefaults.standardUserDefaults stringForKey:kMainWindowFrameDefaultsKey];
  if (frameString.length == 0) {
    [self.window center];
    return;
  }

  NSRect frame = NSRectFromString(frameString);
  if (![self mainWindowFrameIsVisible:frame]) {
    [self.window center];
    return;
  }

  [self.window setFrame:frame display:NO];
}

- (void)restoreMainWindowZoomStateIfNeeded {
  if (didRestoreMainWindowState_) {
    return;
  }

  didRestoreMainWindowState_ = YES;
  if ([NSUserDefaults.standardUserDefaults boolForKey:kMainWindowZoomedDefaultsKey] &&
      !self.window.isZoomed) {
    [self.window zoom:nil];
  }
}

- (BOOL)mainWindowFrameIsVisible:(NSRect)frame {
  if (NSIsEmptyRect(frame) || frame.size.width < 200.0 || frame.size.height < 200.0) {
    return NO;
  }

  for (NSScreen* screen in NSScreen.screens) {
    if (NSIntersectsRect(frame, screen.visibleFrame)) {
      return YES;
    }
  }
  return NO;
}

- (void)saveMainWindowState {
  if (!self.window) {
    return;
  }

  [NSUserDefaults.standardUserDefaults setBool:self.window.isZoomed
                                        forKey:kMainWindowZoomedDefaultsKey];
  if (!self.window.isZoomed && !self.window.isMiniaturized) {
    [NSUserDefaults.standardUserDefaults setObject:NSStringFromRect(self.window.frame)
                                            forKey:kMainWindowFrameDefaultsKey];
  }
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)applyThemeColors {
  BabelTheme* theme = BabelTheme.sharedTheme;
  rootView_.appearance = [theme forcedAppearance];
  sidebarView_.layer.backgroundColor = [theme cgColorForToken:@"sidebar.background" view:sidebarView_];
  rightView_.layer.backgroundColor = [theme cgColorForToken:@"address.panel.background" view:rightView_];
  tabsBarPanel_.layer.backgroundColor = [theme cgColorForToken:@"tabsBar.background" view:tabsBarPanel_];
  addressBarPanel_.layer.backgroundColor =
      [theme cgColorForToken:@"address.panel.background" view:addressBarPanel_];
  addressLabel_.textColor = [theme colorForToken:@"address.title" view:addressLabel_];
  addressTextFieldContainer_.layer.backgroundColor =
      [theme cgColorForToken:@"address.container.background" view:addressTextFieldContainer_];
  addressTextFieldContainer_.layer.borderColor =
      [theme cgColorForToken:@"address.border" view:addressTextFieldContainer_];
  urlTextField_.textColor = [theme colorForToken:@"address.text" view:urlTextField_];
  omniboxSuggestionsPanel_.layer.backgroundColor =
      [theme cgColorForToken:@"omnibox.panel.background" view:omniboxSuggestionsPanel_];
  omniboxSuggestionsPanel_.layer.borderColor =
      [theme cgColorForToken:@"omnibox.border" view:omniboxSuggestionsPanel_];
  linkStatusBarView_.layer.backgroundColor =
      [theme cgColorForToken:@"linkStatus.background" view:linkStatusBarView_];
  linkStatusBarView_.layer.borderColor =
      [theme cgColorForToken:@"linkStatus.border" view:linkStatusBarView_];
  linkStatusBarLabel_.textColor = [theme colorForToken:@"linkStatus.text" view:linkStatusBarLabel_];

  for (BabelBrowserGroup* group in groups_) {
    [group.groupItemView setNeedsDisplay:YES];
    for (BabelBrowserTab* tab in group.tabs) {
      tab.developerToolsPanelView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.panel.background" view:tab.developerToolsPanelView];
      tab.developerToolsToolbarView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.toolbar.background" view:tab.developerToolsToolbarView];
      tab.developerToolsResizeHandleView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.handle.background" view:tab.developerToolsResizeHandleView];
      tab.developerToolsHostView.layer.backgroundColor =
          [theme cgColorForToken:@"developerTools.panel.background" view:tab.developerToolsHostView];
      [tab.developerToolsResizeHandleView setNeedsDisplay:YES];
      [tab.tabItemView setNeedsDisplay:YES];
    }
  }

  for (NSView* suggestionRow in omniboxSuggestionsPanel_.subviews) {
    if ([suggestionRow respondsToSelector:@selector(setSuggestionHighlighted:)]) {
      [suggestionRow setNeedsDisplay:YES];
    }
  }
}

- (void)layoutInterfaceForCurrentSplitViewSize {
  if (!rootView_ || !splitView_ || !sidebarView_ || !rightView_) {
    return;
  }

  CGFloat rootWidth = rootView_.bounds.size.width;
  CGFloat rootHeight = rootView_.bounds.size.height;
  tabsBarPanel_.frame = NSMakeRect(0,
                                   MAX(0.0, rootHeight - kTabBarHeight),
                                   rootWidth,
                                   kTabBarHeight);
  tabsItemsPanel_.frame = NSMakeRect(kTitlebarTabLeadingInset,
                                     4,
                                     MAX(0.0, rootWidth - kTitlebarTabLeadingInset -
                                              kNewTabButtonWidth - 14),
                                     34);
  newTabButton_.frame = NSMakeRect(MAX(kTitlebarTabLeadingInset,
                                       rootWidth - kNewTabButtonWidth - 6),
                                   6,
                                   28,
                                   28);
  splitView_.frame = NSMakeRect(0, 0, rootWidth, MAX(0.0, rootHeight - kTabBarHeight));

  CGFloat dividerThickness = splitView_.dividerThickness;
  CGFloat sidebarWidth = [self sidebarWidth];
  CGFloat totalWidth = splitView_.bounds.size.width;
  CGFloat totalHeight = splitView_.bounds.size.height;
  CGFloat rightWidth = MAX(0.0, totalWidth - sidebarWidth - dividerThickness);

  sidebarView_.frame = NSMakeRect(0, 0, sidebarWidth, totalHeight);
  sidebarTitle_.hidden = sidebarCollapsed_;
  newGroupButton_.hidden = sidebarCollapsed_;
  CGFloat headerY = MAX(0.0, totalHeight - 42);
  CGFloat collapseButtonX = sidebarCollapsed_
      ? MAX(0.0, (sidebarWidth - kSidebarHeaderButtonSize) / 2.0)
      : kSidebarHeaderLeadingInset;
  sidebarCollapseButton_.frame = NSMakeRect(collapseButtonX,
                                            headerY,
                                            kSidebarHeaderButtonSize,
                                            kSidebarHeaderButtonSize);
  sidebarCollapseButton_.toolTip = sidebarCollapsed_ ? @"Expand Sidebar" : @"Collapse Sidebar";
  ConfigureIconButton(sidebarCollapseButton_,
                      sidebarCollapsed_ ? @"collapse-right" : @"collapse-left",
                      sidebarCollapsed_ ? @">>" : @"<<");
  CGFloat titleX = collapseButtonX + kSidebarHeaderButtonSize + kSidebarHeaderButtonGap;
  CGFloat titleIntrinsicWidth = [sidebarTitle_ intrinsicContentSize].width;
  CGFloat titleRightEdge = titleX + titleIntrinsicWidth;
  CGFloat minimumAddButtonX = titleRightEdge + kSidebarHeaderButtonGap;
  CGFloat addButtonX =
      MAX(minimumAddButtonX, sidebarWidth - kSidebarHeaderButtonSize - kSidebarHeaderTrailingInset);
  newGroupButton_.frame = NSMakeRect(addButtonX,
                                     headerY,
                                     kSidebarHeaderButtonSize,
                                     kSidebarHeaderButtonSize);
  CGFloat titleAvailableWidth = MAX(0.0, addButtonX - titleX - kSidebarHeaderButtonGap);
  sidebarTitle_.frame = NSMakeRect(titleX,
                                   MAX(0.0, totalHeight - 40),
                                   MIN(titleIntrinsicWidth, titleAvailableWidth),
                                   24);
  CGFloat groupListX = sidebarCollapsed_ ? 5.0 : 5.0;
  CGFloat groupListY = sidebarCollapsed_ ? 12.0 : 24.0;
  CGFloat groupListBottomInset = sidebarCollapsed_ ? 12.0 : 24.0;
  CGFloat groupListTopInset = sidebarCollapsed_ ? 58.0 : 72.0;
  groupsListView_.frame = NSMakeRect(groupListX,
                                     groupListY,
                                     MAX(0.0, sidebarWidth - (groupListX * 2.0)),
                                     MAX(0.0, totalHeight - groupListTopInset - groupListBottomInset));
  [sidebarView_ addSubview:sidebarCollapseButton_ positioned:NSWindowAbove relativeTo:nil];
  [sidebarView_ addSubview:newGroupButton_ positioned:NSWindowAbove relativeTo:nil];
  [self layoutGroupItems];
  rightView_.frame = NSMakeRect(sidebarWidth + dividerThickness, 0, rightWidth, totalHeight);
  addressBarPanel_.frame = NSMakeRect(0,
                                      totalHeight - kToolbarHeight,
                                      rightWidth,
                                      kToolbarHeight);
  addressLabel_.frame = NSMakeRect(12, 12, 30, 18);
  CGFloat addressFieldX = 50.0;
  CGFloat reloadButtonWidth = 28.0;
  CGFloat reloadButtonRightInset = 8.0;
  CGFloat reloadButtonGap = 6.0;
  CGFloat reloadButtonX = MAX(addressFieldX,
                              rightWidth - reloadButtonRightInset - reloadButtonWidth);
  reloadButton_.frame = NSMakeRect(reloadButtonX, 8, reloadButtonWidth, reloadButtonWidth);
  CGFloat addressFieldWidth = MAX(0.0, reloadButtonX - addressFieldX - reloadButtonGap);
  addressTextFieldContainer_.frame = NSMakeRect(addressFieldX, 7, addressFieldWidth, 30);
  [self layoutAddressTextFieldContent];
  CGFloat suggestionsHeight = omniboxSuggestionsPanel_.hidden
      ? 0.0
      : MIN(kOmniboxSuggestionPanelMaximumHeight,
            kOmniboxSuggestionRowHeight * omniboxSuggestions_.count);
  omniboxSuggestionsPanel_.frame = NSMakeRect(addressFieldX,
                                              MAX(0.0, totalHeight - kToolbarHeight -
                                                           suggestionsHeight - 2.0),
                                              addressFieldWidth,
                                              suggestionsHeight);
  [rightView_ addSubview:omniboxSuggestionsPanel_
              positioned:NSWindowAbove
              relativeTo:pagesPanel_];
  pagesPanel_.frame = NSMakeRect(0,
                                 0,
                                 rightWidth,
                                 MAX(0.0, totalHeight - kToolbarHeight));
  CGFloat linkStatusBarWidth =
      MIN(kLinkStatusBarMaximumWidth, MAX(220.0, rightWidth - 16.0));
  linkStatusBarView_.frame = NSMakeRect(8.0,
                                        8.0,
                                        linkStatusBarWidth,
                                        kLinkStatusBarHeight);
  linkStatusBarLabel_.frame = NSMakeRect(8.0,
                                         4.0,
                                         MAX(0.0, linkStatusBarWidth - 16.0),
                                         16.0);
  [rightView_ addSubview:linkStatusBarView_
              positioned:NSWindowAbove
              relativeTo:pagesPanel_];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      [self layoutBrowserViewsForTab:tab];
    }
  }
  [self layoutTabItemsSelectingLastTab:NO];
}

- (void)requestApplicationTermination {
  if (isTerminating_) {
    return;
  }

  isTerminating_ = YES;
  [self saveMainWindowState];
  [self dispatchApplicationWillQuitModuleLifecycleHook];
  [BabelLocalServiceHost.sharedHost stop];
  [pendingTabs_ removeAllObjects];
  [evictingBrowserTabIdentifiers_ removeAllObjects];

  if ([self totalTabCount] == 0) {
    CefQuitMessageLoop();
    return;
  }

  [self closeAllBrowsersForTermination];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (isTerminating_) {
      CefQuitMessageLoop();
    }
  });
}

- (CGFloat)splitView:(NSSplitView*)splitView
    constrainMinCoordinate:(CGFloat)proposedMinimumPosition
              ofSubviewAt:(NSInteger)dividerIndex {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [self minimumExpandedSidebarWidth];
}

- (CGFloat)splitView:(NSSplitView*)splitView
    constrainSplitPosition:(CGFloat)proposedPosition
               ofSubviewAt:(NSInteger)dividerIndex {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  CGFloat normalizedPosition = [self normalizedExpandedSidebarWidth:proposedPosition];
  if (!isBuildingInterface_) {
    expandedSidebarWidth_ = normalizedPosition;
  }
  return normalizedPosition;
}

- (CGFloat)splitView:(NSSplitView*)splitView
    constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
              ofSubviewAt:(NSInteger)dividerIndex {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return kSidebarMaximumWidth;
}

- (void)splitView:(NSSplitView*)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
  [self layoutInterfaceForCurrentSplitViewSize];
  if (!isBuildingInterface_ && !sidebarCollapsed_) {
    [self saveExpandedSidebarWidth:expandedSidebarWidth_];
  }
}

- (void)windowDidResize:(NSNotification*)notification {
  [self layoutInterfaceForCurrentSplitViewSize];
  [self saveMainWindowState];
}

- (void)windowDidMove:(NSNotification*)notification {
  [self saveMainWindowState];
}

- (void)closeAllBrowsersForTermination {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in [group.tabs copy]) {
      if ([tab developerToolsBrowser]) {
        [tab developerToolsBrowser]->GetHost()->CloseBrowser(true);
      }
      if ([tab browser]) {
        [tab browser]->GetHost()->CloseBrowser(true);
      }
    }
  }
}

- (BOOL)windowShouldClose:(NSWindow*)sender {
  [self requestApplicationTermination];
  return NO;
}

@end
