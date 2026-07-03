// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
