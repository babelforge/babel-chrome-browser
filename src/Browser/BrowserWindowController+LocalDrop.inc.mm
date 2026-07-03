// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths {
  [self appendLocalDropLogLine:[NSString stringWithFormat:@"CEF drag enter paths=%@", paths ?: @[]]];
  if (!browser || paths.count == 0) {
    return;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  BOOL browserURLSupportsDrop = [self URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  if (!tab && selectedTab_ && [self tabSupportsLocalDropPaths:selectedTab_]) {
    tab = selectedTab_;
    [self appendLocalDropLogLine:[NSString stringWithFormat:
        @"CEF drag enter used selected tab fallback requestedURL=%@",
        tab.requestedURLString ?: tab.urlString ?: @""]];
  }
  if ((!tab || ![self tabSupportsLocalDropPaths:tab]) && !browserURLSupportsDrop) {
    [self appendLocalDropLogLine:@"CEF drag enter ignored because no drop-aware tab was found."];
    return;
  }

  [self markPendingLocalDropForBrowser:browser];

  NSString* payloadJSON = [localDropPayloadBuilder_ payloadJSONForLocalPaths:paths];
  if (payloadJSON.length == 0) {
    return;
  }

  [self installLocalDropBridgeForBrowser:browser payloadJSON:payloadJSON];
}

- (BOOL)pageContainerSupportsLocalDrop:(BabelPageContainerView*)container {
  if (!container) {
    return NO;
  }

  for (BabelBrowserTab* tab in tabs_) {
    if (tab.hostView == container) {
      BOOL supported = [self tabSupportsLocalDropPaths:tab];
      [self appendLocalDropLogLine:[NSString stringWithFormat:
          @"AppKit drag probe tab=%@ requestedURL=%@ supported=%@",
          tab.identifier ?: @"",
          tab.requestedURLString ?: tab.urlString ?: @"",
          supported ? @"YES" : @"NO"]];
      return supported;
    }
  }

  [self appendLocalDropLogLine:@"AppKit drag probe had no matching tab."];
  return NO;
}

- (void)pageContainerDidReceiveLocalDrop:(BabelPageContainerView*)container {
  NSArray<NSString*>* paths = [container localDropPaths];
  [self appendLocalDropLogLine:[NSString stringWithFormat:@"AppKit drop accepted paths=%@", paths ?: @[]]];
  [self browser:[container browser] didReceiveLocalDragPaths:paths];
}

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![self tabSupportsLocalDropPaths:tab]) {
    if (tab) {
      [self appendLocalDropLogLine:[NSString stringWithFormat:
          @"Load end did not install local drop bridge for requestedURL=%@",
          tab.requestedURLString ?: tab.urlString ?: @""]];
    }
    return;
  }

  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"Load end installing local drop bridge for requestedURL=%@",
      tab.requestedURLString ?: tab.urlString ?: @""]];
  [self installLocalDropBridgeForBrowser:browser payloadJSON:nil];
}

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return NO;
  }

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  BOOL tabSupportsDrop = tab && [self tabSupportsLocalDropPaths:tab];
  BOOL browserHasPendingDrop = [self hasPendingLocalDropForBrowser:browser];
  BOOL selectedTabSupportsDrop = selectedTab_ && [self tabSupportsLocalDropPaths:selectedTab_];
  BOOL currentURLSupportsDrop = [self URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  BOOL shouldSuppress = tabSupportsDrop || browserHasPendingDrop || selectedTabSupportsDrop || currentURLSupportsDrop;
  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"CEF file navigation suppression requestedURL=%@ tabSupports=%@ pendingDrop=%@ selectedSupports=%@ currentSupports=%@ suppress=%@",
      tab.requestedURLString ?: tab.urlString ?: @"",
      tabSupportsDrop ? @"YES" : @"NO",
      browserHasPendingDrop ? @"YES" : @"NO",
      selectedTabSupportsDrop ? @"YES" : @"NO",
      currentURLSupportsDrop ? @"YES" : @"NO",
      shouldSuppress ? @"YES" : @"NO"]];
  if (shouldSuppress) {
    [self clearPendingLocalDropForBrowser:browser];
  }
  return shouldSuppress;
}

- (void)installLocalDropBridgeForBrowser:(CefRefPtr<CefBrowser>)browser payloadJSON:(NSString*)payloadJSON {
  if (!browser) {
    return;
  }

  NSString* script = [localDropBridgeScriptBuilder_ scriptWithPayloadJSON:payloadJSON];
  browser->GetMainFrame()->ExecuteJavaScript(std::string(script.UTF8String),
                                             "babelchrome://local-drop-bridge",
                                             0);
}

- (void)appendLocalDropLogLine:(NSString*)line {
  [localDropLogWriter_ appendLine:line];
}

- (NSNumber*)browserIdentifierForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return nil;
  }

  return @(browser->GetIdentifier());
}

- (NSString*)currentURLStringForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser || !browser->GetMainFrame()) {
    return @"";
  }

  return [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];
}

- (void)markPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return;
  }

  [localDropCoordinator_ markPendingLocalDropForBrowserIdentifier:browserIdentifier];
  [self appendLocalDropLogLine:[NSString stringWithFormat:
      @"Marked pending local drop for browser=%@",
      browserIdentifier]];
}

- (BOOL)hasPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return NO;
  }

  return [localDropCoordinator_ hasPendingLocalDropForBrowserIdentifier:browserIdentifier];
}

- (void)clearPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  [localDropCoordinator_ clearPendingLocalDropForBrowserIdentifier:browserIdentifier];
}

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab {
  if (!tab) {
    return NO;
  }

  if ([self URLStringSupportsLocalDropPaths:tab.requestedURLString]) {
    return YES;
  }

  return [self URLStringSupportsLocalDropPaths:tab.urlString];
}

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString {
  if (urlString.length == 0) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (!components) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (!snapshot || error) {
    return NO;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme.lowercaseString ?: @"";
  NSString* host = components.host.lowercaseString ?: @"";
  NSString* localModuleIdentifier = [moduleActionService_ localServiceModuleIdentifierForURLComponents:components];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSArray* hooks = [module[@"hooks"] isKindOfClass:NSArray.class] ? module[@"hooks"] : @[];
    if (![hooks containsObject:@"drop.local-paths"]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (localModuleIdentifier.length > 0 && [moduleIdentifier isEqualToString:localModuleIdentifier]) {
      return YES;
    }

    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      if ([routeScheme.lowercaseString isEqualToString:scheme] && [routeHost.lowercaseString isEqualToString:host]) {
        return YES;
      }
    }
  }

  return NO;
}
