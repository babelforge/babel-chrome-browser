// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
