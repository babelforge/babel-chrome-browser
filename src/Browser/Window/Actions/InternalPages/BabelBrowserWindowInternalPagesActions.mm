#import "Browser/Window/Actions/InternalPages/BabelBrowserWindowInternalPagesActions.h"

#import "Browser/Window/Controller/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowInternalPagesActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)openHistoryPage {
  [owner_ openInternalPageWithURLString:kHistoryPageURLString
                                title:@"History"
                                 html:[owner_ historyPageHTML]];
}

- (void)openSettingsPage {
  [owner_ openInternalPageWithURLString:kSettingsPageURLString
                                title:@"Settings"
                                 html:[owner_ settingsPageHTML]];
}

- (void)openSettingsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_ openInternalPageWithURLString:kSettingsPageURLString
                                title:@"Settings"
                                 html:[owner_ settingsPageHTML]
                              browser:browser];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier {
  [owner_ openModuleSettingsPageForIdentifier:moduleIdentifier browser:nullptr];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier browser:(CefRefPtr<CefBrowser>)browser {
  NSString* normalizedIdentifier = [owner_->moduleSettingsRouteResolver_ normalizedModuleIdentifier:moduleIdentifier];
  NSString* urlString = [NSString stringWithFormat:@"babelchrome://settings/%@",
                                                   [owner_ pathEscapedString:normalizedIdentifier]];
  [owner_ openInternalPageWithURLString:urlString
                                title:@"Module Settings"
                                 html:[owner_ moduleSettingsPageHTMLForIdentifier:normalizedIdentifier]
                              browser:browser];
}

- (void)openExtensionsPage {
  [owner_ openExtensionsPageForBrowser:nullptr];
}

- (void)openExtensionsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_ openInternalPageWithURLString:kExtensionsPageURLString
                                title:@"Extensions"
                                 html:[owner_ extensionsPageHTML]
                              browser:browser];
}

- (void)openModulesPage {
  [owner_ openModulesPageForBrowser:nullptr];
}

- (void)openModulesPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_ openInternalPageWithURLString:kModulesPageURLString
                                title:@"Modules"
                                 html:[owner_ modulesPageHTML]
                              browser:browser];
}

- (NSString*)modulesPageHTML {
  return [owner_->moduleInternalPageHTMLBuilder_ modulesPageHTML];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  return [owner_->moduleInternalPageHTMLBuilder_ moduleDetailsPageHTMLForIdentifier:moduleIdentifier];
}

- (NSString*)moduleUpdatesPageHTML {
  return [owner_->moduleInternalPageHTMLBuilder_ moduleUpdatesPageHTML];
}

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier route:(NSString*)route {
  [owner_ openPHPModuleWithIdentifier:moduleIdentifier
                              route:route
                    sourceURLString:nil
                 requestedURLString:[NSString stringWithFormat:@"babelchrome://modules/%@/%@",
                                                               moduleIdentifier ?: @"",
                                                               route.length > 0 ? route : @"index"]];
}

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier
                              route:(NSString*)route
                    sourceURLString:(NSString*)sourceURLString
                 requestedURLString:(NSString*)requestedURLString {
  NSError* error = nil;
  NSURL* moduleURL = [owner_->moduleActionService_ moduleURLForIdentifier:moduleIdentifier
                                                                    route:route
                                                          sourceURLString:sourceURLString
                                                                    error:&error];
  if (!moduleURL) {
    [owner_->moduleUIActionCoordinator_ showModuleActionAlertWithError:error];
    return;
  }

  if ([moduleURL.scheme isEqualToString:@"babelchrome"]) {
    [owner_ handleInternalNavigationURLString:moduleURL.absoluteString];
    return;
  }

  BabelBrowserGroup* group = [owner_ targetGroupForModuleIdentifier:moduleIdentifier
                                                    fallbackGroup:owner_->selectedGroup_];
  [owner_ selectGroup:group];
  BabelBrowserTab* tab = [owner_ createTabForURL:moduleURL.absoluteString
                                       inGroup:group
                                     parentTab:owner_->selectedTab_];
  tab.requestedURLString = requestedURLString.length > 0 ? requestedURLString : moduleURL.absoluteString;
  [owner_ saveGroupsState];
  [owner_ showMainWindow];
}

- (BOOL)openPHPModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* moduleRoute = [owner_->moduleActionService_ moduleRouteForBabelChromeComponents:components error:&error];
  if (!moduleRoute) {
    if (error) {
      [owner_->moduleUIActionCoordinator_ showModuleActionAlertWithError:error];
    }
    return NO;
  }

  NSString* moduleIdentifier =
      [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
  NSString* route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
  if (moduleIdentifier.length == 0 || route.length == 0) {
    return NO;
  }

  [owner_ openPHPModuleWithIdentifier:moduleIdentifier
                              route:route
                    sourceURLString:urlString
                 requestedURLString:urlString];
  return YES;
}

- (void)importProjectLauncherJSONFromPanel {
  NSURL* importURL = [owner_->projectLauncherJSONImporter_ projectLauncherImportURLFromPanel];
  if (!importURL) {
    return;
  }

  BabelBrowserGroup* group = [owner_ targetGroupForModuleIdentifier:@"babelforge.project-launcher"
                                                    fallbackGroup:owner_->selectedGroup_];
  [owner_ selectGroup:group];
  BabelBrowserTab* tab = [owner_ createTabForURL:importURL.absoluteString
                                       inGroup:group
                                     parentTab:owner_->selectedTab_];
  tab.requestedURLString = @"babelchrome://project-launcher";
  [owner_ saveGroupsState];
  [owner_ showMainWindow];
}
- (BOOL)handleInternalNavigationURLString:(NSString*)urlString {
  return [owner_ handleInternalNavigationURLString:urlString browser:nullptr];
}

- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString {
  BabelBrowserTab* tab = [owner_ tabForBrowser:browser];
  if (!tab || ![owner_->stableServerURLResolver_ stableServerURLStringRequestsStart:urlString]) {
    return NO;
  }

  NSString* navigationURLString = [owner_ navigationURLStringForStableBabelChromeURLString:urlString];
  if (navigationURLString.length == 0) {
    return NO;
  }

  NSString* requestedURLString =
      [owner_->stableServerURLResolver_ stableURLStringByRemovingInternalQueryParameters:urlString];
  NSArray<NSString*>* refreshURLStrings =
      [owner_->stableServerURLResolver_ refreshURLStringsForStableURLString:urlString];
  if (refreshURLStrings.count > 0) {
    [owner_->runtimeRefreshCoordinator_ enqueueRefreshURLStrings:refreshURLStrings
                                    forBrowserIdentifier:browser->GetIdentifier()];
  }

  tab.requestedURLString = requestedURLString;
  tab.urlString = navigationURLString;
  browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  [owner_ saveGroupsState];
  return YES;
}

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString browser:(CefRefPtr<CefBrowser>)browser {
  if (browser && [owner_ navigateBrowser:browser toInternalURLStringInSameTab:urlString]) {
    return YES;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (![components.scheme isEqualToString:@"babelchrome"]) {
    return NO;
  }

  NSString* commandName = components.host ?: @"";
  if ([commandName isEqualToString:@"settings"]) {
    NSString* moduleSettingsIdentifier =
        [owner_->moduleSettingsRouteResolver_ moduleIdentifierFromSettingsComponents:components];
    if (moduleSettingsIdentifier.length > 0) {
      BabelInternalSettingsNavigationResult* result =
          [owner_->internalSettingsNavigationHandler_
              applyModuleSettingsComponents:components
                            moduleIdentifier:[owner_->moduleSettingsRouteResolver_
                                                 normalizedModuleIdentifier:moduleSettingsIdentifier]];
      if (result.markdownThemeDidChange) {
        [owner_ reloadMarkdownViewerTabsUsingCurrentTheme];
      }
      [owner_ openModuleSettingsPageForIdentifier:moduleSettingsIdentifier browser:browser];
      return YES;
    }

    BabelInternalSettingsNavigationResult* result =
        [owner_->internalSettingsNavigationHandler_ applyApplicationSettingsComponents:components];
    if (result.markdownThemeDidChange) {
      [owner_ reloadMarkdownViewerTabsUsingCurrentTheme];
    }
    if (result.appearanceThemeDidChange) {
      [owner_ applyThemeColors];
      [owner_ layoutTabItemsSelectingLastTab:NO];
      [owner_ layoutGroupItems];
    }
    [owner_ openSettingsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"extensions"]) {
    BabelInternalExtensionsNavigationResult* result =
        [owner_->internalExtensionsNavigationHandler_ handleExtensionsComponents:components];
    if (result.searchQuery.length > 0) {
      [owner_ openChromeWebStoreSearchForQuery:result.searchQuery];
    }

    if (result.shouldRestartApplication) {
      [owner_ restartApplication];
      return YES;
    }

    [owner_ openExtensionsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"modules"]) {
    BabelInternalNavigationAction* action =
        [owner_->internalNavigationActionParser_ modulesActionFromComponents:components];
    BabelInternalModuleNavigationResult* result =
        [owner_->internalModuleNavigationHandler_ handleModuleAction:action];
    if (result.fileTypeCapabilitiesDidChange) {
      [owner_ refreshBabelChromeFileTypeCapabilities];
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationUpdates]) {
      [owner_ openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[owner_ moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationDetails]) {
      NSString* urlString = [NSString stringWithFormat:@"babelchrome://modules?module=%@",
                                                       [owner_ queryEscapedString:result.moduleIdentifier]];
      [owner_ openInternalPageWithURLString:urlString
                                    title:@"Module"
                                     html:[owner_ moduleDetailsPageHTMLForIdentifier:result.moduleIdentifier]
                                  browser:browser];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationOpenModule]) {
      [owner_ openPHPModuleWithIdentifier:result.moduleIdentifier route:result.route];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationModules]) {
      [owner_ openModulesPageForBrowser:browser];
      return YES;
    }

    [owner_ openModulesPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"project-launcher"]) {
    if ([components.path isEqualToString:@"/import-config"]) {
      [owner_ importProjectLauncherJSONFromPanel];
      return YES;
    }
  }

  if ([commandName isEqualToString:@"history"]) {
    BabelInternalNavigationAction* action =
        [owner_->internalNavigationActionParser_ historyActionFromComponents:components];
    if ([action.name isEqualToString:BabelInternalNavigationActionReopen]) {
      NSInteger closedTabIndex = action.value.integerValue;
      if (closedTabIndex >= 0) {
        [owner_ reopenClosedTabAtIndex:(NSUInteger)closedTabIndex];
      }
      return YES;
    }

    [owner_ openHistoryPage];
    return YES;
  }

  if ([commandName isEqualToString:@"open"]) {
    NSURL* commandURL = [NSURL URLWithString:urlString];
    if (commandURL) {
      [owner_ openBabelChromeCommandURL:commandURL];
    } else {
      [owner_ openCompactBabelChromeCommandString:urlString];
    }
    return YES;
  }

  if ([owner_->stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    [owner_ navigateSelectedTabToViewerURLString:urlString];
    return YES;
  }

  if ([owner_ openPHPModuleURLString:urlString]) {
    return YES;
  }

  return NO;
}
- (void)navigateSelectedTabToViewerURLString:(NSString*)urlString {
  NSString* requestedURLString = [owner_ stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [owner_ navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    return;
  }

  if ([navigationURLString hasPrefix:@"babelchrome://settings/"]) {
    [owner_ handleInternalNavigationURLString:navigationURLString
                                      browser:owner_->selectedTab_ ? [owner_->selectedTab_ browser] : nullptr];
    return;
  }

  BabelBrowserGroup* group = owner_->selectedGroup_ ?: [owner_ ensureGroupNamed:kDefaultGroupName];
  [owner_ selectGroup:group];

  if (!owner_->selectedTab_) {
    BabelBrowserTab* tab = [owner_ createTabForURL:navigationURLString inGroup:group];
    tab.requestedURLString = requestedURLString;
    [owner_ saveGroupsState];
    return;
  }

  owner_->selectedTab_.urlString = navigationURLString;
  owner_->selectedTab_.requestedURLString = requestedURLString;
  [owner_ updateAddressBarForTab:owner_->selectedTab_];

  if ([owner_->selectedTab_ browser]) {
    [owner_->selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  } else {
    [owner_ selectTab:owner_->selectedTab_];
  }

  [owner_ saveGroupsState];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html {
  [owner_ openInternalPageWithURLString:internalURLString
                                title:title
                                 html:html
                              browser:nullptr];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser {
  [owner_->internalPageNavigator_ openInternalPageWithURLString:internalURLString
                                                 title:title
                                                  html:html
                                               browser:browser];
}

- (NSString*)dataURLStringForHTML:(NSString*)html {
  return [owner_->htmlDataURLBuilder_ dataURLStringForHTML:html];
}
- (NSString*)historyPageHTML {
  return [owner_->internalPageHTMLComposer_ historyPageHTMLWithGroups:owner_->groups_];
}

- (NSString*)settingsPageHTML {
  return [owner_->internalPageHTMLComposer_ settingsPageHTMLWithDefaultURLString:BabelChromeConfiguration.defaultURLString
                                                         appearanceTheme:[BabelTheme.sharedTheme appearanceMode]
                                                longQuitShortcutEnabled:[owner_->browserSettingsStore_ longQuitShortcutEnabled]
                                                     tabOpeningStrategy:[owner_ tabOpeningStrategy]
                                                 addressSuggestionsMode:[owner_ addressSuggestionsMode]];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier = [owner_->moduleSettingsRouteResolver_ normalizedModuleIdentifier:moduleIdentifier];
  NSString* moduleName = [owner_->moduleSettingsRouteResolver_ moduleNameForIdentifier:normalizedIdentifier] ?: normalizedIdentifier;
  NSDictionary* requiredSettingsStatus =
      [owner_->moduleActionService_ requiredSettingsStatusForModuleWithIdentifier:normalizedIdentifier
                                                                            error:nil] ?:
      @{};
  return [owner_->internalPageHTMLComposer_ moduleSettingsPageHTMLForIdentifier:normalizedIdentifier
                                                             moduleName:moduleName
                                                          markdownTheme:[owner_ markdownTheme]
                                                 requiredSettingsStatus:requiredSettingsStatus];
}

- (NSString*)extensionsPageHTML {
  return [owner_->internalPageHTMLComposer_ extensionsPageHTML];
}
- (void)openChromeWebStoreSearchForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedQuery.length == 0) {
    return;
  }

  NSString* urlString = [NSString stringWithFormat:@"https://chromewebstore.google.com/search/%@",
                                                   [owner_ pathEscapedString:trimmedQuery]];
  [owner_ openURLStringInNewTab:urlString];
}

- (void)showLocalServiceStartupAlert:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Start Local Viewer";
  alert.informativeText = error.localizedDescription ?: @"BabelChrome could not start the local file viewer service.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}
- (NSString*)queryEscapedString:(NSString*)value {
  return [owner_->browserStringFormatter_ queryEscapedString:value];
}

- (NSString*)pathEscapedString:(NSString*)value {
  return [owner_->browserStringFormatter_ pathEscapedString:value];
}

- (NSString*)trashIconHTML {
  return [owner_->internalPageAssetProvider_ trashIconHTML];
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  return [owner_->internalPageAssetProvider_ resourceSVGIconHTMLNamed:resourceName fallback:fallbackHTML];
}

- (void)restartApplication {
  NSString* bundlePath = NSBundle.mainBundle.bundlePath;
  [owner_->applicationRelauncher_ scheduleRelaunchForBundlePath:bundlePath
                                      processIdentifier:NSProcessInfo.processInfo.processIdentifier];
  [owner_ requestApplicationTermination];
}

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  return [owner_->internalPageRenderer_ internalPageHTMLWithTitle:title body:body];
}


@end
