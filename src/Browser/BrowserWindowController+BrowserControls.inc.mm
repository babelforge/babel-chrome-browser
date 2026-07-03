// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
  [NSUserDefaults.standardUserDefaults setBool:sidebarCollapsed_
                                        forKey:kSidebarCollapsedDefaultsKey];
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
