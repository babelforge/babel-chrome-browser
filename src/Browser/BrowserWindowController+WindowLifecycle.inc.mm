// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
  sidebarCollapsed_ = [windowStateStore_ restoredSidebarCollapsed];
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
- (void)layoutTabItemsSelectingLastTab:(BOOL)selectLastTab {
  CGFloat availableWidth = tabsItemsPanel_.bounds.size.width;
  NSUInteger selectedIndex = selectedTab_ ? [tabs_ indexOfObject:selectedTab_] : NSNotFound;
  NSColor* accentColor = [self accentColorForGroup:selectedGroup_];

  NSArray<NSValue*>* tabFrames =
      [tabStripLayoutCalculator_ tabFramesForAvailableWidth:availableWidth
                                                   tabCount:tabs_.count
                                              selectedIndex:selectedIndex];
  for (NSUInteger index = 0; index < tabs_.count; index++) {
    BabelBrowserTab* tab = tabs_[index];
    tab.tabItemView.accentColor = accentColor;
    tab.tabItemView.frame = tabFrames[index].rectValue;
  }
}

- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group {
  return [groupListCoordinator_ accentColorForGroup:group
                                             groups:groups_
                                               view:rootView_ ?: self.window.contentView];
}

- (void)layoutGroupItems {
  [groupListCoordinator_ layoutGroups:groups_
                     inGroupsListView:groupsListView_
                            collapsed:sidebarCollapsed_
                                 view:rootView_ ?: self.window.contentView];
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
  return [windowStateStore_ restoredExpandedSidebarWidthWithDefault:kSidebarInitialWidth
                                                            minimum:[self minimumExpandedSidebarWidth]
                                                            maximum:kSidebarMaximumWidth];
}

- (CGFloat)normalizedExpandedSidebarWidth:(CGFloat)width {
  return MIN(kSidebarMaximumWidth, MAX([self minimumExpandedSidebarWidth], width));
}

- (void)saveExpandedSidebarWidth:(CGFloat)width {
  expandedSidebarWidth_ = [self normalizedExpandedSidebarWidth:width];
  [windowStateStore_ setExpandedSidebarWidth:expandedSidebarWidth_];
}

- (CGFloat)minimumExpandedSidebarWidth {
  CGFloat titleWidth = sidebarTitle_ ? [self sidebarTitleWidth] : 0.0;
  return [sidebarLayoutCalculator_ minimumExpandedWidthForTitleWidth:titleWidth];
}

- (CGFloat)sidebarTitleWidth {
  return [sidebarTitle_ intrinsicContentSize].width + kSidebarTitleRenderPadding;
}

- (CGFloat)targetSidebarWidth {
  if (sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [self normalizedExpandedSidebarWidth:expandedSidebarWidth_];
}

- (void)restoreMainWindowFrame {
  [windowStateStore_ restoreWindowFrame:self.window];
}

- (void)restoreMainWindowZoomStateIfNeeded {
  if (didRestoreMainWindowState_) {
    return;
  }

  didRestoreMainWindowState_ = YES;
  [windowStateStore_ restoreWindowZoomIfNeeded:self.window];
}

- (void)saveMainWindowState {
  [windowStateStore_ saveWindowState:self.window];
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

  CGFloat sidebarWidth = [self sidebarWidth];
  CGFloat totalHeight = splitView_.bounds.size.height;
  BabelSidebarLayout* sidebarLayout =
      [sidebarLayoutCalculator_ layoutForBounds:splitView_.bounds
                                   sidebarWidth:sidebarWidth
                                      collapsed:sidebarCollapsed_
                                      titleWidth:[self sidebarTitleWidth]];
  CGFloat rightWidth = sidebarLayout.rightContentFrame.size.width;

  sidebarView_.frame = sidebarLayout.sidebarFrame;
  sidebarResizeHandleView_.hidden = sidebarCollapsed_;
  sidebarResizeHandleView_.frame = sidebarLayout.resizeHandleFrame;
  sidebarTitle_.hidden = sidebarCollapsed_;
  newGroupButton_.hidden = sidebarCollapsed_;
  sidebarCollapseButton_.frame = sidebarLayout.collapseButtonFrame;
  sidebarCollapseButton_.toolTip = sidebarCollapsed_ ? @"Expand Sidebar" : @"Collapse Sidebar";
  ConfigureIconButton(sidebarCollapseButton_,
                      sidebarCollapsed_ ? @"collapse-right" : @"collapse-left",
                      sidebarCollapsed_ ? @">>" : @"<<");
  newGroupButton_.frame = sidebarLayout.newGroupButtonFrame;
  sidebarTitle_.frame = sidebarLayout.titleFrame;
  groupsListView_.frame = sidebarLayout.groupsListFrame;
  [sidebarView_ addSubview:sidebarCollapseButton_ positioned:NSWindowAbove relativeTo:nil];
  [sidebarView_ addSubview:newGroupButton_ positioned:NSWindowAbove relativeTo:nil];
  [self layoutGroupItems];
  rightView_.frame = sidebarLayout.rightContentFrame;
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
            kOmniboxSuggestionRowHeight * [omniboxSuggestionsController_ suggestionCount]);
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
  [liveBrowserEvictionPolicy_ reset];

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
