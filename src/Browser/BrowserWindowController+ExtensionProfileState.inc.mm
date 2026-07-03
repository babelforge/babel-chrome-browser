// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
