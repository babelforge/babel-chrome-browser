// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
  CGFloat titleWidth = sidebarTitle_ ? [self sidebarTitleWidth] : 0.0;
  return kSidebarHeaderLeadingInset + kSidebarHeaderButtonSize + kSidebarHeaderButtonGap +
      titleWidth + kSidebarHeaderButtonGap + kSidebarHeaderButtonSize + kSidebarHeaderTrailingInset;
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
  id persistedFrame = [NSUserDefaults.standardUserDefaults objectForKey:kMainWindowFrameDefaultsKey];
  if (!persistedFrame) {
    [self.window center];
    return;
  }

  NSRect frame = [self restoredMainWindowFrameFromPersistedValue:persistedFrame];
  if (![self mainWindowFrameIsVisible:frame]) {
    NSScreen* fallbackScreen = NSScreen.screens.firstObject ?: NSScreen.mainScreen;
    if (fallbackScreen) {
      [self.window setFrame:[self centeredMainWindowFrameOnScreen:fallbackScreen]
                    display:NO];
    } else {
      [self.window center];
    }
    return;
  }

  [self.window setFrame:frame display:NO];
}

- (void)restoreMainWindowZoomStateIfNeeded {
  if (didRestoreMainWindowState_) {
    return;
  }

  didRestoreMainWindowState_ = YES;
  NSScreen* screen = [self bestScreenForMainWindowFrame:self.window.frame];
  BOOL shouldRestoreZoom = [NSUserDefaults.standardUserDefaults boolForKey:kMainWindowZoomedDefaultsKey] &&
      [self mainWindowFrameIsEffectivelyZoomed:self.window.frame onScreen:screen];
  if (shouldRestoreZoom && !self.window.isZoomed) {
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

- (NSRect)restoredMainWindowFrameFromPersistedValue:(id)persistedValue {
  if ([persistedValue isKindOfClass:NSString.class]) {
    return NSRectFromString((NSString*)persistedValue);
  }

  if (![persistedValue isKindOfClass:NSDictionary.class]) {
    return NSZeroRect;
  }

  NSDictionary* persistedFrame = (NSDictionary*)persistedValue;
  NSScreen* screen = [self screenForPersistedMainWindowFrame:persistedFrame];
  if (!screen) {
    return NSZeroRect;
  }

  NSRect visibleFrame = screen.visibleFrame;
  CGFloat width = [persistedFrame[@"width"] doubleValue];
  CGFloat height = [persistedFrame[@"height"] doubleValue];
  CGFloat relativeX = [persistedFrame[@"x"] doubleValue];
  CGFloat relativeY = [persistedFrame[@"y"] doubleValue];

  NSRect frame = NSMakeRect(visibleFrame.origin.x + relativeX,
                            visibleFrame.origin.y + relativeY,
                            width,
                            height);
  return frame;
}

- (NSScreen*)screenForPersistedMainWindowFrame:(NSDictionary*)persistedFrame {
  NSString* screenName = [persistedFrame[@"screenName"] isKindOfClass:NSString.class]
      ? persistedFrame[@"screenName"]
      : @"";
  for (NSScreen* screen in NSScreen.screens) {
    if (screenName.length > 0 && [screen.localizedName isEqualToString:screenName]) {
      return screen;
    }
  }

  return NSScreen.screens.firstObject ?: NSScreen.mainScreen;
}

- (NSRect)centeredMainWindowFrameOnScreen:(NSScreen*)screen {
  NSRect visibleFrame = screen.visibleFrame;
  NSSize windowSize = self.window.frame.size;
  CGFloat width = MIN(MAX(900.0, windowSize.width), visibleFrame.size.width);
  CGFloat height = MIN(MAX(580.0, windowSize.height), visibleFrame.size.height);
  return NSMakeRect(NSMidX(visibleFrame) - (width / 2.0),
                    NSMidY(visibleFrame) - (height / 2.0),
                    width,
                    height);
}

- (NSScreen*)bestScreenForMainWindowFrame:(NSRect)frame {
  NSScreen* bestScreen = self.window.screen ?: NSScreen.mainScreen;
  CGFloat bestIntersectionArea = 0.0;
  for (NSScreen* screen in NSScreen.screens) {
    NSRect intersection = NSIntersectionRect(frame, screen.visibleFrame);
    CGFloat intersectionArea = intersection.size.width * intersection.size.height;
    if (intersectionArea > bestIntersectionArea) {
      bestIntersectionArea = intersectionArea;
      bestScreen = screen;
    }
  }

  return bestScreen ?: NSScreen.screens.firstObject;
}

- (BOOL)mainWindowFrameIsEffectivelyZoomed:(NSRect)frame onScreen:(NSScreen*)screen {
  if (!screen) {
    return NO;
  }

  NSRect visibleFrame = screen.visibleFrame;
  return fabs(frame.origin.x - visibleFrame.origin.x) <= kWindowFrameComparisonTolerance &&
      fabs(frame.origin.y - visibleFrame.origin.y) <= kWindowFrameComparisonTolerance &&
      fabs(frame.size.width - visibleFrame.size.width) <= kWindowFrameComparisonTolerance &&
      fabs(frame.size.height - visibleFrame.size.height) <= kWindowFrameComparisonTolerance;
}

- (void)saveMainWindowState {
  if (!self.window) {
    return;
  }

  NSRect frame = self.window.frame;
  NSScreen* screen = [self bestScreenForMainWindowFrame:frame];
  BOOL shouldRestoreZoom = self.window.isZoomed &&
      [self mainWindowFrameIsEffectivelyZoomed:frame onScreen:screen];
  [NSUserDefaults.standardUserDefaults setBool:shouldRestoreZoom
                                        forKey:kMainWindowZoomedDefaultsKey];
  if (!self.window.isMiniaturized) {
    NSRect visibleFrame = screen.visibleFrame;
    NSDictionary* persistedFrame = @{
      @"version": @1,
      @"screenName": screen.localizedName ?: @"",
      @"x": @(frame.origin.x - visibleFrame.origin.x),
      @"y": @(frame.origin.y - visibleFrame.origin.y),
      @"width": @(frame.size.width),
      @"height": @(frame.size.height)
    };
    [NSUserDefaults.standardUserDefaults setObject:persistedFrame
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

  CGFloat sidebarWidth = [self sidebarWidth];
  CGFloat totalWidth = splitView_.bounds.size.width;
  CGFloat totalHeight = splitView_.bounds.size.height;
  CGFloat rightWidth = MAX(0.0, totalWidth - sidebarWidth);

  sidebarView_.frame = NSMakeRect(0, 0, sidebarWidth, totalHeight);
  sidebarResizeHandleView_.hidden = sidebarCollapsed_;
  sidebarResizeHandleView_.frame = NSMakeRect(MAX(0.0, sidebarWidth - 3.0),
                                              0,
                                              7.0,
                                              totalHeight);
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
  CGFloat titleIntrinsicWidth = [self sidebarTitleWidth];
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
  rightView_.frame = NSMakeRect(sidebarWidth, 0, rightWidth, totalHeight);
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
