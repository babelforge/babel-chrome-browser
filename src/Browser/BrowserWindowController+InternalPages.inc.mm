// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)openHistoryPage {
  [self openInternalPageWithURLString:kHistoryPageURLString
                                title:@"History"
                                 html:[self historyPageHTML]];
}

- (void)openSettingsPage {
  [self openSettingsPageForBrowser:nullptr];
}

- (void)openSettingsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kSettingsPageURLString
                                title:@"Settings"
                                 html:[self settingsPageHTML]
                              browser:browser];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier {
  [self openModuleSettingsPageForIdentifier:moduleIdentifier browser:nullptr];
}

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier browser:(CefRefPtr<CefBrowser>)browser {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  NSString* urlString = [NSString stringWithFormat:@"babelchrome://settings/%@",
                                                   [self pathEscapedString:normalizedIdentifier]];
  [self openInternalPageWithURLString:urlString
                                title:@"Module Settings"
                                 html:[self moduleSettingsPageHTMLForIdentifier:normalizedIdentifier]
                              browser:browser];
}

- (void)openExtensionsPage {
  [self openExtensionsPageForBrowser:nullptr];
}

- (void)openExtensionsPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kExtensionsPageURLString
                                title:@"Extensions"
                                 html:[self extensionsPageHTML]
                              browser:browser];
}

- (void)openModulesPage {
  [self openModulesPageForBrowser:nullptr];
}

- (void)openModulesPageForBrowser:(CefRefPtr<CefBrowser>)browser {
  [self openInternalPageWithURLString:kModulesPageURLString
                                title:@"Modules"
                                 html:[self modulesPageHTML]
                              browser:browser];
}

- (NSString*)modulesPageHTML {
  return [moduleInternalPageHTMLBuilder_ modulesPageHTML];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  return [moduleInternalPageHTMLBuilder_ moduleDetailsPageHTMLForIdentifier:moduleIdentifier];
}

- (NSString*)moduleUpdatesPageHTML {
  return [moduleInternalPageHTMLBuilder_ moduleUpdatesPageHTML];
}

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier route:(NSString*)route {
  [self openPHPModuleWithIdentifier:moduleIdentifier
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
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                                       route:route
                                                             sourceURLString:sourceURLString
                                                                       error:&error];
  if (!moduleURL) {
    [moduleUIActionCoordinator_ showModuleActionAlertWithError:error];
    return;
  }

  BabelBrowserGroup* group = [self targetGroupForModuleIdentifier:moduleIdentifier
                                                    fallbackGroup:selectedGroup_];
  [self selectGroup:group];
  BabelBrowserTab* tab = [self createTabForURL:moduleURL.absoluteString
                                       inGroup:group
                                     parentTab:selectedTab_];
  tab.requestedURLString = requestedURLString.length > 0 ? requestedURLString : moduleURL.absoluteString;
  [self saveGroupsState];
  [self showMainWindow];
}

- (BOOL)openPHPModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* moduleRoute = [moduleActionService_ moduleRouteForBabelChromeComponents:components error:&error];
  if (!moduleRoute) {
    if (error) {
      [moduleUIActionCoordinator_ showModuleActionAlertWithError:error];
    }
    return NO;
  }

  NSString* moduleIdentifier =
      [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
  NSString* route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
  if (moduleIdentifier.length == 0 || route.length == 0) {
    return NO;
  }

  [self openPHPModuleWithIdentifier:moduleIdentifier
                              route:route
                    sourceURLString:urlString
                 requestedURLString:urlString];
  return YES;
}

- (void)importProjectLauncherJSONFromPanel {
  NSURL* importURL = [projectLauncherJSONImporter_ projectLauncherImportURLFromPanel];
  if (!importURL) {
    return;
  }

  BabelBrowserGroup* group = [self targetGroupForModuleIdentifier:@"babelforge.project-launcher"
                                                    fallbackGroup:selectedGroup_];
  [self selectGroup:group];
  BabelBrowserTab* tab = [self createTabForURL:importURL.absoluteString
                                       inGroup:group
                                     parentTab:selectedTab_];
  tab.requestedURLString = @"babelchrome://project-launcher";
  [self saveGroupsState];
  [self showMainWindow];
}
- (BOOL)handleInternalNavigationURLString:(NSString*)urlString {
  return [self handleInternalNavigationURLString:urlString browser:nullptr];
}

- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![stableServerURLResolver_ stableServerURLStringRequestsStart:urlString]) {
    return NO;
  }

  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:urlString];
  if (navigationURLString.length == 0) {
    return NO;
  }

  NSString* requestedURLString =
      [stableServerURLResolver_ stableURLStringByRemovingInternalQueryParameters:urlString];
  NSArray<NSString*>* refreshURLStrings =
      [stableServerURLResolver_ refreshURLStringsForStableURLString:urlString];
  if (refreshURLStrings.count > 0) {
    [runtimeRefreshCoordinator_ enqueueRefreshURLStrings:refreshURLStrings
                                    forBrowserIdentifier:browser->GetIdentifier()];
  }

  tab.requestedURLString = requestedURLString;
  tab.urlString = navigationURLString;
  browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  [self saveGroupsState];
  return YES;
}

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString browser:(CefRefPtr<CefBrowser>)browser {
  if (browser && [self navigateBrowser:browser toInternalURLStringInSameTab:urlString]) {
    return YES;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (![components.scheme isEqualToString:@"babelchrome"]) {
    return NO;
  }

  NSString* commandName = components.host ?: @"";
  if ([commandName isEqualToString:@"settings"]) {
    NSString* moduleSettingsIdentifier = [self moduleSettingsIdentifierFromSettingsComponents:components];
    if (moduleSettingsIdentifier.length > 0) {
      BabelInternalSettingsNavigationResult* result =
          [internalSettingsNavigationHandler_
              applyModuleSettingsComponents:components
                            moduleIdentifier:[self normalizedModuleSettingsIdentifier:moduleSettingsIdentifier]];
      if (result.markdownThemeDidChange) {
        [self reloadMarkdownViewerTabsUsingCurrentTheme];
      }
      [self openModuleSettingsPageForIdentifier:moduleSettingsIdentifier browser:browser];
      return YES;
    }

    BabelInternalSettingsNavigationResult* result =
        [internalSettingsNavigationHandler_ applyApplicationSettingsComponents:components];
    if (result.markdownThemeDidChange) {
      [self reloadMarkdownViewerTabsUsingCurrentTheme];
    }
    if (result.appearanceThemeDidChange) {
      [self applyThemeColors];
      [self layoutTabItemsSelectingLastTab:NO];
      [self layoutGroupItems];
    }
    [self openSettingsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"extensions"]) {
    BabelInternalNavigationAction* action =
        [internalNavigationActionParser_ extensionsActionFromComponents:components];
    if ([action.name isEqualToString:BabelInternalNavigationActionSearch]) {
      [self openChromeWebStoreSearchForQuery:action.value];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionAddUnpacked]) {
      [self addUnpackedExtensionFromPanel];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionRemove]) {
      [self removeUnpackedExtensionAtPath:action.value];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionDisableProfile]) {
      [extensionProfileStore_ setProfileExtensionWithIdentifier:action.value enabled:NO];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionEnableProfile]) {
      [extensionProfileStore_ setProfileExtensionWithIdentifier:action.value enabled:YES];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionRemoveProfile]) {
      [self removeProfileExtensionWithIdentifier:action.value];
      [self openExtensionsPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionRestart]) {
      [self restartApplication];
      return YES;
    }

    [self openExtensionsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"modules"]) {
    BabelInternalNavigationAction* action =
        [internalNavigationActionParser_ modulesActionFromComponents:components];
    BabelInternalModuleNavigationResult* result =
        [internalModuleNavigationHandler_ handleModuleAction:action];
    if (result.fileTypeCapabilitiesDidChange) {
      [self refreshBabelChromeFileTypeCapabilities];
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationUpdates]) {
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationDetails]) {
      NSString* urlString = [NSString stringWithFormat:@"babelchrome://modules?module=%@",
                                                       [self queryEscapedString:result.moduleIdentifier]];
      [self openInternalPageWithURLString:urlString
                                    title:@"Module"
                                     html:[self moduleDetailsPageHTMLForIdentifier:result.moduleIdentifier]
                                  browser:browser];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationOpenModule]) {
      [self openPHPModuleWithIdentifier:result.moduleIdentifier route:result.route];
      return YES;
    }

    if ([result.destination isEqualToString:BabelInternalModuleNavigationDestinationModules]) {
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    [self openModulesPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"project-launcher"]) {
    if ([components.path isEqualToString:@"/import-config"]) {
      [self importProjectLauncherJSONFromPanel];
      return YES;
    }
  }

  if ([commandName isEqualToString:@"history"]) {
    BabelInternalNavigationAction* action =
        [internalNavigationActionParser_ historyActionFromComponents:components];
    if ([action.name isEqualToString:BabelInternalNavigationActionReopen]) {
      NSInteger closedTabIndex = action.value.integerValue;
      if (closedTabIndex >= 0) {
        [self reopenClosedTabAtIndex:(NSUInteger)closedTabIndex];
      }
      return YES;
    }

    [self openHistoryPage];
    return YES;
  }

  if ([commandName isEqualToString:@"open"]) {
    NSURL* commandURL = [NSURL URLWithString:urlString];
    if (commandURL) {
      [self openBabelChromeCommandURL:commandURL];
    } else {
      [self openCompactBabelChromeCommandString:urlString];
    }
    return YES;
  }

  if ([stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    [self navigateSelectedTabToViewerURLString:urlString];
    return YES;
  }

  if ([self openPHPModuleURLString:urlString]) {
    return YES;
  }

  return NO;
}
- (void)navigateSelectedTabToViewerURLString:(NSString*)urlString {
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  if (!selectedTab_) {
    BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
    tab.requestedURLString = requestedURLString;
    [self saveGroupsState];
    return;
  }

  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  } else {
    [self selectTab:selectedTab_];
  }

  [self saveGroupsState];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html {
  [self openInternalPageWithURLString:internalURLString
                                title:title
                                 html:html
                              browser:nullptr];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser {
  if (browser) {
    BabelBrowserTab* targetTab = [self tabForBrowser:browser];
    if (targetTab) {
      NSString* dataURLString = [self dataURLStringForHTML:html];
      targetTab.urlString = dataURLString;
      targetTab.requestedURLString = internalURLString;
      targetTab.title = title;
      targetTab.tabItemView.title = [self compactTitleForString:title];
      browser->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
      [self selectTab:targetTab];
      [self showMainWindow];
      [self saveGroupsState];
      return;
    }
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  BabelBrowserTab* existingTab = [self tabWithURLString:internalURLString inGroup:group];
  NSString* dataURLString = [self dataURLStringForHTML:html];
  if (existingTab) {
    existingTab.urlString = dataURLString;
    existingTab.requestedURLString = internalURLString;
    existingTab.title = title;
    existingTab.tabItemView.title = [self compactTitleForString:title];
    [self selectTab:existingTab];
    if ([existingTab browser]) {
      [existingTab browser]->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
    }
    [self showMainWindow];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [self makeTabForURL:dataURLString identifier:nil title:title];
  tab.requestedURLString = internalURLString;
  [group.tabs addObject:tab];
  [tabContentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (NSString*)dataURLStringForHTML:(NSString*)html {
  return [htmlDataURLBuilder_ dataURLStringForHTML:html];
}
- (NSString*)historyPageHTML {
  NSString* body =
      [historyPageRenderer_ historyPageBodyWithOpenTabRows:[historyPageDataSource_ openTabRowsForGroups:groups_]
                                      recentlyClosedTabRows:[historyPageDataSource_ recentlyClosedTabRows]];
  return [self internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTML {
  NSString* strategy = [self tabOpeningStrategy];
  NSString* addressSuggestionsMode = [self addressSuggestionsMode];
  NSString* appearanceTheme = [BabelTheme.sharedTheme appearanceMode];
  BOOL longQuitShortcutEnabled = [browserSettingsStore_ longQuitShortcutEnabled];
  NSString* body = [appSettingsPageRenderer_ settingsPageBodyWithDefaultURLString:BabelChromeConfiguration.defaultURLString
                                                                  appearanceTheme:appearanceTheme
                                                          longQuitShortcutEnabled:longQuitShortcutEnabled
                                                               tabOpeningStrategy:strategy
                                                           addressSuggestionsMode:addressSuggestionsMode];
  return [self internalPageHTMLWithTitle:@"Settings" body:body];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  NSString* moduleName = [self moduleNameForIdentifier:normalizedIdentifier] ?: normalizedIdentifier;
  NSString* pageTitle = [normalizedIdentifier isEqualToString:@"babelforge.markdown-viewer"]
      ? @"Markdown Viewer Settings"
      : [NSString stringWithFormat:@"%@ Settings", moduleName];
  NSString* body = [moduleSettingsPageRenderer_ moduleSettingsPageBodyForIdentifier:normalizedIdentifier
                                                                         moduleName:moduleName
                                                                      markdownTheme:[self markdownTheme]];
  return [self internalPageHTMLWithTitle:pageTitle body:body];
}

- (NSString*)extensionsPageHTML {
  NSString* body =
      [extensionsPageRenderer_
          extensionsPageBodyWithProfileExtensionRows:[extensionsPageDataSource_ profileExtensionRows]
                               unpackedExtensionRows:[extensionsPageDataSource_ unpackedExtensionRows]];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}
- (NSString*)moduleSettingsIdentifierFromSettingsComponents:(NSURLComponents*)components {
  NSString* path = components.path ?: @"";
  if ([path hasPrefix:@"/"]) {
    path = [path substringFromIndex:1];
  }
  if (path.length > 0) {
    return path;
  }

  NSString* fragment = components.fragment ?: @"";
  if (fragment.length > 0) {
    return fragment;
  }

  return @"";
}

- (NSString*)normalizedModuleSettingsIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier =
      [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
  if (normalizedIdentifier.length == 0) {
    return @"";
  }

  if ([normalizedIdentifier containsString:@"."]) {
    return normalizedIdentifier;
  }

  return [@"babelforge." stringByAppendingString:normalizedIdentifier];
}

- (NSString*)moduleNameForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (error) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (![currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      continue;
    }

    return [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : currentIdentifier;
  }

  return nil;
}
- (void)removeProfileExtensionWithIdentifier:(NSString*)extensionIdentifier {
  [extensionProfileStore_ removeProfileExtensionWithIdentifier:extensionIdentifier];
}

- (void)addUnpackedExtensionFromPanel {
  [extensionFolderController_ addUnpackedExtensionFromPanel];
}

- (void)removeUnpackedExtensionAtPath:(NSString*)extensionPath {
  NSMutableArray<NSString*>* extensionPaths =
      [[extensionProfileStore_ installedExtensionPaths] mutableCopy];
  [extensionPaths removeObject:extensionPath];
  [extensionProfileStore_ saveInstalledExtensionPaths:extensionPaths];
}

- (void)openChromeWebStoreSearchForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedQuery.length == 0) {
    return;
  }

  NSString* urlString = [NSString stringWithFormat:@"https://chromewebstore.google.com/search/%@",
                                                   [self pathEscapedString:trimmedQuery]];
  [self openURLStringInNewTab:urlString];
}

- (void)showLocalServiceStartupAlert:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Start Local Viewer";
  alert.informativeText = error.localizedDescription ?: @"BabelChrome could not start the local file viewer service.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}
- (NSString*)queryEscapedString:(NSString*)value {
  return [browserStringFormatter_ queryEscapedString:value];
}

- (NSString*)pathEscapedString:(NSString*)value {
  return [browserStringFormatter_ pathEscapedString:value];
}

- (NSString*)trashIconHTML {
  return [internalPageAssetProvider_ trashIconHTML];
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  return [internalPageAssetProvider_ resourceSVGIconHTMLNamed:resourceName fallback:fallbackHTML];
}

- (void)restartApplication {
  NSString* bundlePath = NSBundle.mainBundle.bundlePath;
  [applicationRelauncher_ scheduleRelaunchForBundlePath:bundlePath
                                      processIdentifier:NSProcessInfo.processInfo.processIdentifier];
  [self requestApplicationTermination];
}

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  return [internalPageRenderer_ internalPageHTMLWithTitle:title body:body];
}
