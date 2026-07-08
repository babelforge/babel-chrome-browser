#import "Browser/Window/Layout/MainWindowViewFactory.h"

#import "Browser/UI/Views/BrowserSupportViews.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelMainWindowViewSet

@synthesize rootView;
@synthesize splitView;
@synthesize sidebarView;
@synthesize sidebarResizeHandleView;
@synthesize sidebarTitle;
@synthesize sidebarCollapseButton;
@synthesize groupAddButton;
@synthesize groupsListView;
@synthesize rightView;
@synthesize tabsBarPanel;
@synthesize tabsItemsPanel;
@synthesize tabAddButton;
@synthesize addressBarPanel;
@synthesize addressLabel;
@synthesize addressTextFieldContainer;
@synthesize urlTextField;
@synthesize viewerBadgeLabel;
@synthesize reloadButton;
@synthesize omniboxSuggestionsPanel;
@synthesize pagesPanel;
@synthesize linkStatusBarView;
@synthesize linkStatusBarLabel;

@end

@implementation BabelMainWindowViewFactory

- (BabelMainWindowViewSet*)viewSetWithWindowBounds:(NSRect)windowBounds
                                            target:(id)target
                               initialSidebarWidth:(CGFloat)initialSidebarWidth
                                      tabBarHeight:(CGFloat)tabBarHeight
                                     toolbarHeight:(CGFloat)toolbarHeight
                           sidebarHeaderButtonSize:(CGFloat)sidebarHeaderButtonSize
                         sidebarHeaderLeadingInset:(CGFloat)sidebarHeaderLeadingInset
                            sidebarHeaderButtonGap:(CGFloat)sidebarHeaderButtonGap
                               linkStatusBarHeight:(CGFloat)linkStatusBarHeight {
  BabelMainWindowViewSet* viewSet = [[BabelMainWindowViewSet alloc] init];

  BabelThemeRootView* themeRootView = [[BabelThemeRootView alloc] initWithFrame:windowBounds];
  themeRootView.themeTarget = target;
  themeRootView.themeAction = @selector(applyThemeColors);
  themeRootView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  viewSet.rootView = themeRootView;

  viewSet.splitView = [[NSView alloc] initWithFrame:viewSet.rootView.bounds];
  viewSet.splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  viewSet.sidebarView = [[BabelNonMovableView alloc] initWithFrame:NSMakeRect(0, 0, initialSidebarWidth, 820)];
  viewSet.sidebarView.wantsLayer = YES;

  viewSet.sidebarTitle = [NSTextField labelWithString:@"BabelForge"];
  viewSet.sidebarTitle.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  [viewSet.sidebarTitle sizeToFit];
  viewSet.sidebarTitle.frame =
      NSMakeRect(sidebarHeaderLeadingInset + sidebarHeaderButtonSize + sidebarHeaderButtonGap,
                 780,
                 viewSet.sidebarTitle.frame.size.width,
                 24);
  viewSet.sidebarTitle.autoresizingMask = NSViewMinYMargin;
  [viewSet.sidebarView addSubview:viewSet.sidebarTitle];

  viewSet.sidebarCollapseButton = BabelButton(@"", target, @selector(toggleSidebarCollapsed:));
  viewSet.sidebarCollapseButton.bezelStyle = NSBezelStyleTexturedRounded;
  viewSet.sidebarCollapseButton.toolTip = @"Collapse Sidebar";
  [viewSet.sidebarView addSubview:viewSet.sidebarCollapseButton];

  viewSet.groupAddButton = BabelButton(@"+", target, @selector(addGroupFromButton:));
  viewSet.groupAddButton.bezelStyle = NSBezelStyleTexturedRounded;
  viewSet.groupAddButton.font = [NSFont systemFontOfSize:17 weight:NSFontWeightRegular];
  viewSet.groupAddButton.toolTip = @"New Group";
  viewSet.groupAddButton.frame =
      NSMakeRect(200, 778, sidebarHeaderButtonSize, sidebarHeaderButtonSize);
  viewSet.groupAddButton.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
  [viewSet.sidebarView addSubview:viewSet.groupAddButton];

  viewSet.groupsListView = [[BabelNonMovableFlippedView alloc] initWithFrame:NSMakeRect(5, 24, 230, 740)];
  viewSet.groupsListView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [viewSet.sidebarView addSubview:viewSet.groupsListView];

  viewSet.sidebarResizeHandleView =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSMakeRect(initialSidebarWidth, 0, 7, 820)];
  viewSet.sidebarResizeHandleView.resizeTarget = target;
  viewSet.sidebarResizeHandleView.resizeAction = @selector(resizeSidebarFromHandle:);

  viewSet.rightView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 820)];
  viewSet.rightView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  viewSet.rightView.wantsLayer = YES;

  BabelTitlebarView* tabsBarPanel =
      [[BabelTitlebarView alloc] initWithFrame:NSMakeRect(0, 780, 1040, tabBarHeight)];
  tabsBarPanel.doubleClickTarget = target;
  tabsBarPanel.doubleClickAction = @selector(maximizeWindowToVisibleFrame:);
  tabsBarPanel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tabsBarPanel.wantsLayer = YES;
  viewSet.tabsBarPanel = tabsBarPanel;
  [viewSet.rootView addSubview:viewSet.tabsBarPanel];

  viewSet.tabsItemsPanel = [[NSView alloc] initWithFrame:NSMakeRect(8, 4, 990, 34)];
  viewSet.tabsItemsPanel.autoresizingMask = NSViewWidthSizable;
  viewSet.tabsItemsPanel.clipsToBounds = YES;
  [viewSet.tabsBarPanel addSubview:viewSet.tabsItemsPanel];

  viewSet.tabAddButton = BabelButton(@"+", target, @selector(openNewTabFromButton:));
  viewSet.tabAddButton.bezelStyle = NSBezelStyleTexturedRounded;
  viewSet.tabAddButton.font = [NSFont systemFontOfSize:17 weight:NSFontWeightRegular];
  viewSet.tabAddButton.toolTip = @"New Tab";
  viewSet.tabAddButton.frame = NSMakeRect(1002, 6, 28, 28);
  viewSet.tabAddButton.autoresizingMask = NSViewMinXMargin;
  [viewSet.tabsBarPanel addSubview:viewSet.tabAddButton];

  viewSet.addressBarPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 736, 1040, toolbarHeight)];
  viewSet.addressBarPanel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  viewSet.addressBarPanel.wantsLayer = YES;
  [viewSet.rightView addSubview:viewSet.addressBarPanel];

  viewSet.addressLabel = [NSTextField labelWithString:@"URL"];
  viewSet.addressLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  viewSet.addressLabel.alignment = NSTextAlignmentRight;
  [viewSet.addressBarPanel addSubview:viewSet.addressLabel];

  viewSet.addressTextFieldContainer = [[NSView alloc] initWithFrame:NSMakeRect(50, 7, 978, 30)];
  viewSet.addressTextFieldContainer.wantsLayer = YES;
  viewSet.addressTextFieldContainer.layer.borderWidth = 1.0;
  viewSet.addressTextFieldContainer.layer.cornerRadius = 6.0;
  viewSet.addressTextFieldContainer.autoresizingMask = NSViewWidthSizable;
  [viewSet.addressBarPanel addSubview:viewSet.addressTextFieldContainer];

  viewSet.viewerBadgeLabel = [[BabelBadgeLabel alloc] init];
  viewSet.viewerBadgeLabel.hidden = YES;
  viewSet.viewerBadgeLabel.settingsTarget = target;
  viewSet.viewerBadgeLabel.settingsAction = @selector(openAddressBadgeSettingsFromMenu:);
  [viewSet.addressTextFieldContainer addSubview:viewSet.viewerBadgeLabel];

  viewSet.urlTextField = [[BabelAddressTextField alloc] initWithFrame:NSMakeRect(8, 4, 962, 22)];
  viewSet.urlTextField.delegate = target;
  viewSet.urlTextField.target = target;
  viewSet.urlTextField.action = @selector(navigateFromAddressField:);
  viewSet.urlTextField.placeholderString = @"Enter URL";
  viewSet.urlTextField.font = [NSFont systemFontOfSize:14];
  viewSet.urlTextField.bezeled = NO;
  viewSet.urlTextField.drawsBackground = NO;
  viewSet.urlTextField.usesSingleLineMode = YES;
  viewSet.urlTextField.focusRingType = NSFocusRingTypeNone;
  viewSet.urlTextField.autoresizingMask = NSViewWidthSizable;
  [viewSet.addressTextFieldContainer addSubview:viewSet.urlTextField];

  viewSet.reloadButton = BabelButton(@"", target, @selector(reloadSelectedTabFromButton:));
  viewSet.reloadButton.bezelStyle = NSBezelStyleTexturedRounded;
  viewSet.reloadButton.toolTip = @"Reload";
  viewSet.reloadButton.frame = NSMakeRect(1000, 8, 28, 28);
  viewSet.reloadButton.autoresizingMask = NSViewMinXMargin;
  ConfigureIconButton(viewSet.reloadButton, @"toolbar-reload", @"↻");
  [viewSet.addressBarPanel addSubview:viewSet.reloadButton];

  viewSet.omniboxSuggestionsPanel = [[NSView alloc] initWithFrame:NSMakeRect(50, 520, 978, 0)];
  viewSet.omniboxSuggestionsPanel.hidden = YES;
  viewSet.omniboxSuggestionsPanel.wantsLayer = YES;
  viewSet.omniboxSuggestionsPanel.layer.cornerRadius = 8.0;
  viewSet.omniboxSuggestionsPanel.layer.borderWidth = 1.0;
  [viewSet.rightView addSubview:viewSet.omniboxSuggestionsPanel];

  viewSet.pagesPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 736)];
  viewSet.pagesPanel.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  viewSet.pagesPanel.clipsToBounds = YES;
  [viewSet.rightView addSubview:viewSet.pagesPanel];

  viewSet.linkStatusBarView = [[NSView alloc] initWithFrame:NSMakeRect(8, 8, 320, linkStatusBarHeight)];
  viewSet.linkStatusBarView.hidden = YES;
  viewSet.linkStatusBarView.wantsLayer = YES;
  viewSet.linkStatusBarView.layer.borderWidth = 1.0;
  viewSet.linkStatusBarView.layer.cornerRadius = 5.0;
  [viewSet.rightView addSubview:viewSet.linkStatusBarView positioned:NSWindowAbove relativeTo:viewSet.pagesPanel];

  viewSet.linkStatusBarLabel = [NSTextField labelWithString:@""];
  viewSet.linkStatusBarLabel.font = [NSFont systemFontOfSize:12];
  viewSet.linkStatusBarLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
  viewSet.linkStatusBarLabel.frame = NSMakeRect(8, 4, 304, 16);
  viewSet.linkStatusBarLabel.autoresizingMask = NSViewWidthSizable;
  [viewSet.linkStatusBarView addSubview:viewSet.linkStatusBarLabel];

  [viewSet.splitView addSubview:viewSet.sidebarView];
  [viewSet.splitView addSubview:viewSet.rightView];
  [viewSet.rootView addSubview:viewSet.splitView positioned:NSWindowBelow relativeTo:viewSet.tabsBarPanel];
  [viewSet.rootView addSubview:viewSet.sidebarResizeHandleView positioned:NSWindowAbove relativeTo:viewSet.splitView];

  return viewSet;
}

@end
