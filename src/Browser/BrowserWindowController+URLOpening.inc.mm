// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)openURLs:(NSArray<NSURL*>*)urls {
  if (urls.count == 0 && [self totalTabCount] > 0) {
    [self showMainWindow];
    [self saveGroupsState];
    return;
  }

  NSArray<NSURL*>* urlsToOpen = urls.count > 0
      ? urls
      : @[ [NSURL URLWithString:BabelChromeConfiguration.defaultURLString] ];

  for (NSURL* url in urlsToOpen) {
    [self openURL:url];
  }

  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openNewTab {
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openAdjacentNewTab {
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  if (selectedTab_ && [group.tabs containsObject:selectedTab_]) {
    [self createTabForURL:BabelChromeConfiguration.defaultURLString
                  inGroup:group
                parentTab:selectedTab_
     respectingUserStrategy:NO];
  } else {
    [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  }
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)openNewTabFromButton:(id)sender {
  [self openNewTab];
}

- (void)scheduleQueuedURLOpening {
}

- (void)drainQueuedURLOpening {
}

- (void)openURL:(NSURL*)url {
  if ([url.scheme isEqualToString:@"babelchrome"]) {
    if ([self isStableViewerURLString:url.absoluteString]) {
      [self openURLString:url.absoluteString groupName:kDefaultGroupName];
      return;
    }
    if ([self handleInternalNavigationURLString:url.absoluteString]) {
      return;
    }
    [self openBabelChromeCommandURL:url];
    return;
  }

  [self openURLString:url.absoluteString groupName:kDefaultGroupName];
}

- (void)openBabelChromeCommandURL:(NSURL*)url {
  if ([self openCompactBabelChromeCommandString:url.absoluteString]) {
    return;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:url
                                           resolvingAgainstBaseURL:NO];
  NSString* groupName = kDefaultGroupName;
  NSString* targetURLString = nil;

  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:@"group"] && item.value.length > 0) {
      groupName = item.value;
      continue;
    }

    if ([item.name isEqualToString:@"url"] && item.value.length > 0) {
      targetURLString = item.value;
    }
  }

  if (targetURLString.length == 0) {
    targetURLString = BabelChromeConfiguration.defaultURLString;
  }

  [self openURLString:targetURLString groupName:groupName];
}

- (BOOL)openCompactBabelChromeCommandString:(NSString*)urlString {
  NSString* payload = nil;
  if ([urlString hasPrefix:kCompactCommandOpaquePrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandOpaquePrefix.length];
  } else if ([urlString hasPrefix:kCompactCommandHierarchicalPrefix]) {
    payload = [urlString substringFromIndex:kCompactCommandHierarchicalPrefix.length];
  }

  if (!payload) {
    return NO;
  }

  NSArray<NSString*>* separators = @[
    @"::|::url:",
    @"::%7C::url:",
    @"::%7c::url:"
  ];

  NSRange separatorRange = NSMakeRange(NSNotFound, 0);
  for (NSString* separator in separators) {
    separatorRange = [payload rangeOfString:separator];
    if (separatorRange.location != NSNotFound) {
      break;
    }
  }

  if (separatorRange.location == NSNotFound) {
    return NO;
  }

  NSString* encodedGroupName = [payload substringToIndex:separatorRange.location];
  NSString* targetURLString =
      [payload substringFromIndex:separatorRange.location + separatorRange.length];
  NSString* groupName = encodedGroupName.stringByRemovingPercentEncoding ?: encodedGroupName;
  if (groupName.length == 0) {
    groupName = kDefaultGroupName;
  }

  if (targetURLString.length == 0) {
    targetURLString = BabelChromeConfiguration.defaultURLString;
  }

  [self openURLString:targetURLString groupName:groupName];
  return YES;
}

- (void)openURLString:(NSString*)urlString groupName:(NSString*)groupName {
  BabelBrowserGroup* group = [self ensureGroupNamed:groupName];
  [self selectGroup:group];

  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([self isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* existingTab = [self tabWithURLString:requestedURLString inGroup:group] ?:
      [self tabWithURLString:urlString inGroup:group];
  if (existingTab) {
    if (![existingTab.urlString isEqualToString:navigationURLString]) {
      existingTab.urlString = navigationURLString;
      existingTab.requestedURLString = requestedURLString;
      if ([existingTab browser]) {
        existingTab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
    [self selectTab:existingTab];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* navigationExistingTab = [self tabWithURLString:navigationURLString inGroup:group];
  if (navigationExistingTab) {
    navigationExistingTab.requestedURLString = requestedURLString;
    [self selectTab:navigationExistingTab];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
}
