// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
