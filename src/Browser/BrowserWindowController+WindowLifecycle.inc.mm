// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)restoreSessionByPriority {
  [self restoreSessionPositionState];

  NSData* stateData = [groupSessionStore_ persistedGroupsAndTabsStateData];
  NSDictionary* state = [groupSessionStore_ persistedGroupsAndTabsStateFromData:stateData];

  isRestoringSession_ = YES;
  [self restoreGroupsFromState:state];
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
  __weak BabelBrowserWindowController* weakSelf = self;
  [moduleLifecycleDispatcher_
      dispatchApplicationDidStartWithRestoredProjectsHandler:^(NSArray<NSString*>* projectIdentifiers) {
        [weakSelf reloadServerTabsWithProjectIdentifiers:projectIdentifiers];
      }];
}

- (void)dispatchApplicationWillQuitModuleLifecycleHook {
  [moduleLifecycleDispatcher_ dispatchApplicationWillQuit];
}
- (void)buildInterface {
  isBuildingInterface_ = YES;
  [self restoreSessionSidebarState];
  CGFloat initialSidebarWidth = [self targetSidebarWidth];

  BabelMainWindowViewSet* viewSet =
      [mainWindowViewFactory_ viewSetWithWindowBounds:self.window.contentView.bounds
                                               target:self
                                  initialSidebarWidth:initialSidebarWidth
                                         tabBarHeight:kTabBarHeight
                                        toolbarHeight:kToolbarHeight
                              sidebarHeaderButtonSize:kSidebarHeaderButtonSize
                            sidebarHeaderLeadingInset:kSidebarHeaderLeadingInset
                               sidebarHeaderButtonGap:kSidebarHeaderButtonGap
                                  linkStatusBarHeight:kLinkStatusBarHeight];
  rootView_ = viewSet.rootView;
  splitView_ = viewSet.splitView;
  sidebarView_ = viewSet.sidebarView;
  sidebarResizeHandleView_ = viewSet.sidebarResizeHandleView;
  sidebarTitle_ = viewSet.sidebarTitle;
  sidebarCollapseButton_ = viewSet.sidebarCollapseButton;
  newGroupButton_ = viewSet.groupAddButton;
  groupsListView_ = viewSet.groupsListView;
  rightView_ = viewSet.rightView;
  tabsBarPanel_ = viewSet.tabsBarPanel;
  tabsItemsPanel_ = viewSet.tabsItemsPanel;
  newTabButton_ = viewSet.tabAddButton;
  addressBarPanel_ = viewSet.addressBarPanel;
  addressLabel_ = viewSet.addressLabel;
  addressTextFieldContainer_ = viewSet.addressTextFieldContainer;
  urlTextField_ = viewSet.urlTextField;
  viewerBadgeLabel_ = viewSet.viewerBadgeLabel;
  reloadButton_ = viewSet.reloadButton;
  omniboxSuggestionsPanel_ = viewSet.omniboxSuggestionsPanel;
  pagesPanel_ = viewSet.pagesPanel;
  linkStatusBarView_ = viewSet.linkStatusBarView;
  linkStatusBarLabel_ = viewSet.linkStatusBarLabel;

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
  [browserThemeApplier_ applyThemeToRootView:rootView_
                                  sidebarView:sidebarView_
                                    rightView:rightView_
                                 tabsBarPanel:tabsBarPanel_
                              addressBarPanel:addressBarPanel_
                                 addressLabel:addressLabel_
                    addressTextFieldContainer:addressTextFieldContainer_
                                 urlTextField:urlTextField_
                      omniboxSuggestionsPanel:omniboxSuggestionsPanel_
                            linkStatusBarView:linkStatusBarView_
                           linkStatusBarLabel:linkStatusBarLabel_
                                       groups:groups_];
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
  [browserPageLifecycleController_ reset];

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
