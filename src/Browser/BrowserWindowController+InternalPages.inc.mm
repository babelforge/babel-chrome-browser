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
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ modulesPageBodyWithModules:modules
                                                             error:error
                                                   updateURLString:[moduleUpdateService_ updateURLString]
                                              updateLocalDirectory:[moduleUpdateService_ localDirectoryPath]];
  return [self internalPageHTMLWithTitle:@"Modules" body:body];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ moduleDetailsPageBodyForIdentifier:moduleIdentifier
                                                                    modules:modules
                                                                      error:error];
  NSString* pageTitle = moduleIdentifier.length > 0 ? moduleIdentifier : @"Module";
  return [self internalPageHTMLWithTitle:pageTitle body:body];
}

- (NSString*)moduleUpdatesPageHTML {
  NSDictionary* updateResult = [moduleUpdateService_ releaseManifestResult];
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  NSDictionary* releaseModulesByIdentifier =
      [moduleUpdateService_ releaseModulesByIdentifier:releaseModules];

  NSError* snapshotError = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&snapshotError];
  NSArray* installedModules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];

  NSString* body = [modulePageRenderer_ moduleUpdatesPageBodyWithUpdateResult:updateResult
                                                   releaseModulesByIdentifier:releaseModulesByIdentifier
                                                             installedModules:installedModules
                                                                snapshotError:snapshotError
                                                              updateURLString:[moduleUpdateService_ updateURLString]
                                                               localDirectory:[moduleUpdateService_ localDirectoryPath]];
  return [self internalPageHTMLWithTitle:@"Module Updates" body:body];
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
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Load Project Launcher JSON";
  if ([panel runModal] != NSModalResponseOK) {
    [self appendLocalDropLogLine:@"Project Launcher JSON panel cancelled."];
    return;
  }

  NSString* path = panel.URL.path ?: @"";
  if (![path.pathExtension.lowercaseString isEqualToString:@"json"]) {
    [self appendLocalDropLogLine:[NSString stringWithFormat:@"Project Launcher JSON panel rejected path=%@", path]];
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Invalid Project Configuration";
    alert.informativeText = @"Please select a JSON project configuration file.";
    [alert runModal];
    return;
  }

  [self appendLocalDropLogLine:[NSString stringWithFormat:@"Project Launcher JSON panel selected path=%@", path]];
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:@"babelforge.project-launcher"
                                                                       route:@"index"
                                                             sourceURLString:nil
                                                                       error:nil];
  if (!moduleURL || path.length == 0) {
    [self appendLocalDropLogLine:@"Project Launcher JSON panel could not build module URL."];
    return;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:moduleURL resolvingAgainstBaseURL:NO];
  NSMutableArray<NSURLQueryItem*>* queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"action" value:@"importPath"]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"path" value:path]];
  components.queryItems = queryItems;

  BabelBrowserGroup* group = [self targetGroupForModuleIdentifier:@"babelforge.project-launcher"
                                                    fallbackGroup:selectedGroup_];
  [self selectGroup:group];
  BabelBrowserTab* tab = [self createTabForURL:components.URL.absoluteString
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
    if ([action.name isEqualToString:BabelInternalNavigationActionInstallSelectedUpdates]) {
      if ([moduleUIActionCoordinator_ installPHPModuleUpdatesWithIdentifiers:action.values]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionInstallZip]) {
      if ([moduleUIActionCoordinator_ installPHPModuleZipFromPanel]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionConfigureUpdateURL]) {
      [moduleUIActionCoordinator_ configureModuleUpdateURLFromPrompt];
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionConfigureUpdateLocal]) {
      [moduleUIActionCoordinator_ configureModuleUpdateLocalDirectoryFromPanel];
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionCheckUpdates]) {
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionInstallUpdate]) {
      if ([moduleUIActionCoordinator_ installPHPModuleUpdateWithIdentifier:action.value]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionEnable]) {
      if ([moduleUIActionCoordinator_ setPHPModuleWithIdentifier:action.value enabled:YES]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionDisable]) {
      if ([moduleUIActionCoordinator_ setPHPModuleWithIdentifier:action.value enabled:NO]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionRemove]) {
      if ([moduleUIActionCoordinator_ removePHPModuleWithIdentifier:action.value]) {
        [self refreshBabelChromeFileTypeCapabilities];
      }
      [self openModulesPageForBrowser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionModuleDetails]) {
      NSString* urlString = [NSString stringWithFormat:@"babelchrome://modules?module=%@",
                                                       [self queryEscapedString:action.value]];
      [self openInternalPageWithURLString:urlString
                                    title:@"Module"
                                     html:[self moduleDetailsPageHTMLForIdentifier:action.value]
                                  browser:browser];
      return YES;
    }

    if ([action.name isEqualToString:BabelInternalNavigationActionOpen]) {
      [self openPHPModuleWithIdentifier:action.value route:action.secondaryValue];
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
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (NSString*)dataURLStringForHTML:(NSString*)html {
  NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
  NSString* encodedHTML = [data base64EncodedStringWithOptions:0];
  return [NSString stringWithFormat:@"data:text/html;charset=utf-8;base64,%@", encodedHTML];
}
- (NSString*)historyPageHTML {
  NSMutableArray<NSDictionary*>* openTabRows = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [openTabRows addObject:@{
        BabelHistoryRowTitleKey : title ?: @"",
        BabelHistoryRowURLStringKey : tab.requestedURLString ?: tab.urlString ?: @"",
        BabelHistoryRowGroupNameKey : group.name ?: kDefaultGroupName,
      }];
    }
  }

  NSMutableArray<NSDictionary*>* recentlyClosedTabRows = [NSMutableArray array];
  NSArray<BabelClosedTab*>* closedTabs = [recentlyClosedTabStore_ allClosedTabs];
  for (NSInteger index = (NSInteger)closedTabs.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs[(NSUInteger)index];
    NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
    [recentlyClosedTabRows addObject:@{
      BabelHistoryRowTitleKey : title ?: @"",
      BabelHistoryRowURLStringKey : closedTab.requestedURLString ?: closedTab.urlString ?: @"",
      BabelHistoryRowGroupNameKey : closedTab.groupName ?: kDefaultGroupName,
      BabelHistoryRowReopenIndexKey : @((NSUInteger)index),
    }];
  }

  NSString* body = [historyPageRenderer_ historyPageBodyWithOpenTabRows:openTabRows
                                                   recentlyClosedTabRows:recentlyClosedTabRows];
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
  NSArray<NSString*>* extensionPaths = [extensionProfileStore_ installedExtensionPaths];
  NSArray<NSDictionary*>* profileExtensions = [extensionProfileStore_ profileInstalledExtensions];
  NSMutableArray<NSDictionary*>* profileExtensionRows = [NSMutableArray array];
  for (NSDictionary* extension in profileExtensions ?: @[]) {
    NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
        ? extension[@"id"]
        : @"";
    BOOL enabled = [extension[@"enabled"] boolValue];
    NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
    NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
    NSString* status = [extensionProfileStore_ profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                                enabled:enabled];
    [profileExtensionRows addObject:@{
      BabelExtensionProfileNameKey : [extension[@"name"] isKindOfClass:NSString.class] ? extension[@"name"] : @"",
      BabelExtensionProfileIdentifierKey : extensionIdentifier ?: @"",
      BabelExtensionProfileVersionKey : [extension[@"version"] isKindOfClass:NSString.class] ? extension[@"version"] : @"",
      BabelExtensionProfilePathKey : [extension[@"path"] isKindOfClass:NSString.class] ? extension[@"path"] : @"",
      BabelExtensionProfileStatusKey : status ?: @"",
      BabelExtensionProfileToggleActionKey : toggleAction,
      BabelExtensionProfileToggleLabelKey : toggleLabel,
      BabelExtensionProfileRequiresRestartKey : @([extensionProfileStore_ profileExtensionRequiresRestart:extensionIdentifier]),
    }];
  }

  NSMutableArray<NSDictionary*>* unpackedExtensionRows = [NSMutableArray array];
  for (NSString* extensionPath in extensionPaths ?: @[]) {
    NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
    BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
    NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
    [unpackedExtensionRows addObject:@{
      BabelUnpackedExtensionNameKey : extensionPath.lastPathComponent ?: @"",
      BabelUnpackedExtensionPathKey : extensionPath ?: @"",
      BabelUnpackedExtensionStatusKey : [NSString stringWithFormat:@"%@ - %@", status, extensionPath ?: @""],
    }];
  }

  NSString* body = [extensionsPageRenderer_ extensionsPageBodyWithProfileExtensionRows:profileExtensionRows
                                                                 unpackedExtensionRows:unpackedExtensionRows];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}
- (NSString*)settingsTabOpeningStrategyHTML:(NSString*)selectedStrategy {
  return [settingsOptionRenderer_ tabOpeningStrategyHTMLWithSelectedStrategy:selectedStrategy];
}

- (NSString*)settingsAddressSuggestionsHTML:(NSString*)selectedMode {
  return [settingsOptionRenderer_ addressSuggestionsHTMLWithSelectedMode:selectedMode];
}

- (NSString*)settingsAppearanceThemeHTML:(NSString*)selectedTheme {
  return [settingsOptionRenderer_ appearanceThemeHTMLWithSelectedTheme:selectedTheme];
}

- (NSString*)settingsLongQuitShortcutHTML:(BOOL)enabled {
  return [settingsOptionRenderer_ longQuitShortcutHTMLWithEnabledState:enabled];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme {
  return [self settingsMarkdownThemeHTML:selectedTheme settingsURLString:@"babelchrome://settings"];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme settingsURLString:(NSString*)settingsURLString {
  return [settingsOptionRenderer_ markdownThemeHTMLWithSelectedTheme:selectedTheme
                                                   settingsURLString:settingsURLString];
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
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.prompt = @"Add";
  panel.message = @"Choose an unpacked Chrome extension folder containing manifest.json.";

  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* extensionPath = panel.URL.path;
  NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
  if (![NSFileManager.defaultManager fileExistsAtPath:manifestPath]) {
    [self showExtensionFolderMissingManifestAlert:extensionPath];
    return;
  }

  NSMutableArray<NSString*>* extensionPaths =
      [[extensionProfileStore_ installedExtensionPaths] mutableCopy];
  if (![extensionPaths containsObject:extensionPath]) {
    [extensionPaths addObject:extensionPath];
  }
  [extensionProfileStore_ saveInstalledExtensionPaths:extensionPaths];
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

- (void)showExtensionFolderMissingManifestAlert:(NSString*)extensionPath {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Invalid Extension Folder";
  alert.informativeText = [NSString stringWithFormat:@"The selected folder does not contain manifest.json:\n%@",
                                                     extensionPath ?: @""];
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
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

- (NSString*)shellQuotedString:(NSString*)value {
  return [browserStringFormatter_ shellQuotedString:value];
}

- (NSString*)trashIconHTML {
  return [internalPageAssetProvider_ trashIconHTML];
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  return [internalPageAssetProvider_ resourceSVGIconHTMLNamed:resourceName fallback:fallbackHTML];
}

- (BOOL)isInternalModuleCapability:(NSString*)capability {
  static NSSet<NSString*>* internalCapabilities = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    internalCapabilities = [NSSet setWithArray:@[
      @"app.did-start",
      @"app.will-quit",
      @"drop.local-paths",
      @"settings.section.register"
    ]];
  });

  return [internalCapabilities containsObject:capability ?: @""];
}

- (void)restartApplication {
  NSString* bundlePath = NSBundle.mainBundle.bundlePath;
  if (bundlePath.length == 0) {
    [self requestApplicationTermination];
    return;
  }

  int processIdentifier = NSProcessInfo.processInfo.processIdentifier;
  NSString* script = [NSString stringWithFormat:
      @"while /bin/kill -0 %d 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open %@",
      processIdentifier,
      [self shellQuotedString:bundlePath]];

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/nohup"];
  task.arguments = @[@"/bin/sh", @"-c", script];
  NSFileHandle* nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  if (nullHandle) {
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;
  }
  [task launchAndReturnError:nil];
  [self requestApplicationTermination];
}

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  return [internalPageRenderer_ internalPageHTMLWithTitle:title body:body];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  return [internalPageRenderer_ htmlEscapedString:value];
}
