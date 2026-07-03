// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
