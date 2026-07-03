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
    [self showModuleActionAlertWithError:error];
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
  NSDictionary* moduleRoute = [self moduleRouteForBabelChromeComponents:components error:&error];
  if (!moduleRoute) {
    if (error) {
      [self showModuleActionAlertWithError:error];
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
      BOOL markdownThemeDidChange = NO;
      for (NSURLQueryItem* item in components.queryItems) {
        if ([item.name isEqualToString:@"markdownTheme"] &&
            [self isSupportedMarkdownTheme:item.value] &&
            [[self normalizedModuleSettingsIdentifier:moduleSettingsIdentifier]
                isEqualToString:@"babelforge.markdown-viewer"]) {
          NSString* previousTheme = [self markdownTheme];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:kMarkdownThemeDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }
      }

      if (markdownThemeDidChange) {
        [self reloadMarkdownViewerTabsUsingCurrentTheme];
      }
      [self openModuleSettingsPageForIdentifier:moduleSettingsIdentifier browser:browser];
      return YES;
    }

    BOOL markdownThemeDidChange = NO;
    BOOL appearanceThemeDidChange = NO;
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"tabOpeningStrategy"] &&
          [self isSupportedTabOpeningStrategy:item.value]) {
        [NSUserDefaults.standardUserDefaults setObject:item.value
                                                forKey:kTabOpeningStrategyDefaultsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        break;
      }

      if ([item.name isEqualToString:@"longQuitShortcut"]) {
        BOOL enabled = [item.value isEqualToString:@"1"] ||
                       [[item.value lowercaseString] isEqualToString:@"true"];
        [NSUserDefaults.standardUserDefaults setBool:enabled
                                              forKey:kLongQuitShortcutEnabledDefaultsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        break;
      }

      if (![item.name isEqualToString:@"addressSuggestions"] ||
          ![self isSupportedAddressSuggestionsMode:item.value]) {
        if ([item.name isEqualToString:@"markdownTheme"] &&
            [self isSupportedMarkdownTheme:item.value]) {
          NSString* previousTheme = [self markdownTheme];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:kMarkdownThemeDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }

        if ([item.name isEqualToString:@"appearanceTheme"] &&
            [BabelTheme.sharedTheme isSupportedAppearanceMode:item.value]) {
          NSString* previousTheme = [BabelTheme.sharedTheme appearanceMode];
          [NSUserDefaults.standardUserDefaults setObject:item.value
                                                  forKey:BabelThemeAppearanceDefaultsKey];
          [NSUserDefaults.standardUserDefaults synchronize];
          appearanceThemeDidChange = ![previousTheme isEqualToString:item.value];
          break;
        }
        continue;
      }

      [NSUserDefaults.standardUserDefaults setObject:item.value
                                              forKey:kAddressSuggestionsModeDefaultsKey];
      [NSUserDefaults.standardUserDefaults synchronize];
      break;
    }

    if (markdownThemeDidChange) {
      [self reloadMarkdownViewerTabsUsingCurrentTheme];
    }
    if (appearanceThemeDidChange) {
      [self applyThemeColors];
      [self layoutTabItemsSelectingLastTab:NO];
      [self layoutGroupItems];
    }
    [self openSettingsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"extensions"]) {
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"search"] && item.value.length > 0) {
        [self openChromeWebStoreSearchForQuery:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"addUnpacked"] && item.value.length > 0) {
        [self addUnpackedExtensionFromPanel];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"remove"] && item.value.length > 0) {
        [self removeUnpackedExtensionAtPath:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"disableProfile"] && item.value.length > 0) {
        [self setProfileExtensionWithIdentifier:item.value enabled:NO];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"enableProfile"] && item.value.length > 0) {
        [self setProfileExtensionWithIdentifier:item.value enabled:YES];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"removeProfile"] && item.value.length > 0) {
        [self removeProfileExtensionWithIdentifier:item.value];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"restart"] && item.value.length > 0) {
        [self restartApplication];
        return YES;
      }
    }

    [self openExtensionsPageForBrowser:browser];
    return YES;
  }

  if ([commandName isEqualToString:@"modules"]) {
    BOOL didRequestUpdateInstall = NO;
    NSMutableArray<NSString*>* updateIdentifiers = [NSMutableArray array];
    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"installSelectedUpdates"] && item.value.length > 0) {
        didRequestUpdateInstall = YES;
      }
      if ([item.name isEqualToString:@"installUpdates"] && item.value.length > 0) {
        didRequestUpdateInstall = YES;
        [updateIdentifiers addObject:item.value];
      }
    }
    if (didRequestUpdateInstall) {
      [self installPHPModuleUpdatesWithIdentifiers:updateIdentifiers];
      [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                    title:@"Module Updates"
                                     html:[self moduleUpdatesPageHTML]
                                  browser:browser];
      return YES;
    }

    for (NSURLQueryItem* item in components.queryItems) {
      if ([item.name isEqualToString:@"installZip"] && item.value.length > 0) {
        [self installPHPModuleZipFromPanel];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"configureUpdateURL"] && item.value.length > 0) {
        [self configureModuleUpdateURLFromPrompt];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"configureUpdateLocal"] && item.value.length > 0) {
        [self configureModuleUpdateLocalDirectoryFromPanel];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"checkUpdates"] && item.value.length > 0) {
        [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                      title:@"Module Updates"
                                       html:[self moduleUpdatesPageHTML]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"installUpdate"] && item.value.length > 0) {
        [self installPHPModuleUpdateWithIdentifier:item.value];
        [self openInternalPageWithURLString:@"babelchrome://modules?checkUpdates=1"
                                      title:@"Module Updates"
                                       html:[self moduleUpdatesPageHTML]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"enable"] && item.value.length > 0) {
        [self setPHPModuleWithIdentifier:item.value enabled:YES];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"disable"] && item.value.length > 0) {
        [self setPHPModuleWithIdentifier:item.value enabled:NO];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"remove"] && item.value.length > 0) {
        [self removePHPModuleWithIdentifier:item.value];
        [self openModulesPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"module"] && item.value.length > 0) {
        NSString* urlString = [NSString stringWithFormat:@"babelchrome://modules?module=%@",
                                                         [self queryEscapedString:item.value]];
        [self openInternalPageWithURLString:urlString
                                      title:@"Module"
                                       html:[self moduleDetailsPageHTMLForIdentifier:item.value]
                                    browser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"open"] && item.value.length > 0) {
        NSString* route = @"index";
        for (NSURLQueryItem* routeItem in components.queryItems) {
          if ([routeItem.name isEqualToString:@"route"] && routeItem.value.length > 0) {
            route = routeItem.value;
            break;
          }
        }
        [self openPHPModuleWithIdentifier:item.value route:route];
        return YES;
      }
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
    for (NSURLQueryItem* item in components.queryItems) {
      if (![item.name isEqualToString:@"reopen"] || item.value.length == 0) {
        continue;
      }

      NSInteger closedTabIndex = item.value.integerValue;
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

  if ([self isStableViewerURLString:urlString]) {
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
  NSMutableString* body = [NSMutableString string];
  [body appendString:@"<h1>History</h1>"];
  [body appendString:@"<h2>Open Tabs</h2><ul>"];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [body appendFormat:@"<li><span>%@</span><small>%@</small><em>%@</em></li>",
                         [self htmlEscapedString:title],
                         [self htmlEscapedString:tab.requestedURLString ?: tab.urlString],
                         [self htmlEscapedString:group.name ?: kDefaultGroupName]];
    }
  }
  [body appendString:@"</ul>"];

  [body appendString:@"<h2>Recently Closed Tabs</h2>"];
  if (closedTabs_.count == 0) {
    [body appendString:@"<p class='empty'>No recently closed tab.</p>"];
  } else {
    [body appendString:@"<ul>"];
    for (NSInteger index = (NSInteger)closedTabs_.count - 1; index >= 0; index--) {
      BabelClosedTab* closedTab = closedTabs_[(NSUInteger)index];
      NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
      [body appendFormat:
          @"<li><span>%@</span><small>%@</small><em>%@</em>"
           "<div class='actions'><a class='smallButton' href='babelchrome://history?reopen=%ld'>Re-open</a></div></li>",
          [self htmlEscapedString:title],
          [self htmlEscapedString:closedTab.requestedURLString ?: closedTab.urlString],
          [self htmlEscapedString:closedTab.groupName ?: kDefaultGroupName],
          (long)index];
    }
    [body appendString:@"</ul>"];
  }
  return [self internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTML {
  NSString* strategy = [self tabOpeningStrategy];
  NSString* addressSuggestionsMode = [self addressSuggestionsMode];
  NSString* appearanceTheme = [BabelTheme.sharedTheme appearanceMode];
  BOOL longQuitShortcutEnabled =
      [NSUserDefaults.standardUserDefaults boolForKey:kLongQuitShortcutEnabledDefaultsKey];
  NSString* body = [NSString stringWithFormat:
      @"<h1>Settings</h1>"
       "<section><a class='primaryButton' data-can-open-menu='true' href='babelchrome://extensions'>Extensions</a>"
       " <a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules'>PHP Modules</a></section>"
       "<section>"
       "<h2>General</h2>"
       "<dl>"
       "<dt>Default page</dt><dd>%@</dd>"
       "<dt>Application theme</dt><dd>%@</dd>"
       "<dt>Quit shortcut</dt><dd>%@</dd>"
       "<dt>Tab opening strategy</dt><dd>%@</dd>"
       "<dt>Address suggestions</dt><dd>%@</dd>"
       "<dt>Groups file</dt><dd>Stored in the BabelChrome application support folder.</dd>"
       "<dt>Developer Tools docking</dt><dd>The last selected dock mode is saved automatically.</dd>"
       "</dl>"
       "</section>",
      [self htmlEscapedString:BabelChromeConfiguration.defaultURLString],
      [self settingsAppearanceThemeHTML:appearanceTheme],
      [self settingsLongQuitShortcutHTML:longQuitShortcutEnabled],
      [self settingsTabOpeningStrategyHTML:strategy],
      [self settingsAddressSuggestionsHTML:addressSuggestionsMode]];
  return [self internalPageHTMLWithTitle:@"Settings" body:body];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  if ([normalizedIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    NSString* body = [NSString stringWithFormat:
        @"<h1>Markdown Viewer Settings</h1>"
         "<section>"
         "<p class='note'>These settings belong to the Markdown Viewer module, not to BabelChrome itself.</p>"
         "<dl>"
         "<dt>Markdown theme</dt><dd>%@</dd>"
         "</dl>"
         "</section>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self settingsMarkdownThemeHTML:[self markdownTheme] settingsURLString:@"babelchrome://settings/babelforge.markdown-viewer"]];
    return [self internalPageHTMLWithTitle:@"Markdown Viewer Settings" body:body];
  }

  NSString* moduleName = [self moduleNameForIdentifier:normalizedIdentifier] ?: normalizedIdentifier;
  NSString* body = [NSString stringWithFormat:
      @"<h1>%@ Settings</h1>"
       "<section>"
       "<p class='empty'>This module does not expose native BabelChrome settings yet.</p>"
       "</section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName]];
  return [self internalPageHTMLWithTitle:[NSString stringWithFormat:@"%@ Settings", moduleName] body:body];
}

- (NSString*)extensionsPageHTML {
  NSArray<NSString*>* extensionPaths = [self installedExtensionPaths];
  NSArray<NSDictionary*>* profileExtensions = [self profileInstalledExtensions];
  NSMutableString* profileListHTML = [NSMutableString string];
  if (profileExtensions.count == 0) {
    [profileListHTML appendString:@"<p class='empty'>No Chrome profile extension was found.</p>"];
  } else {
    [profileListHTML appendString:@"<ul>"];
    for (NSDictionary* extension in profileExtensions) {
      NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
          ? extension[@"id"]
          : @"";
      BOOL enabled = [extension[@"enabled"] boolValue];
      NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
      NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
      NSString* status = [self profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                 enabled:enabled];
      NSString* restartHTML = [self profileExtensionRequiresRestart:extensionIdentifier]
          ? @"<a class='smallButton primarySmallButton' href='babelchrome://extensions?restart=1'>Restart</a>"
          : @"";
      [profileListHTML appendFormat:
          @"<li><span>%@</span><small>%@ - ID: %@ - Version: %@ - %@</small>"
           "<div class='actions'>%@<a class='smallButton' href='babelchrome://extensions?%@=%@'>%@</a>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?removeProfile=%@' title='Remove'>%@<span>Remove</span></a></div></li>",
          [self htmlEscapedString:extension[@"name"]],
          [self htmlEscapedString:status],
          [self htmlEscapedString:extensionIdentifier],
          [self htmlEscapedString:extension[@"version"]],
          [self htmlEscapedString:extension[@"path"]],
          restartHTML,
          toggleAction,
          [self queryEscapedString:extensionIdentifier],
          toggleLabel,
          [self queryEscapedString:extensionIdentifier],
          [self trashIconHTML]];
    }
    [profileListHTML appendString:@"</ul>"];
  }

  NSMutableString* unpackedListHTML = [NSMutableString string];
  if (extensionPaths.count == 0) {
    [unpackedListHTML appendString:@"<p class='empty'>No unpacked extension is configured.</p>"];
  } else {
    [unpackedListHTML appendString:@"<ul>"];
    for (NSString* extensionPath in extensionPaths) {
      NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
      BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
      NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
      [unpackedListHTML appendFormat:
          @"<li><span>%@</span><small>%@</small><div class='actions'>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?remove=%@' title='Remove'>%@<span>Remove</span></a>"
           "</div></li>",
          [self htmlEscapedString:extensionPath.lastPathComponent],
          [self htmlEscapedString:[NSString stringWithFormat:@"%@ - %@", status, extensionPath]],
          [self queryEscapedString:extensionPath],
          [self trashIconHTML]];
    }
    [unpackedListHTML appendString:@"</ul>"];
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>Extensions</h1>"
       "<section>"
       "<h2>Chrome Web Store</h2>"
       "<form method='get' action='babelchrome://extensions' class='searchForm'>"
       "<input type='search' name='search' placeholder='Search extensions' autofocus>"
       "<button type='submit'>Search</button>"
       "</form>"
       "</section>"
       "<section>"
       "<h2>Chrome Profile Extensions</h2>"
       "<p class='note'>Extensions installed by Chromium in the BabelChrome profile are listed here. Disable and Enable changes are applied on the next BabelChrome restart.</p>"
       "%@"
       "</section>"
       "<section>"
       "<h2>Unpacked Extensions</h2>"
       "<p class='note'>BabelChrome loads configured unpacked extension folders at startup. Changes require restarting BabelChrome.</p>"
       "<p><a class='primaryButton' href='babelchrome://extensions?addUnpacked=1'>Add unpacked extension folder</a></p>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      profileListHTML,
      unpackedListHTML];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}

- (NSString*)modulesPageHTML {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* updateURLString = [self moduleUpdateURLString];
  NSString* updateLocalDirectory = [self moduleUpdateLocalDirectoryPath];
  NSString* updateURLLabel = updateURLString.length > 0 ? updateURLString : @"Not configured";
  NSString* updateLocalLabel = updateLocalDirectory.length > 0 ? updateLocalDirectory : @"Not configured";
  NSMutableString* moduleListHTML = [NSMutableString string];
  if (error) {
    [moduleListHTML appendFormat:@"<p class='empty'>%@</p>",
                                 [self htmlEscapedString:error.localizedDescription]];
  } else if (modules.count == 0) {
    [moduleListHTML appendString:@"<p class='empty'>No PHP module is registered.</p>"];
  } else {
    [moduleListHTML appendString:@"<ul class='stripedList moduleList'>"];
    for (NSDictionary* module in modules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* moduleVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSString* moduleDescription =
          [module[@"description"] isKindOfClass:NSString.class] ? module[@"description"] : @"";
      BOOL enabled = [module[@"enabled"] boolValue];
      BOOL hasIsolatedVendor = [module[@"hasIsolatedVendor"] boolValue];
      NSString* settingsRoute =
          [module[@"settingsRoute"] isKindOfClass:NSString.class] ? module[@"settingsRoute"] : @"";
      BOOL hasSettingsPage = settingsRoute.length > 0 && ![settingsRoute isEqualToString:@"babelchrome://modules"];
      NSString* enabledLabel = enabled ? @"Enabled" : @"Disabled";
      NSString* vendorLabel = hasIsolatedVendor ? @"Bundled vendor" : @"No bundled vendor";
      NSString* versionLabel = [NSString stringWithFormat:@"Installed %@", moduleVersion];
      NSString* detailsActionHTML = @"";
      NSString* settingsActionHTML = @"";
      NSString* toggleActionHTML = @"";
      NSString* removeActionHTML = @"";
      if (moduleIdentifier.length > 0) {
        detailsActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' data-can-open-menu='true' href='babelchrome://modules?module=%@'>Details</a>",
            [self queryEscapedString:moduleIdentifier]];
      }
      if (hasSettingsPage) {
        settingsActionHTML = [NSString stringWithFormat:@"<a class='smallButton' data-can-open-menu='true' href='%@'>Settings</a>",
                                                        [self htmlEscapedString:settingsRoute]];
      }
      if (moduleIdentifier.length > 0) {
        NSString* toggleAction = enabled ? @"disable" : @"enable";
        NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
        toggleActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton' href='babelchrome://modules?%@=%@'>%@</a>",
            toggleAction,
            [self queryEscapedString:moduleIdentifier],
            toggleLabel];
        removeActionHTML = [NSString stringWithFormat:
            @"<a class='smallButton dangerButton iconTextButton' href='babelchrome://modules?remove=%@' title='Remove'>%@<span>Remove</span></a>",
            [self queryEscapedString:moduleIdentifier],
            [self trashIconHTML]];
      }

      [moduleListHTML appendFormat:
          @"<li class='moduleItem'>"
           "<div class='moduleText'><span>%@</span><small>%@ - %@ - %@ - %@</small><em>%@</em>"
           "<p class='note'>%@</p></div>"
           "<div class='moduleButtons'>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "<div class='moduleButtonCell'>%@</div><div class='moduleButtonCell'>%@</div>"
           "</div>"
           "</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:versionLabel],
          @"User-installed",
          [self htmlEscapedString:enabledLabel],
          [self htmlEscapedString:vendorLabel],
          [self htmlEscapedString:moduleDescription],
          detailsActionHTML,
          settingsActionHTML,
          toggleActionHTML,
          removeActionHTML];
    }
    [moduleListHTML appendString:@"</ul>"];
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>PHP Modules</h1>"
       "<section>"
       "<h2>Installed Modules</h2>"
       "<div class='buttonRow'>"
       "<a class='primaryButton' href='babelchrome://modules?installZip=1'>Install or Update Module Zip</a>"
       "<a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules?checkUpdates=1'>Check Updates</a>"
       "<details class='gearMenu'>"
       "<summary title='Update source settings' aria-label='Update source settings'>%@</summary>"
       "<div class='gearMenuPanel'>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateURL=1'>Set Update URL</a>"
       "<a class='smallButton' href='babelchrome://modules?configureUpdateLocal=1'>Set Local Update Folder</a>"
       "</div>"
       "</details>"
       "</div>"
       "<dl>"
       "<dt>Update URL</dt><dd>%@</dd>"
       "<dt>Local update folder</dt><dd>%@</dd>"
       "</dl>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      [self resourceSVGIconHTMLNamed:@"settings-gear" fallback:@"&#9881;"],
      [self htmlEscapedString:updateURLLabel],
      [self htmlEscapedString:updateLocalLabel],
      moduleListHTML];
  return [self internalPageHTMLWithTitle:@"Modules" body:body];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSDictionary* selectedModule = nil;
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if ([currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      selectedModule = module;
      break;
    }
  }

  if (error) {
    NSString* body = [NSString stringWithFormat:@"<h1>Module</h1><p class='empty'>%@</p>",
                                                [self htmlEscapedString:error.localizedDescription]];
    return [self internalPageHTMLWithTitle:@"Module" body:body];
  }

  if (!selectedModule) {
    NSString* body = [NSString stringWithFormat:
        @"<h1>Module</h1><p class='empty'>Module <code>%@</code> is not installed.</p>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self htmlEscapedString:moduleIdentifier ?: @""]];
    return [self internalPageHTMLWithTitle:@"Module" body:body];
  }

  NSString* moduleName = [selectedModule[@"name"] isKindOfClass:NSString.class] ? selectedModule[@"name"] : moduleIdentifier;
  NSString* moduleVersion = [selectedModule[@"version"] isKindOfClass:NSString.class] ? selectedModule[@"version"] : @"";
  NSString* moduleType = [selectedModule[@"type"] isKindOfClass:NSString.class] ? selectedModule[@"type"] : @"";
  NSString* moduleDescription =
      [selectedModule[@"description"] isKindOfClass:NSString.class] ? selectedModule[@"description"] : @"";
  BOOL enabled = [selectedModule[@"enabled"] boolValue];
  BOOL hasIsolatedVendor = [selectedModule[@"hasIsolatedVendor"] boolValue];
  NSDictionary* requirements =
      [selectedModule[@"requirements"] isKindOfClass:NSDictionary.class] ? selectedModule[@"requirements"] : @{};
  NSString* phpRequirement =
      [requirements[@"php"] isKindOfClass:NSString.class] ? requirements[@"php"] : @"";
  NSArray* routes = [selectedModule[@"routes"] isKindOfClass:NSArray.class] ? selectedModule[@"routes"] : @[];
  NSArray* fileTypes = [selectedModule[@"fileTypes"] isKindOfClass:NSArray.class] ? selectedModule[@"fileTypes"] : @[];
  NSArray* hooks = [selectedModule[@"hooks"] isKindOfClass:NSArray.class] ? selectedModule[@"hooks"] : @[];

  NSMutableString* routesHTML = [NSMutableString string];
  for (NSDictionary* route in routes) {
    if (![route isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
    NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
    NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
    if (routeScheme.length == 0 || routeHost.length == 0 || routeHandler.length == 0) {
      continue;
    }

    BOOL routeCanOpenDirectly = [routeScheme isEqualToString:@"babelchrome"] &&
        ![routeHost isEqualToString:@"server"];
    NSString* actionHTML = enabled && routeCanOpenDirectly
        ? [NSString stringWithFormat:@"<a class='smallButton' href='babelchrome://modules?open=%@&route=%@'>Open route</a>",
                                     [self queryEscapedString:moduleIdentifier ?: @""],
                                     [self queryEscapedString:routeHandler]]
        : @"";
    [routesHTML appendFormat:
        @"<li><code>%@://%@</code><span>&rarr;</span><code>%@</code>%@</li>",
        [self htmlEscapedString:routeScheme],
        [self htmlEscapedString:routeHost],
        [self htmlEscapedString:routeHandler],
        actionHTML];
  }

  NSMutableString* tagsHTML = [NSMutableString string];
  for (NSString* fileType in fileTypes) {
    if ([fileType isKindOfClass:NSString.class] && fileType.length > 0) {
      [tagsHTML appendFormat:@"<code>.%@</code>", [self htmlEscapedString:fileType]];
    }
  }
  for (NSString* hook in hooks) {
    if ([hook isKindOfClass:NSString.class] && hook.length > 0 &&
        ![self isInternalModuleCapability:hook]) {
      [tagsHTML appendFormat:@"<code>%@</code>", [self htmlEscapedString:hook]];
    }
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>%@</h1>"
       "<section>"
       "<p class='note'>%@</p>"
       "<dl>"
       "<dt>Identifier</dt><dd><code>%@</code></dd>"
       "<dt>Version</dt><dd>%@</dd>"
       "<dt>Type</dt><dd>%@</dd>"
       "<dt>Status</dt><dd>%@</dd>"
       "<dt>PHP</dt><dd><code>%@</code></dd>"
       "<dt>Vendor</dt><dd>%@</dd>"
       "</dl>"
       "</section>"
       "<section><h2>Routes</h2><ul>%@</ul></section>"
       "<section><h2>Capabilities</h2><div class='routeList'>%@</div></section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName],
      [self htmlEscapedString:moduleDescription],
      [self htmlEscapedString:moduleIdentifier ?: @""],
      [self htmlEscapedString:moduleVersion],
      [self htmlEscapedString:moduleType],
      enabled ? @"Enabled" : @"Disabled",
      [self htmlEscapedString:phpRequirement],
      hasIsolatedVendor ? @"Own vendor" : @"No module vendor",
      routesHTML.length > 0 ? routesHTML : @"<li>No route declared.</li>",
      tagsHTML.length > 0 ? tagsHTML : @"<span class='empty'>No capability declared.</span>"];

  return [self internalPageHTMLWithTitle:moduleName body:body];
}

- (NSString*)moduleUpdatesPageHTML {
  NSDictionary* updateResult = [self moduleUpdateReleaseManifestResult];
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSString* sourceLabel = [updateResult[@"sourceLabel"] isKindOfClass:NSString.class]
      ? updateResult[@"sourceLabel"]
      : @"No source";
  NSString* errorMessage = [updateResult[@"error"] isKindOfClass:NSString.class] ? updateResult[@"error"] : @"";
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  NSDictionary* releaseModulesByIdentifier = [self releaseModulesByIdentifier:releaseModules];

  NSError* snapshotError = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&snapshotError];
  NSArray* installedModules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];

  NSMutableString* rowsHTML = [NSMutableString string];
  NSUInteger updateCount = 0;
  if (snapshotError) {
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>",
                           [self htmlEscapedString:snapshotError.localizedDescription]];
  } else if (manifest.count == 0) {
    NSString* message = errorMessage.length > 0
        ? errorMessage
        : @"Configure an update URL or a local update folder containing module zips.";
    [rowsHTML appendFormat:@"<p class='empty'>%@</p>", [self htmlEscapedString:message]];
  } else if (installedModules.count == 0) {
    [rowsHTML appendString:@"<p class='empty'>No installed module was found.</p>"];
  } else {
    NSMutableString* updateRowsHTML = [NSMutableString string];
    for (NSDictionary* module in installedModules) {
      if (![module isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
      NSString* moduleName = [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : moduleIdentifier;
      NSString* installedVersion = [module[@"version"] isKindOfClass:NSString.class] ? module[@"version"] : @"";
      NSDictionary* releaseModule = releaseModulesByIdentifier[moduleIdentifier];
      NSString* availableVersion =
          [releaseModule[@"version"] isKindOfClass:NSString.class] ? releaseModule[@"version"] : @"";
      NSString* status = @"Not found in update source";
      NSString* actionHTML = @"";
      if (availableVersion.length > 0) {
        NSComparisonResult comparison = [self compareVersion:availableVersion toVersion:installedVersion];
        if (comparison == NSOrderedDescending) {
          status = @"Update available";
          actionHTML = [NSString stringWithFormat:
              @"<label class='updateCheckbox'><input class='updateItemCheckbox' type='checkbox' name='installUpdates' value='%@'> Update</label>",
              [self queryEscapedString:moduleIdentifier]];
          updateCount++;
        } else if (comparison == NSOrderedSame) {
          status = @"Up to date";
        } else {
          status = @"Installed version is newer";
        }
      }

      NSString* wrappedActionsHTML = actionHTML.length > 0
          ? [NSString stringWithFormat:@"<div class='actions'>%@</div>", actionHTML]
          : @"";
      if (actionHTML.length == 0) {
        continue;
      }

      [updateRowsHTML appendFormat:
          @"<li><span>%@</span><small>%@ - Installed %@ - Available %@</small><em>%@</em>%@</li>",
          [self htmlEscapedString:moduleName],
          [self htmlEscapedString:moduleIdentifier],
          [self htmlEscapedString:installedVersion.length > 0 ? installedVersion : @"Unknown"],
          [self htmlEscapedString:availableVersion.length > 0 ? availableVersion : @"None"],
          [self htmlEscapedString:status],
          wrappedActionsHTML];
    }
    if (updateCount == 0) {
      [rowsHTML appendString:@"<p class='empty'>No update available.</p>"];
    } else {
      [rowsHTML appendFormat:
          @"<form class='updatesForm' action='babelchrome://modules' method='get'>"
           "<input type='hidden' name='installSelectedUpdates' value='1'>"
           "<div class='updatesToolbar'>"
           "<label><input id='selectAllUpdates' type='checkbox'> Select all</label>"
           "<button class='primaryButton' type='submit'>Install Updates</button>"
           "</div>"
           "<ul class='stripedList updateList'>%@</ul>"
           "</form>",
          updateRowsHTML];
    }
  }

  NSString* updateURLString = [self moduleUpdateURLString];
  NSString* localDirectory = [self moduleUpdateLocalDirectoryPath];
  NSString* updateScriptHTML = updateCount > 0
      ? @"<script>"
         "const selectAllUpdates=document.getElementById('selectAllUpdates');"
         "if(selectAllUpdates){selectAllUpdates.addEventListener('change',()=>{"
         "document.querySelectorAll('.updateItemCheckbox').forEach((checkbox)=>{checkbox.checked=selectAllUpdates.checked;});"
         "});}"
         "</script>"
      : @"";
  NSString* body = [NSString stringWithFormat:
      @"<h1>Module Updates</h1>"
       "<section>"
       "<h2>Source</h2>"
       "<dl>"
       "<dt>Used source</dt><dd>%@</dd>"
       "<dt>URL source</dt><dd>%@</dd>"
       "<dt>Local fallback</dt><dd>%@</dd>"
       "</dl>"
       "</section>"
       "<section>"
       "<h2>Available Updates</h2>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></div>"
       "%@",
      [self htmlEscapedString:sourceLabel],
      [self htmlEscapedString:updateURLString.length > 0 ? updateURLString : @"Not configured"],
      [self htmlEscapedString:localDirectory.length > 0 ? localDirectory : @"Not configured"],
      rowsHTML,
      updateScriptHTML];
  return [self internalPageHTMLWithTitle:@"Module Updates" body:body];
}

- (void)configureModuleUpdateURLFromPrompt {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Module Update URL";
  alert.informativeText =
      @"Enter either the direct modules-release-manifest.json URL or a base URL containing that file.";
  [alert addButtonWithTitle:@"Save"];
  [alert addButtonWithTitle:@"Cancel"];
  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 520, 28)];
  textField.stringValue = [self moduleUpdateURLString];
  alert.accessoryView = textField;
  if ([alert runModal] != NSAlertFirstButtonReturn) {
    return;
  }

  NSString* value = [textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (value.length == 0) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kModuleUpdateURLDefaultsKey];
  } else {
    [NSUserDefaults.standardUserDefaults setObject:value forKey:kModuleUpdateURLDefaultsKey];
  }
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)configureModuleUpdateLocalDirectoryFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Choose Module Update Folder";
  NSString* currentPath = [self moduleUpdateLocalDirectoryPath];
  if (currentPath.length > 0) {
    panel.directoryURL = [NSURL fileURLWithPath:currentPath];
  }
  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* path = panel.URL.path ?: @"";
  if (path.length == 0) {
    return;
  }

  [NSUserDefaults.standardUserDefaults setObject:path forKey:kModuleUpdateLocalDirectoryDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)installPHPModuleUpdateWithIdentifier:(NSString*)moduleIdentifier {
  [self installPHPModuleUpdatesWithIdentifiers:moduleIdentifier.length > 0 ? @[moduleIdentifier] : @[]];
}

- (void)installPHPModuleUpdatesWithIdentifiers:(NSArray<NSString*>*)moduleIdentifiers {
  if (moduleIdentifiers.count == 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{NSLocalizedDescriptionKey : @"Select at least one module update to install."}]];
    return;
  }

  NSDictionary* updateResult = [self moduleUpdateReleaseManifestResult];
  BOOL didInstallAtLeastOneModule = NO;
  NSMutableSet<NSString*>* seenModuleIdentifiers = [NSMutableSet set];
  NSMutableArray<NSString*>* errors = [NSMutableArray array];

  for (NSString* moduleIdentifier in moduleIdentifiers) {
    NSString* trimmedModuleIdentifier =
        [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedModuleIdentifier.length == 0 || [seenModuleIdentifiers containsObject:trimmedModuleIdentifier]) {
      continue;
    }
    [seenModuleIdentifiers addObject:trimmedModuleIdentifier];

    NSDictionary* releaseModule = [self releaseModuleWithIdentifier:trimmedModuleIdentifier updateResult:updateResult];
    if (!releaseModule) {
      [errors addObject:[NSString stringWithFormat:@"%@: update was not found.", trimmedModuleIdentifier]];
      continue;
    }

    NSError* error = nil;
    NSString* zipPath = [self resolvedUpdateZipPathForReleaseModule:releaseModule
                                                       updateResult:updateResult
                                                              error:&error];
    if (zipPath.length == 0) {
      NSString* message = error.localizedDescription ?: @"Unable to resolve the update zip.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    NSDictionary* response = [BabelLocalServiceHost.sharedHost installModuleZipAtPath:zipPath error:&error];
    if (!response) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (didInstallAtLeastOneModule) {
    [self refreshBabelChromeFileTypeCapabilities];
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:2
                        userInfo:@{NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]}]];
  }
}

- (NSDictionary*)moduleUpdateReleaseManifestResult {
  NSString* updateURLString = [self moduleUpdateURLString];
  NSError* urlError = nil;
  if (updateURLString.length > 0) {
    NSDictionary* result = [self releaseManifestResultFromURLString:updateURLString error:&urlError];
    if (result) {
      return result;
    }
  }

  NSString* localDirectory = [self moduleUpdateLocalDirectoryPath];
  if (localDirectory.length > 0) {
    NSError* error = nil;
    NSDictionary* result = [self releaseManifestResultFromLocalPath:localDirectory error:&error];
    if (result) {
      return result;
    }
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"Local fallback: %@", localDirectory],
      @"error" : error.localizedDescription ?: @"Unable to read the local update folder."
    };
  }

  if (updateURLString.length > 0) {
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"URL: %@", updateURLString],
      @"error" : urlError.localizedDescription ?: @"Unable to read the update URL and no local fallback is configured."
    };
  }

  return @{
    @"sourceLabel" : @"No source configured",
    @"error" : @"Configure an update URL or a local update folder."
  };
}

- (NSDictionary*)releaseManifestResultFromURLString:(NSString*)urlString error:(NSError**)error {
  NSURL* manifestURL = [self moduleUpdateManifestURLForURLString:urlString];
  if (!manifestURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"The configured update URL is invalid."}];
    }
    return nil;
  }

  NSData* data = [NSData dataWithContentsOfURL:manifestURL options:0 error:error];
  if (!data) {
    return nil;
  }

  NSDictionary* manifest = [self releaseManifestFromData:data error:error];
  if (!manifest) {
    return nil;
  }

  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"url",
    @"sourceLabel" : manifestURL.absoluteString ?: @"URL",
    @"baseURL" : [manifestURL URLByDeletingLastPathComponent].absoluteString ?: @""
  };
}

- (NSDictionary*)releaseManifestResultFromLocalPath:(NSString*)path error:(NSError**)error {
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:6
                               userInfo:@{NSLocalizedDescriptionKey : @"The local update source must be a folder containing module zips."}];
    }
    return nil;
  }

  NSArray* directoryEntries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:error];
  if (!directoryEntries) {
    return nil;
  }

  NSDictionary* cachedIndex = [self moduleUpdateLocalIndex];
  NSDictionary* cachedItems = [cachedIndex[@"items"] isKindOfClass:NSDictionary.class] ? cachedIndex[@"items"] : @{};
  NSMutableDictionary* nextCachedItems = [NSMutableDictionary dictionary];
  NSMutableDictionary* latestModulesByIdentifier = [NSMutableDictionary dictionary];

  for (NSString* entryName in directoryEntries) {
    if (![entryName isKindOfClass:NSString.class] || ![entryName.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      continue;
    }

    NSString* zipPath = [path stringByAppendingPathComponent:entryName];
    NSDictionary* releaseModule = [self releaseModuleFromLocalZipAtPath:zipPath
                                                               fileName:entryName
                                                            cachedItems:cachedItems];
    if (!releaseModule) {
      continue;
    }

    nextCachedItems[zipPath] = releaseModule;
    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length == 0) {
      continue;
    }

    NSDictionary* currentModule = latestModulesByIdentifier[moduleIdentifier];
    if (!currentModule || [self shouldPreferReleaseModule:releaseModule overReleaseModule:currentModule]) {
      latestModulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  [self writeModuleUpdateLocalIndex:@{
    @"version" : @1,
    @"items" : nextCachedItems
  }];

  NSArray* modules = [latestModulesByIdentifier.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* leftModule,
                                                                                                         NSDictionary* rightModule) {
    NSString* leftIdentifier = [leftModule[@"id"] isKindOfClass:NSString.class] ? leftModule[@"id"] : @"";
    NSString* rightIdentifier = [rightModule[@"id"] isKindOfClass:NSString.class] ? rightModule[@"id"] : @"";
    return [leftIdentifier compare:rightIdentifier options:NSCaseInsensitiveSearch];
  }];
  if (modules.count == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:7
                               userInfo:@{NSLocalizedDescriptionKey : @"No valid module zip was found in the local update folder."}];
    }
    return nil;
  }

  NSDictionary* manifest = @{
    @"generatedAt" : [NSDate.date descriptionWithLocale:nil],
    @"modules" : modules
  };
  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"local",
    @"sourceLabel" : [NSString stringWithFormat:@"Local folder: %@", path],
    @"basePath" : path
  };
}

- (NSDictionary*)releaseModuleFromLocalZipAtPath:(NSString*)zipPath
                                        fileName:(NSString*)fileName
                                     cachedItems:(NSDictionary*)cachedItems {
  NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:zipPath error:nil];
  NSDate* modificationDate = [attributes[NSFileModificationDate] isKindOfClass:NSDate.class]
      ? attributes[NSFileModificationDate]
      : NSDate.distantPast;
  NSNumber* fileSize = [attributes[NSFileSize] isKindOfClass:NSNumber.class] ? attributes[NSFileSize] : @0;
  NSNumber* modifiedAt = @((NSInteger)floor(modificationDate.timeIntervalSince1970));

  NSDictionary* cachedItem = [cachedItems[zipPath] isKindOfClass:NSDictionary.class] ? cachedItems[zipPath] : nil;
  if (cachedItem &&
      [cachedItem[@"filemtime"] isEqual:modifiedAt] &&
      [cachedItem[@"size"] isEqual:fileSize] &&
      [cachedItem[@"id"] isKindOfClass:NSString.class] &&
      [cachedItem[@"version"] isKindOfClass:NSString.class]) {
    return cachedItem;
  }

  NSError* manifestError = nil;
  NSDictionary* moduleManifest = [self moduleManifestFromZipAtPath:zipPath error:&manifestError];
  if (!moduleManifest) {
    NSLog(@"Unable to read module update zip manifest at %@: %@", zipPath, manifestError.localizedDescription);
    return nil;
  }

  NSString* moduleIdentifier = [moduleManifest[@"id"] isKindOfClass:NSString.class] ? moduleManifest[@"id"] : @"";
  NSString* moduleVersion = [moduleManifest[@"version"] isKindOfClass:NSString.class] ? moduleManifest[@"version"] : @"";
  if (moduleIdentifier.length == 0 || moduleVersion.length == 0) {
    NSLog(@"Skipping module update zip without id or version: %@", zipPath);
    return nil;
  }

  NSString* moduleName = [moduleManifest[@"name"] isKindOfClass:NSString.class] ? moduleManifest[@"name"] : moduleIdentifier;
  NSMutableDictionary* releaseModule = [NSMutableDictionary dictionaryWithDictionary:moduleManifest];
  releaseModule[@"id"] = moduleIdentifier;
  releaseModule[@"name"] = moduleName;
  releaseModule[@"version"] = moduleVersion;
  releaseModule[@"zip"] = fileName ?: zipPath.lastPathComponent;
  releaseModule[@"path"] = zipPath;
  releaseModule[@"filemtime"] = modifiedAt;
  releaseModule[@"size"] = fileSize;
  return releaseModule;
}

- (BOOL)shouldPreferReleaseModule:(NSDictionary*)candidateModule overReleaseModule:(NSDictionary*)currentModule {
  NSString* candidateVersion = [candidateModule[@"version"] isKindOfClass:NSString.class] ? candidateModule[@"version"] : @"";
  NSString* currentVersion = [currentModule[@"version"] isKindOfClass:NSString.class] ? currentModule[@"version"] : @"";
  NSComparisonResult versionComparison = [self compareVersion:candidateVersion toVersion:currentVersion];
  if (versionComparison == NSOrderedDescending) {
    return YES;
  }
  if (versionComparison == NSOrderedAscending) {
    return NO;
  }

  NSNumber* candidateModifiedAt = [candidateModule[@"filemtime"] isKindOfClass:NSNumber.class] ? candidateModule[@"filemtime"] : @0;
  NSNumber* currentModifiedAt = [currentModule[@"filemtime"] isKindOfClass:NSNumber.class] ? currentModule[@"filemtime"] : @0;
  return [candidateModifiedAt compare:currentModifiedAt] == NSOrderedDescending;
}

- (NSDictionary*)moduleManifestFromZipAtPath:(NSString*)zipPath error:(NSError**)error {
  NSData* manifestData = [self dataFromZipAtPath:zipPath innerPath:@"manifest.json" error:nil];
  if (!manifestData) {
    manifestData = [self dataFromZipAtPath:zipPath innerPath:@"*/manifest.json" error:error];
  }
  if (!manifestData) {
    return nil;
  }

  return [self releaseManifestFromData:manifestData error:error];
}

- (NSData*)dataFromZipAtPath:(NSString*)zipPath innerPath:(NSString*)innerPath error:(NSError**)error {
  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
  task.arguments = @[@"-p", zipPath, innerPath];

  NSPipe* outputPipe = [NSPipe pipe];
  NSPipe* errorPipe = [NSPipe pipe];
  task.standardOutput = outputPipe;
  task.standardError = errorPipe;

  NSError* launchError = nil;
  if (![task launchAndReturnError:&launchError]) {
    if (error) {
      *error = launchError;
    }
    return nil;
  }

  NSData* outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
  NSData* errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (task.terminationStatus != 0 || outputData.length == 0) {
    if (error) {
      NSString* unzipError = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:8
                               userInfo:@{NSLocalizedDescriptionKey : unzipError.length > 0
                                                                    ? unzipError
                                                                    : @"Unable to extract manifest.json from the module zip."}];
    }
    return nil;
  }

  return outputData;
}

- (NSDictionary*)moduleUpdateLocalIndex {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSData* data = [NSData dataWithContentsOfFile:indexPath];
  if (!data) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (void)writeModuleUpdateLocalIndex:(NSDictionary*)index {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSString* indexDirectory = indexPath.stringByDeletingLastPathComponent;
  [NSFileManager.defaultManager createDirectoryAtPath:indexDirectory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
  if (data) {
    [data writeToFile:indexPath options:NSDataWritingAtomic error:nil];
  }
}

- (NSDictionary*)releaseManifestFromData:(NSData*)data error:(NSError**)error {
  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest is not a JSON object."}];
    }
    return nil;
  }

  return decoded;
}

- (NSDictionary*)releaseModulesByIdentifier:(NSArray*)releaseModules {
  NSMutableDictionary* modulesByIdentifier = [NSMutableDictionary dictionary];
  for (NSDictionary* releaseModule in releaseModules) {
    if (![releaseModule isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length > 0) {
      modulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  return modulesByIdentifier;
}

- (NSDictionary*)releaseModuleWithIdentifier:(NSString*)moduleIdentifier updateResult:(NSDictionary*)updateResult {
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  return [self releaseModulesByIdentifier:releaseModules][moduleIdentifier ?: @""];
}

- (NSString*)resolvedUpdateZipPathForReleaseModule:(NSDictionary*)releaseModule
                                      updateResult:(NSDictionary*)updateResult
                                             error:(NSError**)error {
  NSString* zipName = [releaseModule[@"zip"] isKindOfClass:NSString.class] ? releaseModule[@"zip"] : @"";
  if (zipName.length == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest entry does not declare a zip file."}];
    }
    return @"";
  }

  NSString* sourceKind = [updateResult[@"sourceKind"] isKindOfClass:NSString.class] ? updateResult[@"sourceKind"] : @"";
  if ([sourceKind isEqualToString:@"local"]) {
    NSString* basePath = [updateResult[@"basePath"] isKindOfClass:NSString.class] ? updateResult[@"basePath"] : @"";
    NSString* zipPath = [basePath stringByAppendingPathComponent:zipName];
    if ([NSFileManager.defaultManager fileExistsAtPath:zipPath]) {
      return zipPath;
    }
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Update zip not found: %@", zipPath]}];
    }
    return @"";
  }

  NSString* baseURLString = [updateResult[@"baseURL"] isKindOfClass:NSString.class] ? updateResult[@"baseURL"] : @"";
  NSURL* baseURL = [NSURL URLWithString:baseURLString];
  NSURL* zipURL = [NSURL URLWithString:zipName relativeToURL:baseURL];
  if (!zipURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey : @"The update zip URL is invalid."}];
    }
    return @"";
  }

  NSData* data = [NSData dataWithContentsOfURL:zipURL options:0 error:error];
  if (!data) {
    return @"";
  }

  NSString* targetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:zipName.lastPathComponent];
  if (![data writeToFile:targetPath options:NSDataWritingAtomic error:error]) {
    return @"";
  }

  return targetPath;
}

- (NSURL*)moduleUpdateManifestURLForURLString:(NSString*)urlString {
  NSString* trimmedString =
      [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedString.length == 0) {
    return nil;
  }

  NSURL* sourceURL = [NSURL URLWithString:trimmedString];
  if (!sourceURL.scheme.length) {
    return nil;
  }

  if ([sourceURL.path.lastPathComponent isEqualToString:@"modules-release-manifest.json"] ||
      [sourceURL.pathExtension.lowercaseString isEqualToString:@"json"]) {
    return sourceURL;
  }

  NSString* separator = [trimmedString hasSuffix:@"/"] ? @"" : @"/";
  return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@modules-release-manifest.json",
                                                         trimmedString,
                                                         separator]];
}

- (NSString*)moduleUpdateLocalIndexPath {
  return [BabelChromeConfiguration.applicationSupportDirectoryURL.path stringByAppendingPathComponent:kModuleUpdateLocalIndexFilename];
}

- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion {
  return [leftVersion compare:rightVersion options:NSNumericSearch];
}

- (NSString*)moduleUpdateURLString {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateURLDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSString*)moduleUpdateLocalDirectoryPath {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateLocalDirectoryDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSDictionary*)moduleRouteForBabelChromeComponents:(NSURLComponents*)components
                                               error:(NSError**)error {
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:error];
  if (!snapshot) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme ?: @"";
  NSString* host = components.host ?: @"";
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
      if ([routeScheme isEqualToString:scheme] && [routeHost isEqualToString:host] &&
          moduleIdentifier.length > 0 && routeHandler.length > 0) {
        return @{
          @"moduleIdentifier" : moduleIdentifier,
          @"route" : routeHandler
        };
      }
    }
  }

  return nil;
}

- (void)refreshBabelChromeFileTypeCapabilities {
  if (browserClient_) {
    browserClient_->RefreshFileTypesHeaderValue();
  }
}

- (void)installPHPModuleZipFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;
  panel.title = @"Install PHP Modules";
  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  BOOL didInstallAtLeastOneModule = NO;
  NSMutableArray<NSString*>* errors = [NSMutableArray array];
  for (NSURL* url in panel.URLs) {
    if (![url.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      [errors addObject:[NSString stringWithFormat:@"%@: selected package must be a zip archive.",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file"]];
      continue;
    }

    NSError* error = nil;
    NSDictionary* response = [BabelLocalServiceHost.sharedHost installModuleZipAtPath:url.path
                                                                                error:&error];
    if (!response) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file",
                                                   message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (didInstallAtLeastOneModule) {
    [self refreshBabelChromeFileTypeCapabilities];
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{
                          NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]
                        }]];
    return;
  }
}

- (void)setPHPModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled {
  NSError* error = nil;
  NSDictionary* response = [BabelLocalServiceHost.sharedHost setModuleWithIdentifier:moduleIdentifier
                                                                             enabled:enabled
                                                                               error:&error];
  if (!response) {
    [self showModuleActionAlertWithError:error];
    return;
  }

  [self refreshBabelChromeFileTypeCapabilities];
}

- (void)removePHPModuleWithIdentifier:(NSString*)moduleIdentifier {
  NSAlert* confirmation = [[NSAlert alloc] init];
  confirmation.messageText = @"Remove PHP Module";
  confirmation.informativeText =
      [NSString stringWithFormat:@"Remove module \"%@\" from BabelChrome?", moduleIdentifier ?: @""];
  [confirmation addButtonWithTitle:@"Remove"];
  [confirmation addButtonWithTitle:@"Cancel"];
  confirmation.alertStyle = NSAlertStyleWarning;
  if ([confirmation runModal] != NSAlertFirstButtonReturn) {
    return;
  }

  NSError* error = nil;
  NSDictionary* response = [BabelLocalServiceHost.sharedHost removeModuleWithIdentifier:moduleIdentifier
                                                                                  error:&error];
  if (!response) {
    [self showModuleActionAlertWithError:error];
    return;
  }

  [self refreshBabelChromeFileTypeCapabilities];
}

- (void)showModuleActionAlertWithError:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Manage PHP Module";
  alert.informativeText = error.localizedDescription ?: @"The module operation failed.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

- (NSString*)userModulesDirectoryPath {
  NSArray<NSURL*>* applicationSupportURLs =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask];
  NSURL* baseURL = applicationSupportURLs.firstObject;
  if (!baseURL) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"BabelChrome/Modules"];
  }

  return [[baseURL URLByAppendingPathComponent:@"BabelForge/BabelChrome/Modules"
                                   isDirectory:YES] path];
}

- (NSString*)settingsTabOpeningStrategyHTML:(NSString*)selectedStrategy {
  NSString* originalClass = [selectedStrategy isEqualToString:kTabOpeningStrategyAppend]
      ? @"option selected"
      : @"option";
  NSString* childClusterClass = [selectedStrategy isEqualToString:kTabOpeningStrategyChildCluster]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Original</strong><span>New tabs open at the end of the tab bar.</span></a>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Parent group</strong><span>New tabs opened from a page stay next to their parent tab.</span></a>"
       "</div>",
      originalClass,
      kTabOpeningStrategyAppend,
      childClusterClass,
      kTabOpeningStrategyChildCluster];
}

- (NSString*)settingsAddressSuggestionsHTML:(NSString*)selectedMode {
  NSString* localClass = [selectedMode isEqualToString:kAddressSuggestionsModeLocal]
      ? @"option selected"
      : @"option";
  NSString* googleClass = [selectedMode isEqualToString:kAddressSuggestionsModeGoogle]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local only</strong><span>Use open tabs and recently closed tabs only.</span></a>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local + Google</strong><span>Also ask Google Suggest while typing.</span></a>"
       "</div>",
      localClass,
      kAddressSuggestionsModeLocal,
      googleClass,
      kAddressSuggestionsModeGoogle];
}

- (NSString*)settingsAppearanceThemeHTML:(NSString*)selectedTheme {
  NSDictionary<NSString*, NSString*>* labels = @{
    BabelThemeAppearanceSystem : @"System",
    BabelThemeAppearanceLight : @"Light",
    BabelThemeAppearanceDark : @"Dark",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    BabelThemeAppearanceSystem : @"Follow the current macOS appearance.",
    BabelThemeAppearanceLight : @"Always use BabelChrome light colors.",
    BabelThemeAppearanceDark : @"Always use BabelChrome dark colors.",
  };
  NSArray<NSString*>* themes = @[
    BabelThemeAppearanceSystem,
    BabelThemeAppearanceLight,
    BabelThemeAppearanceDark
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='babelchrome://settings?appearanceTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
}

- (NSString*)settingsLongQuitShortcutHTML:(BOOL)enabled {
  NSString* offClass = enabled ? @"option" : @"option selected";
  NSString* onClass = enabled ? @"option selected" : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?longQuitShortcut=0'>"
       "<strong>Immediate Cmd+Q</strong><span>Quit as soon as Cmd+Q is pressed.</span></a>"
       "<a class='%@' href='babelchrome://settings?longQuitShortcut=1'>"
       "<strong>Long Cmd+Q</strong><span>Require Cmd+Q to be held for 2 seconds before quitting.</span></a>"
       "</div>",
      offClass,
      onClass];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme {
  return [self settingsMarkdownThemeHTML:selectedTheme settingsURLString:@"babelchrome://settings"];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme settingsURLString:(NSString*)settingsURLString {
  NSDictionary<NSString*, NSString*>* labels = @{
    kMarkdownThemeGitHubLight : @"GitHub Light",
    kMarkdownThemeGitHubDark : @"GitHub Dark",
    kMarkdownThemeReader : @"Reader",
    kMarkdownThemeCompact : @"Compact",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    kMarkdownThemeGitHubLight : @"Default technical documentation style.",
    kMarkdownThemeGitHubDark : @"Dark technical documentation style.",
    kMarkdownThemeReader : @"Wider reading rhythm for long documents.",
    kMarkdownThemeCompact : @"Denser rendering for reference documents.",
  };
  NSArray<NSString*>* themes = @[
    kMarkdownThemeGitHubLight,
    kMarkdownThemeGitHubDark,
    kMarkdownThemeReader,
    kMarkdownThemeCompact
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='%@?markdownTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        [self htmlEscapedString:settingsURLString ?: @"babelchrome://settings"],
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
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

- (NSArray<NSString*>*)installedExtensionPaths {
  NSArray* extensionPaths =
      [NSUserDefaults.standardUserDefaults arrayForKey:BabelChromeConfiguration.extensionPathsDefaultsKey];
  if (![extensionPaths isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* stringPaths = [NSMutableArray array];
  for (NSString* extensionPath in extensionPaths) {
    if ([extensionPath isKindOfClass:NSString.class] && extensionPath.length > 0) {
      [stringPaths addObject:extensionPath];
    }
  }
  return stringPaths;
}

- (NSArray<NSDictionary*>*)profileInstalledExtensions {
  NSURL* extensionsDirectoryURL = [[BabelChromeConfiguration.profileDirectoryURL
      URLByAppendingPathComponent:@"Default" isDirectory:YES]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES];
  NSMutableDictionary<NSString*, NSDictionary*>* extensionsByIdentifier = [NSMutableDictionary dictionary];
  [self collectProfileExtensionsFromDirectory:extensionsDirectoryURL
                                      enabled:YES
                       extensionsByIdentifier:extensionsByIdentifier];
  [self collectProfileExtensionsFromDirectory:BabelChromeConfiguration.profileExtensionBackupDirectoryURL
                                      enabled:NO
                       extensionsByIdentifier:extensionsByIdentifier];
  for (NSString* disabledIdentifier in [self disabledProfileExtensionIdentifiers]) {
    if (extensionsByIdentifier[disabledIdentifier]) {
      continue;
    }
    extensionsByIdentifier[disabledIdentifier] = @{
      @"id": disabledIdentifier,
      @"name": disabledIdentifier,
      @"version": @"Missing package",
      @"path": @"The extension package is missing from the Chromium profile. Reinstall it from the Chrome Web Store.",
      @"enabled": @NO
    };
  }
  NSMutableArray<NSDictionary*>* extensions = [NSMutableArray arrayWithArray:extensionsByIdentifier.allValues];
  [extensions sortUsingDescriptors:@[
    [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]
  ]];
  return extensions;
}

- (void)collectProfileExtensionsFromDirectory:(NSURL*)extensionsDirectoryURL
                                      enabled:(BOOL)enabled
                       extensionsByIdentifier:(NSMutableDictionary<NSString*, NSDictionary*>*)extensionsByIdentifier {
  NSArray<NSURL*>* extensionIdentifierURLs =
      [NSFileManager.defaultManager contentsOfDirectoryAtURL:extensionsDirectoryURL
                                  includingPropertiesForKeys:nil
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
  for (NSURL* extensionIdentifierURL in extensionIdentifierURLs) {
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:extensionIdentifierURL.path
                                            isDirectory:&isDirectory] ||
        !isDirectory) {
      continue;
    }

    NSArray<NSURL*>* versionURLs =
        [NSFileManager.defaultManager contentsOfDirectoryAtURL:extensionIdentifierURL
                                    includingPropertiesForKeys:nil
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:nil];
    NSURL* latestVersionURL = [self latestExtensionVersionURLFromURLs:versionURLs];
    if (!latestVersionURL) {
      continue;
    }

    NSDictionary* manifest = [self extensionManifestAtURL:
        [latestVersionURL URLByAppendingPathComponent:@"manifest.json" isDirectory:NO]];
    if (!manifest) {
      continue;
    }

    NSString* name = [self extensionNameFromManifest:manifest extensionURL:latestVersionURL];
    NSString* version = [manifest[@"version"] isKindOfClass:NSString.class] ? manifest[@"version"] : @"";
    NSString* identifier = extensionIdentifierURL.lastPathComponent ?: @"";
    extensionsByIdentifier[identifier] = @{
      @"id": identifier,
      @"name": name.length > 0 ? name : identifier,
      @"version": version.length > 0 ? version : latestVersionURL.lastPathComponent ?: @"",
      @"path": latestVersionURL.path ?: @"",
      @"enabled": @(enabled && [self profileExtensionWithIdentifierIsEnabled:identifier])
    };
  }
}

- (NSURL*)latestExtensionVersionURLFromURLs:(NSArray<NSURL*>*)versionURLs {
  NSArray<NSURL*>* sortedURLs = [versionURLs sortedArrayUsingComparator:^NSComparisonResult(
      NSURL* firstURL,
      NSURL* secondURL) {
    return [secondURL.lastPathComponent compare:firstURL.lastPathComponent
                                        options:NSNumericSearch];
  }];
  for (NSURL* versionURL in sortedURLs) {
    BOOL isDirectory = NO;
    NSString* manifestPath = [[versionURL URLByAppendingPathComponent:@"manifest.json"
                                                           isDirectory:NO] path];
    if ([NSFileManager.defaultManager fileExistsAtPath:versionURL.path isDirectory:&isDirectory] &&
        isDirectory &&
        [NSFileManager.defaultManager fileExistsAtPath:manifestPath]) {
      return versionURL;
    }
  }
  return nil;
}

- (NSDictionary*)extensionManifestAtURL:(NSURL*)manifestURL {
  NSData* data = [NSData dataWithContentsOfURL:manifestURL];
  if (!data) {
    return nil;
  }

  id manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [manifest isKindOfClass:NSDictionary.class] ? manifest : nil;
}

- (NSString*)extensionNameFromManifest:(NSDictionary*)manifest extensionURL:(NSURL*)extensionURL {
  NSString* name = [manifest[@"name"] isKindOfClass:NSString.class] ? manifest[@"name"] : @"";
  if (![name hasPrefix:@"__MSG_"] || ![name hasSuffix:@"__"]) {
    return name;
  }

  NSString* messageKey = [name substringWithRange:NSMakeRange(6, name.length - 8)];
  NSString* defaultLocale = [manifest[@"default_locale"] isKindOfClass:NSString.class]
      ? manifest[@"default_locale"]
      : @"en";
  NSString* localizedName = [self localizedExtensionMessageForKey:messageKey
                                                           locale:defaultLocale
                                                     extensionURL:extensionURL];
  return localizedName.length > 0 ? localizedName : name;
}

- (NSString*)localizedExtensionMessageForKey:(NSString*)messageKey
                                      locale:(NSString*)locale
                                extensionURL:(NSURL*)extensionURL {
  NSURL* messagesURL = [[[extensionURL URLByAppendingPathComponent:@"_locales"
                                                       isDirectory:YES]
      URLByAppendingPathComponent:locale isDirectory:YES]
      URLByAppendingPathComponent:@"messages.json" isDirectory:NO];
  NSData* data = [NSData dataWithContentsOfURL:messagesURL];
  if (!data) {
    return @"";
  }

  id messages = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![messages isKindOfClass:NSDictionary.class]) {
    return @"";
  }

  NSDictionary* message = messages[messageKey];
  if (![message isKindOfClass:NSDictionary.class] ||
      ![message[@"message"] isKindOfClass:NSString.class]) {
    return @"";
  }
  return message[@"message"];
}

- (NSURL*)profilePreferencesFileURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Preferences" isDirectory:NO];
}

- (NSURL*)profileSecurePreferencesFileURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Secure Preferences" isDirectory:NO];
}

- (NSURL*)profileExtensionDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [[[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                         isDirectory:YES]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES]
      URLByAppendingPathComponent:extensionIdentifier isDirectory:YES];
}

- (NSURL*)profileExtensionBackupDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [BabelChromeConfiguration.profileExtensionBackupDirectoryURL
      URLByAppendingPathComponent:extensionIdentifier isDirectory:YES];
}

- (NSURL*)disabledProfileExtensionsDirectoryURL {
  return [[BabelChromeConfiguration.profileDirectoryURL URLByAppendingPathComponent:@"Default"
                                                                        isDirectory:YES]
      URLByAppendingPathComponent:@"Disabled Extensions" isDirectory:YES];
}

- (NSURL*)disabledProfileExtensionDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [[self disabledProfileExtensionsDirectoryURL] URLByAppendingPathComponent:extensionIdentifier
                                                                       isDirectory:YES];
}

- (NSDictionary*)profilePreferencesDictionaryAtURL:(NSURL*)preferencesURL {
  NSData* data = [NSData dataWithContentsOfURL:preferencesURL];
  if (!data) {
    return @{};
  }

  id preferences = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [preferences isKindOfClass:NSDictionary.class] ? preferences : @{};
}

- (NSMutableDictionary*)mutableProfilePreferencesDictionaryAtURL:(NSURL*)preferencesURL {
  NSData* data = [NSData dataWithContentsOfURL:preferencesURL];
  if (!data) {
    return [NSMutableDictionary dictionary];
  }

  id preferences = [NSJSONSerialization JSONObjectWithData:data
                                                   options:NSJSONReadingMutableContainers
                                                     error:nil];
  return [preferences isKindOfClass:NSMutableDictionary.class]
      ? preferences
      : [NSMutableDictionary dictionary];
}

- (BOOL)saveProfilePreferencesDictionary:(NSDictionary*)preferences toURL:(NSURL*)preferencesURL {
  if (preferences.count == 0) {
    return NO;
  }

  NSData* data = [NSJSONSerialization dataWithJSONObject:preferences options:0 error:nil];
  if (!data) {
    return NO;
  }

  return [data writeToURL:preferencesURL atomically:YES];
}

- (BOOL)profileExtensionWithIdentifierIsEnabled:(NSString*)extensionIdentifier {
  if ([[self disabledProfileExtensionIdentifiers] containsObject:extensionIdentifier]) {
    return NO;
  }

  NSDictionary* preferences = [self profilePreferencesDictionaryAtURL:[self profilePreferencesFileURL]];
  NSNumber* state = [self profileExtensionStateForIdentifier:extensionIdentifier
                                                 preferences:preferences];
  if (state) {
    return state.integerValue != 0;
  }

  return YES;
}

- (NSNumber*)profileExtensionStateForIdentifier:(NSString*)extensionIdentifier
                                    preferences:(NSDictionary*)preferences {
  NSDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  NSDictionary* settings = [extensions[@"settings"] isKindOfClass:NSDictionary.class]
      ? extensions[@"settings"]
      : nil;
  NSDictionary* extensionSettings = [settings[extensionIdentifier] isKindOfClass:NSDictionary.class]
      ? settings[extensionIdentifier]
      : nil;
  NSNumber* state = [extensionSettings[@"state"] isKindOfClass:NSNumber.class]
      ? extensionSettings[@"state"]
      : nil;
  return state;
}

- (BOOL)isValidProfileExtensionIdentifier:(NSString*)extensionIdentifier {
  if (extensionIdentifier.length == 0) {
    return NO;
  }

  NSCharacterSet* invalidCharacters =
      [[NSCharacterSet alphanumericCharacterSet] invertedSet];
  return [extensionIdentifier rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound;
}

- (void)setProfileExtensionWithIdentifier:(NSString*)extensionIdentifier enabled:(BOOL)enabled {
  if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
    return;
  }

  if (!enabled) {
    [self backupProfileExtensionWithIdentifier:extensionIdentifier];
  }
  [self saveProfileExtensionWithIdentifier:extensionIdentifier disabled:!enabled];
  [self savePendingProfileExtensionRestartStateForIdentifier:extensionIdentifier
                                                     enabled:enabled];
  [self setProfileExtensionPreferenceStateWithIdentifier:extensionIdentifier
                                                 enabled:enabled
                                          preferencesURL:[self profilePreferencesFileURL]
                                      createMissingEntry:YES];
}

- (void)restoreProfileExtensionsMovedByOlderVersions {
  NSFileManager* fileManager = NSFileManager.defaultManager;
  NSURL* disabledExtensionsURL = [self disabledProfileExtensionsDirectoryURL];
  NSArray<NSURL*>* disabledExtensionURLs =
      [fileManager contentsOfDirectoryAtURL:disabledExtensionsURL
                 includingPropertiesForKeys:nil
                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                      error:nil];
  for (NSURL* disabledExtensionURL in disabledExtensionURLs) {
    NSString* extensionIdentifier = disabledExtensionURL.lastPathComponent;
    if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
      continue;
    }

    NSURL* activeExtensionURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
    if ([fileManager fileExistsAtPath:activeExtensionURL.path]) {
      continue;
    }

    [fileManager createDirectoryAtURL:[activeExtensionURL URLByDeletingLastPathComponent]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
    [fileManager moveItemAtURL:disabledExtensionURL
                         toURL:activeExtensionURL
                         error:nil];
  }
}

- (void)backupProfileExtensionWithIdentifier:(NSString*)extensionIdentifier {
  NSURL* extensionDirectoryURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* backupDirectoryURL = [self profileExtensionBackupDirectoryURLForIdentifier:extensionIdentifier];
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:extensionDirectoryURL.path
                                         isDirectory:&isDirectory] ||
      !isDirectory) {
    return;
  }

  [NSFileManager.defaultManager createDirectoryAtURL:[backupDirectoryURL URLByDeletingLastPathComponent]
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  [NSFileManager.defaultManager removeItemAtURL:backupDirectoryURL error:nil];
  [NSFileManager.defaultManager copyItemAtURL:extensionDirectoryURL
                                        toURL:backupDirectoryURL
                                        error:nil];
}

- (NSArray<NSString*>*)disabledProfileExtensionIdentifiers {
  NSArray* identifiers = [NSUserDefaults.standardUserDefaults
      arrayForKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey];
  if (![identifiers isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* validIdentifiers = [NSMutableArray array];
  for (NSString* identifier in identifiers) {
    if ([identifier isKindOfClass:NSString.class] &&
        [self isValidProfileExtensionIdentifier:identifier]) {
      [validIdentifiers addObject:identifier];
    }
  }
  return validIdentifiers;
}

- (void)saveProfileExtensionWithIdentifier:(NSString*)extensionIdentifier disabled:(BOOL)disabled {
  NSMutableArray<NSString*>* identifiers = [[self disabledProfileExtensionIdentifiers] mutableCopy];
  if (disabled && ![identifiers containsObject:extensionIdentifier]) {
    [identifiers addObject:extensionIdentifier];
  }
  if (!disabled) {
    [identifiers removeObject:extensionIdentifier];
  }

  [NSUserDefaults.standardUserDefaults setObject:identifiers
                                          forKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (NSDictionary*)pendingProfileExtensionRestartStates {
  NSDictionary* states = [NSUserDefaults.standardUserDefaults
      dictionaryForKey:BabelChromeConfiguration.pendingProfileExtensionRestartStatesDefaultsKey];
  return [states isKindOfClass:NSDictionary.class] ? states : @{};
}

- (void)savePendingProfileExtensionRestartStateForIdentifier:(NSString*)extensionIdentifier
                                                    enabled:(BOOL)enabled {
  NSMutableDictionary* states = [[self pendingProfileExtensionRestartStates] mutableCopy];
  states[extensionIdentifier] = enabled ? @"enable" : @"disable";
  [NSUserDefaults.standardUserDefaults setObject:states
                                          forKey:[BabelChromeConfiguration
                                                     pendingProfileExtensionRestartStatesDefaultsKey]];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)clearPendingProfileExtensionRestartStates {
  [NSUserDefaults.standardUserDefaults removeObjectForKey:[BabelChromeConfiguration
                                                              pendingProfileExtensionRestartStatesDefaultsKey]];
  [NSUserDefaults.standardUserDefaults synchronize];
}

- (BOOL)profileExtensionRequiresRestart:(NSString*)extensionIdentifier {
  return [self pendingProfileExtensionRestartStates][extensionIdentifier] != nil;
}

- (NSString*)profileExtensionStatusLabelForIdentifier:(NSString*)extensionIdentifier
                                              enabled:(BOOL)enabled {
  NSString* pendingState = [self pendingProfileExtensionRestartStates][extensionIdentifier];
  if ([pendingState isEqualToString:@"enable"]) {
    return @"Enabled after restart";
  }
  if ([pendingState isEqualToString:@"disable"]) {
    return @"Disabled after restart";
  }
  return enabled ? @"Enabled" : @"Disabled";
}

- (void)setProfileExtensionPreferenceStateWithIdentifier:(NSString*)extensionIdentifier
                                                enabled:(BOOL)enabled
                                         preferencesURL:(NSURL*)preferencesURL
                                     createMissingEntry:(BOOL)createMissingEntry {
  NSMutableDictionary* preferences = [self mutableProfilePreferencesDictionaryAtURL:preferencesURL];
  NSMutableDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSMutableDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  if (!extensions) {
    if (!createMissingEntry) {
      return;
    }
    extensions = [NSMutableDictionary dictionary];
    preferences[@"extensions"] = extensions;
  }

  NSMutableDictionary* settings = [extensions[@"settings"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"settings"]
      : nil;
  if (!settings) {
    if (!createMissingEntry) {
      return;
    }
    settings = [NSMutableDictionary dictionary];
    extensions[@"settings"] = settings;
  }

  NSMutableDictionary* extensionSettings =
      [settings[extensionIdentifier] isKindOfClass:NSMutableDictionary.class]
          ? settings[extensionIdentifier]
          : nil;
  if (!extensionSettings) {
    if (!createMissingEntry) {
      return;
    }
    extensionSettings = [NSMutableDictionary dictionary];
    settings[extensionIdentifier] = extensionSettings;
  }

  extensionSettings[@"state"] = enabled ? @1 : @0;
  extensionSettings[@"disable_reasons"] = enabled ? @[] : @[ @1 ];
  [self saveProfilePreferencesDictionary:preferences toURL:preferencesURL];
}

- (void)removeProfileExtensionWithIdentifier:(NSString*)extensionIdentifier {
  if (![self isValidProfileExtensionIdentifier:extensionIdentifier]) {
    return;
  }

  NSURL* extensionDirectoryURL = [self profileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* disabledExtensionDirectoryURL =
      [self disabledProfileExtensionDirectoryURLForIdentifier:extensionIdentifier];
  NSURL* backupExtensionDirectoryURL =
      [self profileExtensionBackupDirectoryURLForIdentifier:extensionIdentifier];
  [NSFileManager.defaultManager removeItemAtURL:extensionDirectoryURL error:nil];
  [NSFileManager.defaultManager removeItemAtURL:disabledExtensionDirectoryURL error:nil];
  [NSFileManager.defaultManager removeItemAtURL:backupExtensionDirectoryURL error:nil];
  [self saveProfileExtensionWithIdentifier:extensionIdentifier disabled:NO];
  [self removeProfileExtensionReferencesWithIdentifier:extensionIdentifier
                                           preferences:[self profilePreferencesFileURL]];
  [self removeProfileExtensionReferencesWithIdentifier:extensionIdentifier
                                           preferences:[self profileSecurePreferencesFileURL]];
}

- (void)removeProfileExtensionReferencesWithIdentifier:(NSString*)extensionIdentifier
                                           preferences:(NSURL*)preferencesURL {
  NSMutableDictionary* preferences = [self mutableProfilePreferencesDictionaryAtURL:preferencesURL];
  if (preferences.count == 0) {
    return;
  }

  NSMutableDictionary* extensions = [preferences[@"extensions"] isKindOfClass:NSMutableDictionary.class]
      ? preferences[@"extensions"]
      : nil;
  NSMutableDictionary* settings = [extensions[@"settings"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"settings"]
      : nil;
  [settings removeObjectForKey:extensionIdentifier];

  NSMutableDictionary* commands = [extensions[@"commands"] isKindOfClass:NSMutableDictionary.class]
      ? extensions[@"commands"]
      : nil;
  for (NSString* commandName in commands.allKeys.copy) {
    NSDictionary* command = [commands[commandName] isKindOfClass:NSDictionary.class]
        ? commands[commandName]
        : nil;
    if ([command[@"extension"] isEqualToString:extensionIdentifier]) {
      [commands removeObjectForKey:commandName];
    }
  }

  NSMutableDictionary* installSignature =
      [extensions[@"install_signature"] isKindOfClass:NSMutableDictionary.class]
          ? extensions[@"install_signature"]
          : nil;
  [self removeProfileExtensionIdentifier:extensionIdentifier
                         fromMutableArray:installSignature[@"ids"]];
  [self removeProfileExtensionIdentifier:extensionIdentifier
                         fromMutableArray:installSignature[@"invalid_ids"]];

  NSMutableDictionary* updateClientData =
      [preferences[@"updateclientdata"] isKindOfClass:NSMutableDictionary.class]
          ? preferences[@"updateclientdata"]
          : nil;
  NSMutableDictionary* updateClientApps =
      [updateClientData[@"apps"] isKindOfClass:NSMutableDictionary.class]
          ? updateClientData[@"apps"]
          : nil;
  [updateClientApps removeObjectForKey:extensionIdentifier];

  [self saveProfilePreferencesDictionary:preferences toURL:preferencesURL];
}

- (void)removeProfileExtensionIdentifier:(NSString*)extensionIdentifier
                        fromMutableArray:(id)mutableArray {
  if (![mutableArray isKindOfClass:NSMutableArray.class]) {
    return;
  }

  [mutableArray removeObject:extensionIdentifier];
}

- (void)saveInstalledExtensionPaths:(NSArray<NSString*>*)extensionPaths {
  [NSUserDefaults.standardUserDefaults setObject:extensionPaths
                                          forKey:BabelChromeConfiguration.extensionPathsDefaultsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
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

  NSMutableArray<NSString*>* extensionPaths = [[self installedExtensionPaths] mutableCopy];
  if (![extensionPaths containsObject:extensionPath]) {
    [extensionPaths addObject:extensionPath];
  }
  [self saveInstalledExtensionPaths:extensionPaths];
}

- (void)removeUnpackedExtensionAtPath:(NSString*)extensionPath {
  NSMutableArray<NSString*>* extensionPaths = [[self installedExtensionPaths] mutableCopy];
  [extensionPaths removeObject:extensionPath];
  [self saveInstalledExtensionPaths:extensionPaths];
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
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)pathEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLPathAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)shellQuotedString:(NSString*)value {
  return [NSString stringWithFormat:@"'%@'",
                                    [value stringByReplacingOccurrencesOfString:@"'"
                                                                     withString:@"'\\''"]];
}

- (NSString*)trashIconHTML {
  return @"<svg class='buttonIcon' viewBox='0 0 24 24' aria-hidden='true'>"
          "<path d='M9 3h6l1 2h4v2H4V5h4l1-2z'/>"
          "<path d='M6 9h12l-1 12H7L6 9zm4 2v8h2v-8h-2zm4 0v8h2v-8h-2z'/>"
          "</svg>";
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  NSString* resourcePath = [NSBundle.mainBundle pathForResource:resourceName ofType:@"svg"];
  if (resourcePath.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSError* error = nil;
  NSString* iconHTML = [NSString stringWithContentsOfFile:resourcePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (error || iconHTML.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSMutableString* normalizedIconHTML = [NSMutableString stringWithString:iconHTML];
  [normalizedIconHTML replaceOccurrencesOfString:@"<svg "
                                      withString:@"<svg class='buttonIcon gearIcon' aria-hidden='true' "
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];
  [normalizedIconHTML replaceOccurrencesOfString:@"fill=\"#17345a\""
                                      withString:@"fill=\"currentColor\""
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];

  return normalizedIconHTML;
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

- (BOOL)internalPagesUseDarkTheme {
  NSString* mode = [BabelTheme.sharedTheme appearanceMode];
  if ([mode isEqualToString:BabelThemeAppearanceDark]) {
    return YES;
  }

  if ([mode isEqualToString:BabelThemeAppearanceLight]) {
    return NO;
  }

  NSAppearanceName name = [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[
    NSAppearanceNameAqua,
    NSAppearanceNameDarkAqua
  ]];
  return [name isEqualToString:NSAppearanceNameDarkAqua];
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
  NSString* bodyClass = [self internalPagesUseDarkTheme] ? @"dark" : @"light";
  return [NSString stringWithFormat:
      @"<!doctype html><html><head><meta charset='utf-8'>"
       "<title>%@</title>"
       "<style>"
       "body{font:14px -apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;margin:0;color:#1f2933;background:#f7f8fa;}"
       "main{max-width:920px;margin:0 auto;padding:34px 42px;}"
       "h1{font-size:30px;margin:0 0 24px;}h2{font-size:16px;margin:28px 0 12px;color:#44515f;}"
       "ul{list-style:none;margin:0;padding:0;border:1px solid #d8dde3;border-radius:8px;background:white;overflow:hidden;}"
       "li{display:grid;grid-template-columns:minmax(160px,1fr) minmax(260px,2fr) minmax(180px,auto);gap:18px;padding:12px 14px;border-top:1px solid #eef1f4;align-items:center;}"
       "li:first-child{border-top:0;}span{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}"
       "small{color:#526171;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}em{color:#7a8794;font-style:normal;text-align:right;}"
       "dl{display:grid;grid-template-columns:180px 1fr;gap:12px 18px;background:white;border:1px solid #d8dde3;border-radius:8px;padding:18px;}"
       "dt{font-weight:700;}dd{margin:0;color:#526171;}"
       ".options{display:grid;grid-template-columns:repeat(2,minmax(180px,1fr));gap:10px;}"
       ".option{display:block;text-decoration:none;color:#243447;border:1px solid #d8dde3;border-radius:8px;padding:12px;background:#f9fafb;cursor:pointer;}"
       ".option strong{display:block;margin-bottom:5px;color:#172533;}.option span{display:block;color:#526171;line-height:1.35;}"
       ".option.selected{border-color:#1473e6;background:#edf5ff;box-shadow:inset 0 0 0 1px #1473e6;}"
       ".stripedList li:nth-child(odd){background:#fff;}.stripedList li:nth-child(even){background:#f3f8ff;}"
       ".primaryButton,.smallButton,button{display:inline-flex;align-items:center;justify-content:center;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;text-decoration:none;font-weight:700;min-height:32px;padding:0 12px;cursor:pointer;}"
       ".primaryButton{background:#1473e6;border-color:#1473e6;color:#fff;}.smallButton{min-height:26px;font-size:12px;}"
       ".primarySmallButton{border-color:#1473e6;background:#1473e6;color:#fff;}"
       ".buttonRow{display:flex;align-items:center;gap:8px;flex-wrap:wrap;}"
       ".gearMenu{position:relative;}.gearMenu summary{display:inline-flex;align-items:center;justify-content:center;width:54px;min-height:38px;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;cursor:pointer;list-style:none;}"
       ".gearMenu summary::-webkit-details-marker{display:none;}.gearMenuPanel{position:absolute;z-index:10;right:0;top:46px;display:grid;gap:8px;min-width:190px;padding:10px;background:#fff;border:1px solid #d8dde3;border-radius:8px;box-shadow:0 10px 28px rgba(20,32,45,.18);}"
       ".updatesForm{display:grid;gap:10px;}.updatesToolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:10px 12px;}"
       ".updatesToolbar label,.updateCheckbox{display:inline-flex;align-items:center;gap:7px;font-weight:700;color:#243447;cursor:pointer;}.updateList input{cursor:pointer;}"
       ".moduleList .moduleItem{grid-template-columns:minmax(0,1fr) 230px;gap:18px;align-items:center;}"
       ".moduleText{min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:5px 14px;align-items:center;}"
       ".moduleText span,.moduleText small{min-width:0;}.moduleText span,.moduleText small{display:block;}.moduleText em{text-align:left;}"
       ".moduleText .note{grid-column:1 / -1;margin:0;}"
       ".moduleButtons{display:grid;grid-template-columns:repeat(2,minmax(92px,1fr));gap:8px;align-content:center;}"
       ".moduleButtonCell{min-height:26px;}.moduleButtonCell .smallButton{width:100%%;box-sizing:border-box;}"
       ".bottomButtonRow{display:flex;justify-content:flex-start;margin-top:14px;}"
       "li>.note{grid-column:1 / 3;margin:0;}"
       "li>.actions{grid-column:3;grid-row:1 / span 2;}"
       ".actions{display:flex;align-items:center;justify-content:flex-end;gap:8px;min-width:0;flex-wrap:wrap;}"
       ".routeList{grid-column:1 / 3;display:flex;align-items:center;gap:7px;flex-wrap:wrap;min-width:0;}"
       ".routeList code{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;background:#f1f5f9;border:1px solid #d8dde3;border-radius:6px;padding:3px 6px;color:#273849;}"
       ".routeList span{color:#7a8794;font-weight:700;}"
       ".dangerButton{border-color:#f0b9b9;color:#8a1f1f;background:#fff8f8;}.iconTextButton{gap:6px;}"
       ".buttonIcon{width:14px;height:14px;fill:currentColor;flex:0 0 auto;}.gearIcon{width:24px;height:24px;}"
       ".searchForm{display:grid;grid-template-columns:minmax(220px,1fr) auto;gap:10px;max-width:620px;}"
       "input{font:inherit;border:1px solid #c7d0db;border-radius:7px;padding:8px 10px;background:#fff;}"
       ".note,.empty{color:#526171;line-height:1.45;}.empty{background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:14px;}"
       "body.dark{color:#e7edf5;background:#15171a;}"
       "body.dark h2{color:#c8d3df;}"
       "body.dark ul,body.dark dl,body.dark .empty{background:#1e2227;border-color:#343b44;}"
       "body.dark li{border-top-color:#2d333b;}"
       "body.dark small,body.dark dd,body.dark .note,body.dark .empty{color:#aeb8c4;}"
       "body.dark em,body.dark .routeList span{color:#8f9ba8;}"
       "body.dark .option{color:#dbe5f0;border-color:#343b44;background:#20252b;}"
       "body.dark .option strong{color:#f4f7fb;}body.dark .option span{color:#aeb8c4;}"
       "body.dark .option.selected{border-color:#5ea1ff;background:#193149;box-shadow:inset 0 0 0 1px #5ea1ff;}"
       "body.dark .stripedList li:nth-child(odd){background:#1e2227;}body.dark .stripedList li:nth-child(even){background:#202a35;}"
       "body.dark .primaryButton,body.dark .smallButton,body.dark button{border-color:#46515d;background:#242a31;color:#f4f7fb;}"
       "body.dark .primaryButton,body.dark .primarySmallButton{background:#2f7de1;border-color:#2f7de1;color:#fff;}"
       "body.dark .gearMenu summary,body.dark .gearMenuPanel,body.dark .updatesToolbar{border-color:#343b44;background:#1e2227;color:#f4f7fb;}"
       "body.dark .gearMenuPanel{box-shadow:0 10px 28px rgba(0,0,0,.32);}body.dark .updatesToolbar label,body.dark .updateCheckbox{color:#dbe5f0;}"
       "body.dark .dangerButton{border-color:#7f3a43;color:#ffb6bf;background:#321d22;}"
       "body.dark input{background:#1e2227;border-color:#46515d;color:#f4f7fb;}"
       "body.dark .routeList code{background:#20252b;border-color:#343b44;color:#dbe5f0;}"
       "</style></head><body class='%@'><main>%@</main>"
       "<script>"
       "document.addEventListener('click',(event)=>{"
       "document.querySelectorAll('.gearMenu[open]').forEach((menu)=>{"
       "if(!menu.contains(event.target)){menu.removeAttribute('open');}"
       "});"
       "});"
       "document.addEventListener('keydown',(event)=>{"
       "if(event.key==='Escape'){document.querySelectorAll('.gearMenu[open]').forEach((menu)=>menu.removeAttribute('open'));}"
       "});"
       "document.addEventListener('contextmenu',(event)=>{"
       "const control=event.target.closest('a.smallButton,a.primaryButton,a.option,button,summary');"
       "if(control&&control.dataset.canOpenMenu!=='true'){event.preventDefault();}"
       "},true);"
       "</script></body></html>",
      [self htmlEscapedString:title],
      bodyClass,
      body ?: @""];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* escapedString = [NSMutableString stringWithString:value ?: @""];
  [escapedString replaceOccurrencesOfString:@"&"
                                 withString:@"&amp;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"<"
                                 withString:@"&lt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@">"
                                 withString:@"&gt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"\""
                                 withString:@"&quot;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  return escapedString;
}
