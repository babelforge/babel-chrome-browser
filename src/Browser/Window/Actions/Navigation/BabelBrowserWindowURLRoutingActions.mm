#import "Browser/Window/Actions/Navigation/BabelBrowserWindowURLRoutingActions.h"

#import "Browser/Window/Controller/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowURLRoutingActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)openURLs:(NSArray<NSURL*>*)urls {
  if (urls.count == 0 && [owner_ totalTabCount] > 0) {
    [owner_ showMainWindow];
    [owner_ saveGroupsState];
    return;
  }

  NSArray<NSURL*>* urlsToOpen = urls.count > 0
      ? urls
      : @[ [NSURL URLWithString:BabelChromeConfiguration.defaultURLString] ];

  for (NSURL* url in urlsToOpen) {
    [owner_ openURL:url];
  }

  [owner_ showMainWindow];
  [owner_ saveGroupsState];
}

- (void)openNewTab {
  BabelBrowserGroup* group = owner_->selectedGroup_ ?: [owner_ ensureGroupNamed:kDefaultGroupName];
  [owner_ createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [owner_ showMainWindow];
  [owner_ saveGroupsState];
}

- (void)openAdjacentNewTab {
  BabelBrowserGroup* group = owner_->selectedGroup_ ?: [owner_ ensureGroupNamed:kDefaultGroupName];
  if (owner_->selectedTab_ && [group.tabs containsObject:owner_->selectedTab_]) {
    [owner_ createTabForURL:BabelChromeConfiguration.defaultURLString
                  inGroup:group
                parentTab:owner_->selectedTab_
     respectingUserStrategy:NO];
  } else {
    [owner_ createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  }
  [owner_ showMainWindow];
  [owner_ saveGroupsState];
}

- (void)openNewTabFromButton:(id)sender {
  [owner_ openNewTab];
}

- (void)scheduleQueuedURLOpening {
}

- (void)drainQueuedURLOpening {
}

- (void)openURL:(NSURL*)url {
  if ([url.scheme isEqualToString:@"babelchrome"]) {
    if ([owner_->stableViewerURLResolver_ isStableViewerURLString:url.absoluteString]) {
      [owner_ openURLString:url.absoluteString groupName:kDefaultGroupName];
      return;
    }
    if ([owner_ handleInternalNavigationURLString:url.absoluteString]) {
      return;
    }
    [owner_ openBabelChromeCommandURL:url];
    return;
  }

  [owner_ openURLString:url.absoluteString groupName:kDefaultGroupName];
}

- (void)openBabelChromeCommandURL:(NSURL*)url {
  BabelChromeCommand* command = [owner_->chromeCommandParser_ commandFromURL:url];
  [owner_ openURLString:command.urlString groupName:command.groupName];
}

- (BOOL)openCompactBabelChromeCommandString:(NSString*)urlString {
  BabelChromeCommand* command = [owner_->chromeCommandParser_ compactCommandFromURLString:urlString];
  if (!command) {
    return NO;
  }

  [owner_ openURLString:command.urlString groupName:command.groupName];
  return YES;
}

- (void)openURLString:(NSString*)urlString groupName:(NSString*)groupName {
  BabelBrowserGroup* group = [owner_ ensureGroupNamed:groupName];
  [owner_ selectGroup:group];

  NSString* requestedURLString = [owner_ stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [owner_ navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([owner_->stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        [owner_ stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }

  if ([navigationURLString hasPrefix:@"babelchrome://settings/"]) {
    [owner_ handleInternalNavigationURLString:navigationURLString];
    return;
  }

  BabelBrowserTab* existingTab = [owner_ tabWithURLString:requestedURLString inGroup:group] ?:
      [owner_ tabWithURLString:urlString inGroup:group];
  if (existingTab) {
    if (![existingTab.urlString isEqualToString:navigationURLString]) {
      existingTab.urlString = navigationURLString;
      existingTab.requestedURLString = requestedURLString;
      if ([existingTab browser]) {
        existingTab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
    }
    [owner_ selectTab:existingTab];
    [owner_ saveGroupsState];
    return;
  }

  BabelBrowserTab* navigationExistingTab = [owner_ tabWithURLString:navigationURLString inGroup:group];
  if (navigationExistingTab) {
    navigationExistingTab.requestedURLString = requestedURLString;
    [owner_ selectTab:navigationExistingTab];
    [owner_ saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [owner_ createTabForURL:navigationURLString inGroup:group];
  tab.requestedURLString = requestedURLString;
  if (tab == owner_->selectedTab_) {
    [owner_ updateAddressBarForTab:tab];
  }
  [owner_ saveGroupsState];
}
- (NSString*)viewerURLStringForSupportedURLString:(NSString*)urlString {
  NSError* serviceError = nil;
  NSString* viewerURLString =
      [owner_->viewerNavigationURLResolver_ navigationURLStringForStableViewerURLString:urlString
                                                                 markdownTheme:[owner_ markdownTheme]
                                                                         error:&serviceError];
  if (serviceError) {
    [owner_ showLocalServiceStartupAlert:serviceError];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  return [owner_->viewerNavigationURLResolver_ noViewerInstalledPageURLStringForStableViewerURLString:urlString];
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  return [owner_->viewerNavigationURLResolver_ stableViewerURLStringForSupportedURLString:urlString];
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  if (![owner_ isStableBabelChromeURLString:urlString]) {
    return nil;
  }

  NSString* viewerURLString = [owner_ viewerURLStringForSupportedURLString:urlString];
  if (viewerURLString.length > 0) {
    return viewerURLString;
  }

  if ([owner_->stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    return [owner_ noViewerInstalledPageURLStringForStableViewerURLString:urlString];
  }

  return [owner_ moduleNavigationURLStringForStableBabelChromeURLString:urlString];
}

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ isStableBabelChromeURLString:urlString];
}

- (BOOL)isStableServerURLString:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ isStableServerURLString:urlString];
}

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ stableServerURLStringRequestsStart:urlString];
}

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ refreshURLStringsForStableURLString:urlString];
}

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ stableURLStringByRemovingInternalQueryParameters:urlString];
}

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components {
  return [owner_->stableServerURLResolver_ stableServerProjectPathForURLComponents:components];
}

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab {
  return [owner_->stableServerURLResolver_ stableServerReloadURLStringForRequestedURLString:tab.requestedURLString
                                                                    actualURLString:tab.urlString];
}

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  return [owner_->moduleNavigationURLResolver_ navigationURLStringForStableBabelChromeURLString:urlString];
}
- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser {
  return [owner_->browserTabLookupService_ tabForBrowser:browser groups:owner_->groups_];
}

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString {
  return [owner_->localServiceURLClassifier_ isLocalServiceModuleURLString:urlString];
}

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString {
  return [owner_->localServiceURLClassifier_ isLocalServiceRuntimeURLString:urlString];
}

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString {
  return [owner_->localServiceURLClassifier_ isProjectLauncherModuleURLString:urlString];
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesRefreshURLString:(NSString*)requestedURLString {
  return [owner_->runtimeRefreshTabMatcher_ tabRequestedURLString:tab.requestedURLString
                                       tabActualURLString:tab.urlString
                                  matchesRefreshURLString:requestedURLString];
}

- (void)reloadTabsWithRequestedURLString:(NSString*)requestedURLString excludingTab:(BabelBrowserTab*)excludedTab {
  if ([owner_->stableURLTabReloader_ reloadTabsWithRequestedURLString:requestedURLString
                                                 excludingTab:excludedTab
                                                       groups:owner_->groups_]) {
    [owner_ saveGroupsState];
  }
}

- (void)reloadRequestedURLStrings:(NSArray<NSString*>*)requestedURLStrings excludingTab:(BabelBrowserTab*)excludedTab {
  for (NSString* requestedURLString in requestedURLStrings) {
    [owner_ reloadTabsWithRequestedURLString:requestedURLString excludingTab:excludedTab];
  }
}

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString {
  return [owner_->stableServerURLResolver_ serverProjectIdentifierForStableURLString:urlString];
}

- (void)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers {
  if ([owner_->stableURLTabReloader_ reloadServerTabsWithProjectIdentifiers:projectIdentifiers
                                                             groups:owner_->groups_]) {
    [owner_ saveGroupsState];
  }
}


@end
