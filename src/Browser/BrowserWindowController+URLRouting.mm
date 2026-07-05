#import "Browser/BrowserWindowController+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation BabelBrowserWindowController (URLRouting)

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
    if ([stableViewerURLResolver_ isStableViewerURLString:url.absoluteString]) {
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
  BabelChromeCommand* command = [chromeCommandParser_ commandFromURL:url];
  [self openURLString:command.urlString groupName:command.groupName];
}

- (BOOL)openCompactBabelChromeCommandString:(NSString*)urlString {
  BabelChromeCommand* command = [chromeCommandParser_ compactCommandFromURLString:urlString];
  if (!command) {
    return NO;
  }

  [self openURLString:command.urlString groupName:command.groupName];
  return YES;
}

- (void)openURLString:(NSString*)urlString groupName:(NSString*)groupName {
  BabelBrowserGroup* group = [self ensureGroupNamed:groupName];
  [self selectGroup:group];

  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
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
  NSError* serviceError = nil;
  NSString* viewerURLString =
      [viewerNavigationURLResolver_ navigationURLStringForStableViewerURLString:urlString
                                                                 markdownTheme:[self markdownTheme]
                                                                         error:&serviceError];
  if (serviceError) {
    [self showLocalServiceStartupAlert:serviceError];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  return [viewerNavigationURLResolver_ noViewerInstalledPageURLStringForStableViewerURLString:urlString];
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  return [viewerNavigationURLResolver_ stableViewerURLStringForSupportedURLString:urlString];
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  if (![self isStableBabelChromeURLString:urlString]) {
    return nil;
  }

  NSString* viewerURLString = [self viewerURLStringForSupportedURLString:urlString];
  if (viewerURLString.length > 0) {
    return viewerURLString;
  }

  if ([stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    return [self noViewerInstalledPageURLStringForStableViewerURLString:urlString];
  }

  return [self moduleNavigationURLStringForStableBabelChromeURLString:urlString];
}

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString {
  return [stableServerURLResolver_ isStableBabelChromeURLString:urlString];
}

- (BOOL)isStableServerURLString:(NSString*)urlString {
  return [stableServerURLResolver_ isStableServerURLString:urlString];
}

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString {
  return [stableServerURLResolver_ stableServerURLStringRequestsStart:urlString];
}

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString {
  return [stableServerURLResolver_ refreshURLStringsForStableURLString:urlString];
}

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString {
  return [stableServerURLResolver_ stableURLStringByRemovingInternalQueryParameters:urlString];
}

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components {
  return [stableServerURLResolver_ stableServerProjectPathForURLComponents:components];
}

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab {
  return [stableServerURLResolver_ stableServerReloadURLStringForRequestedURLString:tab.requestedURLString
                                                                    actualURLString:tab.urlString];
}

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  return [moduleNavigationURLResolver_ navigationURLStringForStableBabelChromeURLString:urlString];
}
- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser {
  return [browserTabLookupService_ tabForBrowser:browser groups:groups_];
}

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString {
  return [localServiceURLClassifier_ isLocalServiceModuleURLString:urlString];
}

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString {
  return [localServiceURLClassifier_ isLocalServiceRuntimeURLString:urlString];
}

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString {
  return [localServiceURLClassifier_ isProjectLauncherModuleURLString:urlString];
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesRefreshURLString:(NSString*)requestedURLString {
  return [runtimeRefreshTabMatcher_ tabRequestedURLString:tab.requestedURLString
                                       tabActualURLString:tab.urlString
                                  matchesRefreshURLString:requestedURLString];
}

- (void)reloadTabsWithRequestedURLString:(NSString*)requestedURLString excludingTab:(BabelBrowserTab*)excludedTab {
  if ([stableURLTabReloader_ reloadTabsWithRequestedURLString:requestedURLString
                                                 excludingTab:excludedTab
                                                       groups:groups_]) {
    [self saveGroupsState];
  }
}

- (void)reloadRequestedURLStrings:(NSArray<NSString*>*)requestedURLStrings excludingTab:(BabelBrowserTab*)excludedTab {
  for (NSString* requestedURLString in requestedURLStrings) {
    [self reloadTabsWithRequestedURLString:requestedURLString excludingTab:excludedTab];
  }
}

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString {
  return [stableServerURLResolver_ serverProjectIdentifierForStableURLString:urlString];
}

- (void)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers {
  if ([stableURLTabReloader_ reloadServerTabsWithProjectIdentifiers:projectIdentifiers
                                                             groups:groups_]) {
    [self saveGroupsState];
  }
}

@end

#pragma clang diagnostic pop
