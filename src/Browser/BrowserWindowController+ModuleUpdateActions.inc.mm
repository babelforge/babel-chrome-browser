// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
