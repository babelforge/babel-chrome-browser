#import "Browser/Window/Actions/Lifecycle/BabelBrowserWindowLifecycleActions.h"

#import "Browser/Window/Controller/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowLifecycleActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)restoreSessionByPriority {
  [owner_ restoreSessionPositionState];

  NSData* stateData = [owner_->groupSessionStore_ persistedGroupsAndTabsStateData];
  NSDictionary* state = [owner_->groupSessionStore_ persistedGroupsAndTabsStateFromData:stateData];

  owner_->isRestoringSession_ = YES;
  [owner_ restoreGroupsFromState:state];
  [owner_ restoreSessionGroupsFromState:state];
  owner_->isRestoringSession_ = NO;

  NSString* prewarmedModuleIdentifier = [owner_ prewarmSelectedRestoredTabRuntimeIfNeeded];
  [owner_ restoreSessionInitialBrowsers];
  [owner_ restoreSessionModulesLifecycle];
  NSSet<NSString*>* excludedModuleIdentifiers = prewarmedModuleIdentifier.length > 0
      ? [NSSet setWithObject:prewarmedModuleIdentifier]
      : [NSSet set];
  [owner_ scheduleBackgroundModulePrewarmExcludingIdentifiers:excludedModuleIdentifiers];
}

- (void)restoreSessionPositionState {
  [owner_ restoreSessionWindowFrame];
  [owner_ restoreSessionSidebarState];
}

- (void)restoreSessionWindowFrame {
  [owner_ restoreMainWindowFrame];
}

- (void)restoreSessionWindowZoom {
  [owner_ restoreMainWindowZoomStateIfNeeded];
}

- (void)restoreSessionSidebarCollapsedState {
  owner_->sidebarCollapsed_ = [owner_->windowStateStore_ restoredSidebarCollapsed];
}

- (void)restoreSessionSidebarExpandedWidth {
  owner_->expandedSidebarWidth_ = [owner_ restoredExpandedSidebarWidth];
}

- (void)restoreSessionSidebarState {
  [owner_ restoreSessionSidebarCollapsedState];
  [owner_ restoreSessionSidebarExpandedWidth];
}

- (void)applySessionSidebarDividerPosition {
  if (owner_->didApplyInitialSidebarRestore_) {
    return;
  }

  owner_->didApplyInitialSidebarRestore_ = YES;
  BOOL previousBuildingState = owner_->isBuildingInterface_;
  owner_->isBuildingInterface_ = YES;
  [owner_ layoutInterfaceForCurrentSplitViewSize];
  owner_->isBuildingInterface_ = previousBuildingState;
}

- (void)restoreSessionSidebarAfterInitialLayout {
  [owner_ restoreSessionSidebarState];
  [owner_ applySessionSidebarDividerPosition];
}

- (void)restoreSessionInitialBrowsers {
  [owner_ createInitialRestoredBrowserIfNeeded];
}

- (void)restoreSessionModulesLifecycle {
  [owner_ dispatchApplicationDidStartModuleLifecycleHook];
}

- (NSString*)prewarmSelectedRestoredTabRuntimeIfNeeded {
  BabelBrowserTab* selectedTab = owner_->selectedTab_;
  NSString* requestedURLString = selectedTab.requestedURLString.length > 0
      ? selectedTab.requestedURLString
      : selectedTab.urlString;
  NSString* moduleIdentifier =
      [owner_->restoredTabModuleDependencyResolver_ moduleIdentifierForRestoredURLString:requestedURLString];
  if (moduleIdentifier.length == 0 ||
      ![owner_->moduleActionService_ moduleWithIdentifierUsesPrewarmStartPolicy:moduleIdentifier]) {
    return nil;
  }

  NSError* error = nil;
  [owner_->moduleActionService_ prewarmModuleWithIdentifierIfNeeded:moduleIdentifier error:&error];
  if (error) {
    NSLog(@"BabelChrome startup prewarm failed for module %@: %@",
          moduleIdentifier,
          error.localizedDescription);
  }

  return moduleIdentifier;
}

- (void)scheduleBackgroundModulePrewarmExcludingIdentifiers:(NSSet<NSString*>*)excludedIdentifiers {
  [owner_->moduleActionService_ schedulePrewarmModulesExcludingIdentifiers:excludedIdentifiers ?: [NSSet set]];
}

- (void)maximizeWindowToVisibleFrame:(id)sender {
  NSScreen* screen = owner_.window.screen ?: NSScreen.mainScreen;
  if (!screen) {
    return;
  }

  [owner_.window setFrame:screen.visibleFrame display:YES animate:YES];
}

- (void)dispatchApplicationDidStartModuleLifecycleHook {
  __weak BabelBrowserWindowController* weakSelf = owner_;
  [owner_->moduleLifecycleDispatcher_
      dispatchApplicationDidStartWithRestoredProjectsHandler:^(NSArray<NSString*>* projectIdentifiers) {
        [weakSelf reloadServerTabsWithProjectIdentifiers:projectIdentifiers];
      }];
}

- (void)dispatchApplicationWillQuitModuleLifecycleHook {
  [owner_->moduleLifecycleDispatcher_ dispatchApplicationWillQuit];
}
- (void)buildInterface {
  owner_->isBuildingInterface_ = YES;
  [owner_ restoreSessionSidebarState];
  CGFloat initialSidebarWidth = [owner_ targetSidebarWidth];

  BabelMainWindowViewSet* viewSet =
      [owner_->mainWindowViewFactory_ viewSetWithWindowBounds:owner_.window.contentView.bounds
                                               target:owner_
                                  initialSidebarWidth:initialSidebarWidth
                                         tabBarHeight:kTabBarHeight
                                        toolbarHeight:kToolbarHeight
                              sidebarHeaderButtonSize:kSidebarHeaderButtonSize
                            sidebarHeaderLeadingInset:kSidebarHeaderLeadingInset
                               sidebarHeaderButtonGap:kSidebarHeaderButtonGap
                                  linkStatusBarHeight:kLinkStatusBarHeight];
  owner_->rootView_ = viewSet.rootView;
  owner_->splitView_ = viewSet.splitView;
  owner_->sidebarView_ = viewSet.sidebarView;
  owner_->sidebarResizeHandleView_ = viewSet.sidebarResizeHandleView;
  owner_->sidebarTitle_ = viewSet.sidebarTitle;
  owner_->sidebarCollapseButton_ = viewSet.sidebarCollapseButton;
  owner_->newGroupButton_ = viewSet.groupAddButton;
  owner_->groupsListView_ = viewSet.groupsListView;
  owner_->rightView_ = viewSet.rightView;
  owner_->tabsBarPanel_ = viewSet.tabsBarPanel;
  owner_->tabsItemsPanel_ = viewSet.tabsItemsPanel;
  owner_->newTabButton_ = viewSet.tabAddButton;
  owner_->addressBarPanel_ = viewSet.addressBarPanel;
  owner_->addressLabel_ = viewSet.addressLabel;
  owner_->addressTextFieldContainer_ = viewSet.addressTextFieldContainer;
  owner_->urlTextField_ = viewSet.urlTextField;
  owner_->viewerBadgeLabel_ = viewSet.viewerBadgeLabel;
  owner_->reloadButton_ = viewSet.reloadButton;
  owner_->omniboxSuggestionsPanel_ = viewSet.omniboxSuggestionsPanel;
  owner_->pagesPanel_ = viewSet.pagesPanel;
  owner_->linkStatusBarView_ = viewSet.linkStatusBarView;
  owner_->linkStatusBarLabel_ = viewSet.linkStatusBarLabel;

  [owner_.window setContentView:owner_->rootView_];
  [owner_ applyThemeColors];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
  owner_->isBuildingInterface_ = NO;
}
- (void)layoutTabItemsSelectingLastTab:(BOOL)selectLastTab {
  CGFloat availableWidth = owner_->tabsItemsPanel_.bounds.size.width;
  NSUInteger selectedIndex = owner_->selectedTab_ ? [owner_->tabs_ indexOfObject:owner_->selectedTab_] : NSNotFound;
  NSColor* accentColor = [owner_ accentColorForGroup:owner_->selectedGroup_];

  NSArray<NSValue*>* tabFrames =
      [owner_->tabStripLayoutCalculator_ tabFramesForAvailableWidth:availableWidth
                                                   tabCount:owner_->tabs_.count
                                              selectedIndex:selectedIndex];
  for (NSUInteger index = 0; index < owner_->tabs_.count; index++) {
    BabelBrowserTab* tab = owner_->tabs_[index];
    tab.tabItemView.accentColor = accentColor;
    tab.tabItemView.frame = tabFrames[index].rectValue;
  }
}

- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group {
  return [owner_->groupListCoordinator_ accentColorForGroup:group
                                             groups:owner_->groups_
                                               view:owner_->rootView_ ?: owner_.window.contentView];
}

- (void)layoutGroupItems {
  [owner_->groupListCoordinator_ layoutGroups:owner_->groups_
                     inGroupsListView:owner_->groupsListView_
                            collapsed:owner_->sidebarCollapsed_
                                 view:owner_->rootView_ ?: owner_.window.contentView];
}

- (NSUInteger)totalTabCount {
  NSUInteger tabCount = 0;
  for (BabelBrowserGroup* group in owner_->groups_) {
    tabCount += group.tabs.count;
  }
  return tabCount;
}

- (CGFloat)sidebarWidth {
  if (owner_->sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [owner_ normalizedExpandedSidebarWidth:owner_->expandedSidebarWidth_];
}

- (CGFloat)restoredExpandedSidebarWidth {
  return [owner_->windowStateStore_ restoredExpandedSidebarWidthWithDefault:kSidebarInitialWidth
                                                            minimum:[owner_ minimumExpandedSidebarWidth]
                                                            maximum:kSidebarMaximumWidth];
}

- (CGFloat)normalizedExpandedSidebarWidth:(CGFloat)width {
  return MIN(kSidebarMaximumWidth, MAX([owner_ minimumExpandedSidebarWidth], width));
}

- (void)saveExpandedSidebarWidth:(CGFloat)width {
  owner_->expandedSidebarWidth_ = [owner_ normalizedExpandedSidebarWidth:width];
  [owner_->windowStateStore_ setExpandedSidebarWidth:owner_->expandedSidebarWidth_];
}

- (CGFloat)minimumExpandedSidebarWidth {
  CGFloat titleWidth = owner_->sidebarTitle_ ? [owner_ sidebarTitleWidth] : 0.0;
  return [owner_->sidebarLayoutCalculator_ minimumExpandedWidthForTitleWidth:titleWidth];
}

- (CGFloat)sidebarTitleWidth {
  return [owner_->sidebarTitle_ intrinsicContentSize].width + kSidebarTitleRenderPadding;
}

- (CGFloat)targetSidebarWidth {
  if (owner_->sidebarCollapsed_) {
    return kSidebarCollapsedWidth;
  }
  return [owner_ normalizedExpandedSidebarWidth:owner_->expandedSidebarWidth_];
}

- (void)restoreMainWindowFrame {
  [owner_->windowStateStore_ restoreWindowFrame:owner_.window];
}

- (void)restoreMainWindowZoomStateIfNeeded {
  if (owner_->didRestoreMainWindowState_) {
    return;
  }

  owner_->didRestoreMainWindowState_ = YES;
  [owner_->windowStateStore_ restoreWindowZoomIfNeeded:owner_.window];
}

- (void)saveMainWindowState {
  [owner_->windowStateStore_ saveWindowState:owner_.window];
}

- (void)applyThemeColors {
  [owner_->browserThemeApplier_ applyThemeToRootView:owner_->rootView_
                                  sidebarView:owner_->sidebarView_
                                    rightView:owner_->rightView_
                                 tabsBarPanel:owner_->tabsBarPanel_
                              addressBarPanel:owner_->addressBarPanel_
                                 addressLabel:owner_->addressLabel_
                    addressTextFieldContainer:owner_->addressTextFieldContainer_
                                 urlTextField:owner_->urlTextField_
                      omniboxSuggestionsPanel:owner_->omniboxSuggestionsPanel_
                            linkStatusBarView:owner_->linkStatusBarView_
                           linkStatusBarLabel:owner_->linkStatusBarLabel_
                                       groups:owner_->groups_];
}

- (void)layoutInterfaceForCurrentSplitViewSize {
  if (!owner_->rootView_ || !owner_->splitView_ || !owner_->sidebarView_ || !owner_->rightView_) {
    return;
  }

  CGFloat rootWidth = owner_->rootView_.bounds.size.width;
  CGFloat rootHeight = owner_->rootView_.bounds.size.height;
  owner_->tabsBarPanel_.frame = NSMakeRect(0,
                                   MAX(0.0, rootHeight - kTabBarHeight),
                                   rootWidth,
                                   kTabBarHeight);
  owner_->tabsItemsPanel_.frame = NSMakeRect(kTitlebarTabLeadingInset,
                                     4,
                                     MAX(0.0, rootWidth - kTitlebarTabLeadingInset -
                                              kNewTabButtonWidth - 14),
                                     34);
  owner_->newTabButton_.frame = NSMakeRect(MAX(kTitlebarTabLeadingInset,
                                       rootWidth - kNewTabButtonWidth - 6),
                                   6,
                                   28,
                                   28);
  owner_->splitView_.frame = NSMakeRect(0, 0, rootWidth, MAX(0.0, rootHeight - kTabBarHeight));

  CGFloat sidebarWidth = [owner_ sidebarWidth];
  CGFloat totalHeight = owner_->splitView_.bounds.size.height;
  BabelSidebarLayout* sidebarLayout =
      [owner_->sidebarLayoutCalculator_ layoutForBounds:owner_->splitView_.bounds
                                   sidebarWidth:sidebarWidth
                                      collapsed:owner_->sidebarCollapsed_
                                      titleWidth:[owner_ sidebarTitleWidth]];
  CGFloat rightWidth = sidebarLayout.rightContentFrame.size.width;

  owner_->sidebarView_.frame = sidebarLayout.sidebarFrame;
  owner_->sidebarResizeHandleView_.hidden = owner_->sidebarCollapsed_;
  owner_->sidebarResizeHandleView_.frame = sidebarLayout.resizeHandleFrame;
  owner_->sidebarTitle_.hidden = owner_->sidebarCollapsed_;
  owner_->newGroupButton_.hidden = owner_->sidebarCollapsed_;
  owner_->sidebarCollapseButton_.frame = sidebarLayout.collapseButtonFrame;
  owner_->sidebarCollapseButton_.toolTip = owner_->sidebarCollapsed_ ? @"Expand Sidebar" : @"Collapse Sidebar";
  ConfigureIconButton(owner_->sidebarCollapseButton_,
                      owner_->sidebarCollapsed_ ? @"collapse-right" : @"collapse-left",
                      owner_->sidebarCollapsed_ ? @">>" : @"<<");
  owner_->newGroupButton_.frame = sidebarLayout.newGroupButtonFrame;
  owner_->sidebarTitle_.frame = sidebarLayout.titleFrame;
  owner_->groupsListView_.frame = sidebarLayout.groupsListFrame;
  [owner_->sidebarView_ addSubview:owner_->sidebarCollapseButton_ positioned:NSWindowAbove relativeTo:nil];
  [owner_->sidebarView_ addSubview:owner_->newGroupButton_ positioned:NSWindowAbove relativeTo:nil];
  [owner_ layoutGroupItems];
  owner_->rightView_.frame = sidebarLayout.rightContentFrame;
  owner_->addressBarPanel_.frame = NSMakeRect(0,
                                      totalHeight - kToolbarHeight,
                                      rightWidth,
                                      kToolbarHeight);
  owner_->addressLabel_.frame = NSMakeRect(12, 12, 30, 18);
  CGFloat addressFieldX = 50.0;
  CGFloat reloadButtonWidth = 28.0;
  CGFloat reloadButtonRightInset = 8.0;
  CGFloat reloadButtonGap = 6.0;
  CGFloat reloadButtonX = MAX(addressFieldX,
                              rightWidth - reloadButtonRightInset - reloadButtonWidth);
  owner_->reloadButton_.frame = NSMakeRect(reloadButtonX, 8, reloadButtonWidth, reloadButtonWidth);
  CGFloat addressFieldWidth = MAX(0.0, reloadButtonX - addressFieldX - reloadButtonGap);
  owner_->addressTextFieldContainer_.frame = NSMakeRect(addressFieldX, 7, addressFieldWidth, 30);
  [owner_ layoutAddressTextFieldContent];
  CGFloat suggestionsHeight = owner_->omniboxSuggestionsPanel_.hidden
      ? 0.0
      : MIN(kOmniboxSuggestionPanelMaximumHeight,
            kOmniboxSuggestionRowHeight * [owner_->omniboxSuggestionsController_ suggestionCount]);
  owner_->omniboxSuggestionsPanel_.frame = NSMakeRect(addressFieldX,
                                              MAX(0.0, totalHeight - kToolbarHeight -
                                                           suggestionsHeight - 2.0),
                                              addressFieldWidth,
                                              suggestionsHeight);
  [owner_->rightView_ addSubview:owner_->omniboxSuggestionsPanel_
              positioned:NSWindowAbove
              relativeTo:owner_->pagesPanel_];
  owner_->pagesPanel_.frame = NSMakeRect(0,
                                 0,
                                 rightWidth,
                                 MAX(0.0, totalHeight - kToolbarHeight));
  CGFloat linkStatusBarWidth =
      MIN(kLinkStatusBarMaximumWidth, MAX(220.0, rightWidth - 16.0));
  owner_->linkStatusBarView_.frame = NSMakeRect(8.0,
                                        8.0,
                                        linkStatusBarWidth,
                                        kLinkStatusBarHeight);
  owner_->linkStatusBarLabel_.frame = NSMakeRect(8.0,
                                         4.0,
                                         MAX(0.0, linkStatusBarWidth - 16.0),
                                         16.0);
  [owner_->rightView_ addSubview:owner_->linkStatusBarView_
              positioned:NSWindowAbove
              relativeTo:owner_->pagesPanel_];
  for (BabelBrowserGroup* group in owner_->groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      [owner_ layoutBrowserViewsForTab:tab];
    }
  }
  [owner_ layoutTabItemsSelectingLastTab:NO];
}

- (void)requestApplicationTermination {
  if (owner_->isTerminating_) {
    return;
  }

  owner_->isTerminating_ = YES;
  [owner_ saveMainWindowState];
  [owner_ dispatchApplicationWillQuitModuleLifecycleHook];
  [BabelLocalServiceHost.sharedHost stop];
  [owner_->browserPageLifecycleController_ reset];

  if ([owner_ totalTabCount] == 0) {
    CefQuitMessageLoop();
    return;
  }

  [owner_ closeAllBrowsersForTermination];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (owner_->isTerminating_) {
      CefQuitMessageLoop();
    }
  });
}

- (void)windowDidResize:(NSNotification*)notification {
  [owner_ layoutInterfaceForCurrentSplitViewSize];
  [owner_ saveMainWindowState];
}

- (void)windowDidMove:(NSNotification*)notification {
  [owner_ saveMainWindowState];
}

- (void)closeAllBrowsersForTermination {
  for (BabelBrowserGroup* group in owner_->groups_) {
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
  [owner_ requestApplicationTermination];
  return NO;
}


@end
