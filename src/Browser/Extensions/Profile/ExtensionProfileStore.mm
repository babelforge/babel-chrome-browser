#import "Browser/Extensions/Profile/ExtensionProfileStore.h"

@implementation BabelExtensionProfileStore {
  NSURL* profileDirectoryURL_;
  NSURL* profileExtensionBackupDirectoryURL_;
  NSUserDefaults* userDefaults_;
  NSString* extensionPathsDefaultsKey_;
  NSString* disabledProfileExtensionIdentifiersDefaultsKey_;
  NSString* pendingProfileExtensionRestartStatesDefaultsKey_;
}

- (instancetype)initWithProfileDirectoryURL:(NSURL*)profileDirectoryURL
         profileExtensionBackupDirectoryURL:(NSURL*)profileExtensionBackupDirectoryURL
                               userDefaults:(NSUserDefaults*)userDefaults
                  extensionPathsDefaultsKey:(NSString*)extensionPathsDefaultsKey
disabledProfileExtensionIdentifiersDefaultsKey:(NSString*)disabledProfileExtensionIdentifiersDefaultsKey
pendingProfileExtensionRestartStatesDefaultsKey:(NSString*)pendingProfileExtensionRestartStatesDefaultsKey {
  self = [super init];
  if (self) {
    profileDirectoryURL_ = profileDirectoryURL;
    profileExtensionBackupDirectoryURL_ = profileExtensionBackupDirectoryURL;
    userDefaults_ = userDefaults;
    extensionPathsDefaultsKey_ = extensionPathsDefaultsKey;
    disabledProfileExtensionIdentifiersDefaultsKey_ =
        disabledProfileExtensionIdentifiersDefaultsKey;
    pendingProfileExtensionRestartStatesDefaultsKey_ =
        pendingProfileExtensionRestartStatesDefaultsKey;
  }
  return self;
}

- (NSArray<NSString*>*)installedExtensionPaths {
  NSArray* extensionPaths = [userDefaults_ arrayForKey:extensionPathsDefaultsKey_];
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

- (void)saveInstalledExtensionPaths:(NSArray<NSString*>*)extensionPaths {
  [userDefaults_ setObject:extensionPaths forKey:extensionPathsDefaultsKey_];
  [userDefaults_ synchronize];
}

- (NSArray<NSDictionary*>*)profileInstalledExtensions {
  NSURL* extensionsDirectoryURL = [[self defaultProfileDirectoryURL]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES];
  NSMutableDictionary<NSString*, NSDictionary*>* extensionsByIdentifier =
      [NSMutableDictionary dictionary];
  [self collectProfileExtensionsFromDirectory:extensionsDirectoryURL
                                      enabled:YES
                       extensionsByIdentifier:extensionsByIdentifier];
  [self collectProfileExtensionsFromDirectory:profileExtensionBackupDirectoryURL_
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
  NSMutableArray<NSDictionary*>* extensions =
      [NSMutableArray arrayWithArray:extensionsByIdentifier.allValues];
  [extensions sortUsingDescriptors:@[
    [NSSortDescriptor sortDescriptorWithKey:@"name"
                                  ascending:YES
                                   selector:@selector(localizedCaseInsensitiveCompare:)]
  ]];
  return extensions;
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

- (void)clearPendingProfileExtensionRestartStates {
  [userDefaults_ removeObjectForKey:pendingProfileExtensionRestartStatesDefaultsKey_];
  [userDefaults_ synchronize];
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

- (NSURL*)defaultProfileDirectoryURL {
  return [profileDirectoryURL_ URLByAppendingPathComponent:@"Default" isDirectory:YES];
}

- (NSURL*)profilePreferencesFileURL {
  return [[self defaultProfileDirectoryURL] URLByAppendingPathComponent:@"Preferences"
                                                            isDirectory:NO];
}

- (NSURL*)profileSecurePreferencesFileURL {
  return [[self defaultProfileDirectoryURL] URLByAppendingPathComponent:@"Secure Preferences"
                                                            isDirectory:NO];
}

- (NSURL*)profileExtensionDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [[[self defaultProfileDirectoryURL] URLByAppendingPathComponent:@"Extensions"
                                                             isDirectory:YES]
      URLByAppendingPathComponent:extensionIdentifier isDirectory:YES];
}

- (NSURL*)profileExtensionBackupDirectoryURLForIdentifier:(NSString*)extensionIdentifier {
  return [profileExtensionBackupDirectoryURL_ URLByAppendingPathComponent:extensionIdentifier
                                                              isDirectory:YES];
}

- (NSURL*)disabledProfileExtensionsDirectoryURL {
  return [[self defaultProfileDirectoryURL] URLByAppendingPathComponent:@"Disabled Extensions"
                                                            isDirectory:YES];
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
  NSArray* identifiers = [userDefaults_ arrayForKey:disabledProfileExtensionIdentifiersDefaultsKey_];
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

  [userDefaults_ setObject:identifiers forKey:disabledProfileExtensionIdentifiersDefaultsKey_];
  [userDefaults_ synchronize];
}

- (NSDictionary*)pendingProfileExtensionRestartStates {
  NSDictionary* states =
      [userDefaults_ dictionaryForKey:pendingProfileExtensionRestartStatesDefaultsKey_];
  return [states isKindOfClass:NSDictionary.class] ? states : @{};
}

- (void)savePendingProfileExtensionRestartStateForIdentifier:(NSString*)extensionIdentifier
                                                    enabled:(BOOL)enabled {
  NSMutableDictionary* states = [[self pendingProfileExtensionRestartStates] mutableCopy];
  states[extensionIdentifier] = enabled ? @"enable" : @"disable";
  [userDefaults_ setObject:states forKey:pendingProfileExtensionRestartStatesDefaultsKey_];
  [userDefaults_ synchronize];
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

@end
