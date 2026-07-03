// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
        [extensionProfileStore_ setProfileExtensionWithIdentifier:item.value enabled:NO];
        [self openExtensionsPageForBrowser:browser];
        return YES;
      }

      if ([item.name isEqualToString:@"enableProfile"] && item.value.length > 0) {
        [extensionProfileStore_ setProfileExtensionWithIdentifier:item.value enabled:YES];
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
