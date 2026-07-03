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
