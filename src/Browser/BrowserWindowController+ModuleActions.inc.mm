// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
