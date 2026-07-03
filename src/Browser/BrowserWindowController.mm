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
static const CGFloat kSidebarTitleRenderPadding = 4.0;
static const CGFloat kSidebarMaximumWidth = 360.0;
static const CGFloat kSidebarCollapsedWidth = 48.0;
static const CGFloat kWindowFrameComparisonTolerance = 2.0;
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
static NSString* const kLongQuitShortcutEnabledDefaultsKey = @"LongQuitShortcutEnabled";
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

@interface BabelMainWindow : NSWindow

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

@implementation BabelBrowserWindowController {
  NSView* rootView_;
  NSView* splitView_;
  NSView* sidebarView_;
  BabelDeveloperToolsResizeHandleView* sidebarResizeHandleView_;
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
      [[BabelMainWindow alloc] initWithContentRect:frame
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
    [self restoreProfileExtensionsMovedByOlderVersions];
    [self clearPendingProfileExtensionRestartStates];
    window.delegate = self;
    [self buildInterface];
    [self restoreFaviconStore];
    [self restoreSessionByPriority];
  }
  return self;
}

- (void)restoreSessionByPriority {
  [self restoreSessionPositionState];

  NSData* stateData = [self persistedGroupsAndTabsStateData];
  NSDictionary* state = [self persistedGroupsAndTabsStateFromData:stateData];

  isRestoringSession_ = YES;
  [self restoreSessionTabsFromState:state];
  [self restoreSessionGroupsFromState:state];
  isRestoringSession_ = NO;

  [self restoreSessionInitialBrowsers];
  [self restoreSessionModulesLifecycle];
}

- (void)restoreSessionPositionState {
  [self restoreSessionWindowFrame];
  [self restoreSessionSidebarState];
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
  [self layoutInterfaceForCurrentSplitViewSize];
  isBuildingInterface_ = previousBuildingState;
}

- (void)restoreSessionSidebarAfterInitialLayout {
  [self restoreSessionSidebarState];
  [self applySessionSidebarDividerPosition];
}

- (void)restoreSessionInitialBrowsers {
  [self createInitialRestoredBrowserIfNeeded];
}

- (void)restoreSessionModulesLifecycle {
  [self dispatchApplicationDidStartModuleLifecycleHook];
}

- (void)maximizeWindowToVisibleFrame:(id)sender {
  NSScreen* screen = self.window.screen ?: NSScreen.mainScreen;
  if (!screen) {
    return;
  }

  [self.window setFrame:screen.visibleFrame display:YES animate:YES];
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

  splitView_ = [[NSView alloc] initWithFrame:rootView_.bounds];
  splitView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  sidebarView_ = [[BabelNonMovableView alloc] initWithFrame:NSMakeRect(0, 0, kSidebarInitialWidth, 820)];
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

  groupsListView_ = [[BabelNonMovableFlippedView alloc] initWithFrame:NSMakeRect(5, 24, 230, 740)];
  groupsListView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [sidebarView_ addSubview:groupsListView_];

  sidebarResizeHandleView_ =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSMakeRect(initialSidebarWidth, 0, 7, 820)];
  sidebarResizeHandleView_.resizeTarget = self;
  sidebarResizeHandleView_.resizeAction = @selector(resizeSidebarFromHandle:);

  rightView_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 820)];
  rightView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  rightView_.wantsLayer = YES;

  BabelTitlebarView* tabsBarPanel =
      [[BabelTitlebarView alloc] initWithFrame:NSMakeRect(0, 780, 1040, kTabBarHeight)];
  tabsBarPanel.doubleClickTarget = self;
  tabsBarPanel.doubleClickAction = @selector(maximizeWindowToVisibleFrame:);
  tabsBarPanel_ = tabsBarPanel;
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
  [rootView_ addSubview:sidebarResizeHandleView_ positioned:NSWindowAbove relativeTo:splitView_];
  [self.window setContentView:rootView_];
  [self applyThemeColors];
  [self layoutInterfaceForCurrentSplitViewSize];
  isBuildingInterface_ = NO;
}

- (NSData*)persistedGroupsAndTabsStateData {
  return [NSData dataWithContentsOfURL:BabelChromeConfiguration.groupsStateFileURL];
}

- (NSDictionary*)persistedGroupsAndTabsStateFromData:(NSData*)data {
  if (data.length == 0) {
    return @{};
  }

  NSError* error = nil;
  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&error];
  return [state isKindOfClass:NSDictionary.class] ? state : @{};
}

- (void)restoreSessionTabsFromState:(NSDictionary*)state {
  [self restoreGroupsFromState:state];
}

- (void)restoreSessionGroupsFromState:(NSDictionary*)state {
  BabelBrowserGroup* defaultGroup = [self groupWithIdentifier:kDefaultGroupIdentifier];
  if (!defaultGroup) {
    defaultGroup = [self createGroupWithName:kDefaultGroupName identifier:kDefaultGroupIdentifier];
  }

  NSString* selectedGroupIdentifier = [self persistedSelectedGroupIdentifierFromState:state];
  BabelBrowserGroup* groupToSelect = [self groupWithIdentifier:selectedGroupIdentifier] ?: defaultGroup;
  [self selectGroup:groupToSelect];
  [self saveGroupsState];
}

- (NSString*)persistedSelectedGroupIdentifierFromState:(NSDictionary*)state {
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

#include "BrowserWindowController+InternalPages.inc.mm"

#include "BrowserWindowController+BrowserControls.inc.mm"

#include "BrowserWindowController+SelectionAddressOmnibox.inc.mm"

#include "BrowserWindowController+LayoutWindowLifecycle.inc.mm"

@end
