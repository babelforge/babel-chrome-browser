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
