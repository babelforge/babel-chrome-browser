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

- (NSString*)viewerURLStringForSupportedURLString:(NSString*)urlString {
  NSURL* url = [self sourceURLForViewerURLString:urlString];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSError* serviceError = nil;
  if (![BabelLocalServiceHost.sharedHost startIfNeededWithError:&serviceError]) {
    [self showLocalServiceStartupAlert:serviceError];
    return nil;
  }

  NSURL* viewerURL = [BabelLocalServiceHost.sharedHost viewerURLForURL:url];
  NSURLComponents* viewerComponents = viewerURL ? [NSURLComponents componentsWithURL:viewerURL
                                                             resolvingAgainstBaseURL:NO] : nil;
  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString];
  if (viewerKind.length == 0) {
    viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  }
  if (viewerComponents && [viewerKind isEqualToString:@"markdown"]) {
    NSMutableArray<NSURLQueryItem*>* queryItems =
        [viewerComponents.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"theme" value:[self markdownTheme]]];
    viewerComponents.queryItems = queryItems;
    viewerURL = viewerComponents.URL;
  }

  NSString* viewerURLString = viewerURL.absoluteString;
  NSString* fragment = [self stableViewerFragmentForURLString:urlString];
  if (viewerURLString.length > 0 && fragment.length > 0) {
    return [viewerURLString stringByAppendingString:fragment];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  NSString* sourceDisplayString = sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString;
  if (sourceDisplayString.length == 0) {
    sourceDisplayString = urlString ?: @"";
  }

  NSString* extension = sourceURL.pathExtension.lowercaseString ?: @"";
  NSString* title = @"No viewer installed for this file type";
  NSString* detail = extension.length > 0
      ? [NSString stringWithFormat:@"No enabled BabelChrome viewer module currently handles .%@ files.", extension]
      : @"No enabled BabelChrome viewer module currently handles this source.";
  NSString* html = [NSString stringWithFormat:
      @"<!doctype html>"
       "<html><head><meta charset='utf-8'>"
       "<style>"
       "body{margin:0;background:#f5f6f8;color:#1f2328;font:15px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;}"
       "main{max-width:760px;margin:92px auto;padding:0 28px;}"
       "h1{font-size:28px;line-height:1.2;margin:0 0 14px;font-weight:700;}"
       "p{line-height:1.55;margin:0 0 18px;color:#59636e;}"
       "code{display:block;background:#fff;border:1px solid #d8dee4;border-radius:8px;padding:14px 16px;white-space:pre-wrap;word-break:break-all;color:#1f2328;}"
       "</style></head><body><main>"
       "<h1>%@</h1>"
       "<p>%@</p>"
       "<code>%@</code>"
       "</main></body></html>",
      [self htmlEscapedString:title],
      [self htmlEscapedString:detail],
      [self htmlEscapedString:sourceDisplayString]];
  return [self dataURLStringForHTML:html];
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  if ([self isStableViewerURLString:urlString]) {
    return urlString;
  }

  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSString* viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  if (viewerKind.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceKind = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* encodedSourceValue = [self stableViewerEscapedString:sourceValue];
  if (encodedSourceValue.length == 0) {
    return nil;
  }

  return [NSString stringWithFormat:@"babelchrome://%@/%@/%@",
                                    viewerKind,
                                    sourceKind,
                                    encodedSourceValue];
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  if (![self isStableBabelChromeURLString:urlString]) {
    return nil;
  }

  NSString* viewerURLString = [self viewerURLStringForSupportedURLString:urlString];
  if (viewerURLString.length > 0) {
    return viewerURLString;
  }

  if ([self isStableViewerURLString:urlString]) {
    return [self noViewerInstalledPageURLStringForStableViewerURLString:urlString];
  }

  return [self moduleNavigationURLStringForStableBabelChromeURLString:urlString];
}

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0;
}

- (BOOL)isStableServerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] &&
         [components.host isEqualToString:@"server"] &&
         components.path.length > 1;
}

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString {
  if (![self isStableServerURLString:urlString]) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kInternalStartQueryParameter] &&
        ![item.value isEqualToString:@"0"]) {
      return YES;
    }
  }

  return NO;
}

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSMutableArray<NSString*>* refreshURLStrings = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if (![item.name isEqualToString:kInternalRefreshQueryParameter] || item.value.length == 0) {
      continue;
    }

    NSString* refreshURLString = item.value.stringByRemovingPercentEncoding ?: item.value;
    if ([self isStableBabelChromeURLString:refreshURLString]) {
      [refreshURLStrings addObject:refreshURLString];
    }
  }

  return refreshURLStrings;
}

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (!components) {
    return urlString;
  }

  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kInternalStartQueryParameter] ||
        [item.name isEqualToString:kInternalRefreshQueryParameter]) {
      continue;
    }

    [queryItems addObject:item];
  }

  components.queryItems = queryItems.count > 0 ? queryItems : nil;
  return components.string ?: urlString;
}

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components {
  NSString* path = components.percentEncodedPath ?: components.path ?: @"";
  NSArray<NSString*>* pathComponents = [path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 2 && pathComponents[1].length > 0) {
    return [@"/" stringByAppendingString:pathComponents[1]];
  }

  return path.length > 0 ? path : @"/";
}

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab {
  NSString* requestedURLString = tab.requestedURLString ?: @"";
  if (![self isStableServerURLString:requestedURLString]) {
    return requestedURLString;
  }

  NSURLComponents* requestedComponents =
      [NSURLComponents componentsWithString:requestedURLString];
  NSURLComponents* actualComponents =
      [NSURLComponents componentsWithString:tab.urlString ?: @""];
  NSString* actualScheme = actualComponents.scheme.lowercaseString ?: @"";
  if (![actualScheme isEqualToString:@"http"] && ![actualScheme isEqualToString:@"https"]) {
    return requestedURLString;
  }

  NSString* actualPath = actualComponents.percentEncodedPath ?: actualComponents.path ?: @"";
  if ([actualPath hasPrefix:@"/module/"]) {
    return requestedURLString;
  }

  NSString* projectPath = [self stableServerProjectPathForURLComponents:requestedComponents];
  if (actualPath.length > 0 && ![actualPath isEqualToString:@"/"]) {
    requestedComponents.percentEncodedPath = [projectPath stringByAppendingString:actualPath];
  } else {
    requestedComponents.percentEncodedPath = projectPath;
  }

  requestedComponents.percentEncodedQuery = actualComponents.percentEncodedQuery;
  requestedComponents.percentEncodedFragment = actualComponents.percentEncodedFragment;

  return requestedComponents.string ?: requestedURLString;
}

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* moduleIdentifier = nil;
  NSString* route = nil;
  NSString* sourceURLString = nil;
  if ([components.host isEqualToString:@"modules"]) {
    NSArray<NSString*>* pathComponents = [components.path pathComponents];
    if (pathComponents.count >= 3) {
      moduleIdentifier = pathComponents[1];
      route = pathComponents[2];
    }
  } else {
    NSError* error = nil;
    NSDictionary* moduleRoute = [self moduleRouteForBabelChromeComponents:components error:&error];
    if (!moduleRoute) {
      return nil;
    }

    moduleIdentifier =
        [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
    route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
    sourceURLString = urlString;
  }

  if (moduleIdentifier.length == 0 || route.length == 0) {
    return nil;
  }

  NSError* error = nil;
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                                       route:route
                                                             sourceURLString:sourceURLString
                                                                       error:&error];
  return moduleURL.absoluteString;
}

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
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] ||
      ![components.host isEqualToString:@"server"]) {
    return @"";
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count < 2) {
    return @"";
  }

  return pathComponents[1].stringByRemovingPercentEncoding ?: pathComponents[1];
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

- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![self stableServerURLStringRequestsStart:urlString]) {
    return NO;
  }

  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:urlString];
  if (navigationURLString.length == 0) {
    return NO;
  }

  NSString* requestedURLString = [self stableURLStringByRemovingInternalQueryParameters:urlString];
  NSArray<NSString*>* refreshURLStrings = [self refreshURLStringsForStableURLString:urlString];
  if (refreshURLStrings.count > 0) {
    pendingRefreshURLStringsByBrowserIdentifier_[@(browser->GetIdentifier())] = refreshURLStrings;
  }

  tab.requestedURLString = requestedURLString;
  tab.urlString = navigationURLString;
  browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  [self saveGroupsState];
  return YES;
}

- (BOOL)isStableViewerURLString:(NSString*)urlString {
  return [self viewerKindForStableViewerURLString:urlString].length > 0 &&
         [self sourceKindForStableViewerURLString:urlString].length > 0;
}

- (NSURL*)sourceURLForViewerURLString:(NSString*)urlString {
  NSString* sourceKind = nil;
  NSString* encodedSourceValue = nil;
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if ([components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0) {
    NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
    if (pathComponents.count >= 3) {
      NSString* candidateSourceKind = pathComponents[1];
      if ([candidateSourceKind isEqualToString:@"file"] || [candidateSourceKind isEqualToString:@"url"]) {
        sourceKind = candidateSourceKind;
        NSString* prefix = [NSString stringWithFormat:@"/%@/", candidateSourceKind];
        encodedSourceValue = [components.path hasPrefix:prefix]
            ? [components.path substringFromIndex:prefix.length]
            : @"";
      }
    }
  }

  if (encodedSourceValue.length > 0) {
    NSString* sourceValue = encodedSourceValue.stringByRemovingPercentEncoding ?: encodedSourceValue;
    if ([sourceKind isEqualToString:@"file"]) {
      return [NSURL fileURLWithPath:sourceValue];
    }
    return [NSURL URLWithString:sourceValue];
  }

  return [NSURL URLWithString:urlString ?: @""];
}

- (NSString*)stableViewerFragmentForURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return @"";
  }

  NSRange fragmentRange = [urlString rangeOfString:@"#"];
  if (fragmentRange.location == NSNotFound) {
    return @"";
  }

  return [urlString substringFromIndex:fragmentRange.location];
}

- (NSString*)stableViewerEscapedString:(NSString*)value {
  NSMutableCharacterSet* allowedCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
  [allowedCharacters addCharactersInString:@"-._~"];
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)viewerKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  return sourceKind.length > 0 ? components.host : nil;
}

- (NSString*)resolvedViewerKindForStableViewerURLString:(NSString*)urlString {
  NSString* viewerKind = [self viewerKindForStableViewerURLString:urlString];
  if (![viewerKind isEqualToString:@"viewer"]) {
    return viewerKind;
  }

  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (!sourceURL) {
    return nil;
  }

  return [BabelLocalServiceHost.sharedHost viewerKindForURL:sourceURL];
}

- (NSString*)sourceKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 3 &&
      ([pathComponents[1] isEqualToString:@"file"] || [pathComponents[1] isEqualToString:@"url"])) {
    return pathComponents[1];
  }
  return nil;
}

- (NSString*)displayURLStringForStableViewerURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return urlString ?: @"";
  }

  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString] ?:
      [self viewerKindForStableViewerURLString:urlString];
  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (viewerKind.length == 0 || sourceKind.length == 0 || !sourceURL) {
    return urlString.stringByRemovingPercentEncoding ?: urlString ?: @"";
  }

  NSString* sourceDisplayString = [sourceKind isEqualToString:@"file"]
      ? sourceURL.path
      : sourceURL.absoluteString;
  NSString* fragment = [self stableViewerFragmentForURLString:urlString];

  return [sourceDisplayString stringByAppendingString:fragment ?: @""];
}
