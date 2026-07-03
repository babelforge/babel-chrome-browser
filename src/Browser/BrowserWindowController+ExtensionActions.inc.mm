// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
