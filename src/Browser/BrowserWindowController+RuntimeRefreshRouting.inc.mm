// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        return tab;
      }
    }
  }

  return nil;
}

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path hasPrefix:@"/module/"];
}

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.host isEqualToString:@"127.0.0.1"] ||
      (![components.scheme isEqualToString:@"http"] && ![components.scheme isEqualToString:@"https"])) {
    return NO;
  }

  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:@"token"] && item.value.length > 0) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path isEqualToString:@"/module/babelforge.project-launcher/index"];
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesRefreshURLString:(NSString*)requestedURLString {
  if ([tab.requestedURLString isEqualToString:requestedURLString]) {
    return YES;
  }

  if ([requestedURLString isEqualToString:@"babelchrome://project-launcher"] &&
      [self isProjectLauncherModuleURLString:tab.urlString]) {
    return YES;
  }

  if (![self isStableServerURLString:requestedURLString]) {
    return NO;
  }

  NSString* requestedProjectIdentifier =
      [self serverProjectIdentifierForStableURLString:requestedURLString];
  NSString* tabProjectIdentifier =
      [self serverProjectIdentifierForStableURLString:tab.requestedURLString];
  return requestedProjectIdentifier.length > 0 &&
         [requestedProjectIdentifier isEqualToString:tabProjectIdentifier];
}

- (void)reloadTabsWithRequestedURLString:(NSString*)requestedURLString excludingTab:(BabelBrowserTab*)excludedTab {
  if (![self isStableBabelChromeURLString:requestedURLString]) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab == excludedTab || ![self tab:tab matchesRefreshURLString:requestedURLString]) {
        continue;
      }

      NSString* stableURLString =
          [self isStableServerURLString:requestedURLString] ? tab.requestedURLString : requestedURLString;
      NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:stableURLString];
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
  }

  [self saveGroupsState];
}

- (void)reloadRequestedURLStrings:(NSArray<NSString*>*)requestedURLStrings excludingTab:(BabelBrowserTab*)excludedTab {
  for (NSString* requestedURLString in requestedURLStrings) {
    [self reloadTabsWithRequestedURLString:requestedURLString excludingTab:excludedTab];
  }
}

- (NSArray<NSString*>*)restoredProjectIdentifiersFromLifecycleResponse:(NSDictionary*)response {
  NSMutableArray<NSString*>* identifiers = [NSMutableArray array];
  NSArray* results = [response[@"results"] isKindOfClass:NSArray.class] ? response[@"results"] : @[];
  for (NSDictionary* result in results) {
    if (![result isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSDictionary* payload = [result[@"payload"] isKindOfClass:NSDictionary.class] ? result[@"payload"] : nil;
    NSArray* restored = [payload[@"restored"] isKindOfClass:NSArray.class] ? payload[@"restored"] : @[];
    for (NSString* identifier in restored) {
      if ([identifier isKindOfClass:NSString.class] && identifier.length > 0 &&
          ![identifiers containsObject:identifier]) {
        [identifiers addObject:identifier];
      }
    }
  }

  return identifiers;
}

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString {
  return [stableServerURLResolver_ serverProjectIdentifierForStableURLString:urlString];
}

- (void)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers {
  NSSet<NSString*>* identifierSet = [NSSet setWithArray:projectIdentifiers];
  if (identifierSet.count == 0) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      NSString* projectIdentifier =
          [self serverProjectIdentifierForStableURLString:tab.requestedURLString];
      if (projectIdentifier.length == 0 || ![identifierSet containsObject:projectIdentifier]) {
        continue;
      }

      NSString* navigationURLString =
          [self navigationURLStringForStableBabelChromeURLString:tab.requestedURLString];
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
  }

  [self saveGroupsState];
}
