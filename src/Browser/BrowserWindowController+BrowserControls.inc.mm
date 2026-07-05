// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab {
  return [internalPageTabClassifier_ isInternalPageTab:tab];
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
  return [viewerSourceActionHandler_ canOpenViewerSourceForTab:[self tabForBrowser:browser]];
}

- (void)openViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  [viewerSourceActionHandler_ openViewerSourceForTab:[self tabForBrowser:browser]];
}

- (void)revealViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  [viewerSourceActionHandler_ revealViewerSourceForTab:[self tabForBrowser:browser]];
}

- (void)closeDeveloperToolsFromButton:(NSButton*)sender {
  BabelBrowserTab* tab = [self tabForDeveloperToolsControl:sender];
  [self closeDeveloperToolsForTab:tab];
}

- (void)changeDeveloperToolsDockFromButton:(NSButton*)sender {
  NSString* dockMode = [developerToolsDockingPolicy_ dockModeForTag:sender.tag];
  if (dockMode.length == 0) {
    return;
  }

  developerToolsDockMode_ = dockMode;
  [developerToolsDockingStore_ setDockMode:dockMode
                              allowedModes:[developerToolsDockingPolicy_ allowedDockModes]];
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

  developerToolsSizeRatio_ =
      [developerToolsDockingStore_ setSizeRatio:developerToolsSizeRatio_ + (signedDelta / axisLength)];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)resizeSidebarFromHandle:(BabelDeveloperToolsResizeHandleView*)sender {
  if (sidebarCollapsed_) {
    return;
  }

  [self saveExpandedSidebarWidth:expandedSidebarWidth_ + sender.dragDelta];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)toggleSidebarCollapsed:(id)sender {
  if (!sidebarCollapsed_) {
    [self saveExpandedSidebarWidth:sidebarView_.frame.size.width];
  }
  sidebarCollapsed_ = !sidebarCollapsed_;
  [windowStateStore_ setSidebarCollapsed:sidebarCollapsed_];
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

- (NSString*)restoredDeveloperToolsDockMode {
  return [developerToolsDockingStore_ restoredDockModeWithFallback:kDeveloperToolsDockModeBottom
                                                      allowedModes:[developerToolsDockingPolicy_ allowedDockModes]];
}

- (CGFloat)restoredDeveloperToolsSizeRatio {
  return [developerToolsDockingStore_ restoredSizeRatio];
}

- (BOOL)developerToolsDockModeIsHorizontal {
  return [developerToolsDockingPolicy_ isHorizontalDockMode:developerToolsDockMode_];
}

- (void)navigateSelectedTabBack {
  [browserNavigationController_ navigateTabBack:selectedTab_];
}

- (void)navigateSelectedTabForward {
  [browserNavigationController_ navigateTabForward:selectedTab_];
}

- (void)reloadSelectedTab {
  [self reloadSelectedTabIgnoringCache:NO];
}

- (void)reloadSelectedTabFromButton:(id)sender {
  [self reloadSelectedTab];
}

- (void)reloadSelectedTabIgnoringCache {
  [self reloadSelectedTabIgnoringCache:YES];
}

- (void)reloadSelectedTabIgnoringCache:(BOOL)ignoringCache {
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
      if (!ignoringCache) {
        return;
      }
    }
  }

  if (!ignoringCache) {
    [browserNavigationController_ reloadTab:selectedTab_];
    return;
  }

  [browserNavigationController_ reloadTabIgnoringCache:selectedTab_];
}

- (void)reloadMarkdownViewerTabsUsingCurrentTheme {
  for (BabelBrowserTab* tab in tabs_) {
    if (![[stableViewerURLResolver_ resolvedViewerKindForStableViewerURLString:tab.requestedURLString] isEqualToString:@"markdown"]) {
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
