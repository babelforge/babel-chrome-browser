#import "Startup/ProfileExtensionStartupSynchronizer.h"

#import "Configuration/Configuration.h"

@implementation BabelProfileExtensionStartupSynchronizer

+ (void)applyProfileExtensionPackageState {
  NSURL* backupDirectoryURL = BabelChromeConfiguration.profileExtensionBackupDirectoryURL;
  NSURL* extensionsDirectoryURL = [[BabelChromeConfiguration.profileDirectoryURL
      URLByAppendingPathComponent:@"Default" isDirectory:YES]
      URLByAppendingPathComponent:@"Extensions" isDirectory:YES];
  NSArray<NSString*>* disabledIdentifiers = [self disabledProfileExtensionIdentifiers];

  NSArray<NSURL*>* backupURLs =
      [NSFileManager.defaultManager contentsOfDirectoryAtURL:backupDirectoryURL
                                  includingPropertiesForKeys:nil
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
  for (NSURL* backupURL in backupURLs) {
    NSString* extensionIdentifier = backupURL.lastPathComponent;
    if (![self isValidProfileExtensionIdentifier:extensionIdentifier] ||
        [disabledIdentifiers containsObject:extensionIdentifier]) {
      continue;
    }

    NSURL* activeExtensionURL = [extensionsDirectoryURL URLByAppendingPathComponent:extensionIdentifier
                                                                        isDirectory:YES];
    if ([NSFileManager.defaultManager fileExistsAtPath:activeExtensionURL.path]) {
      continue;
    }

    [self copyProfileExtensionPackageFromURL:backupURL toURL:activeExtensionURL];
  }

  NSArray<NSURL*>* activeURLs =
      [NSFileManager.defaultManager contentsOfDirectoryAtURL:extensionsDirectoryURL
                                  includingPropertiesForKeys:nil
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
  for (NSURL* activeURL in activeURLs) {
    NSString* extensionIdentifier = activeURL.lastPathComponent;
    if (![self isValidProfileExtensionIdentifier:extensionIdentifier] ||
        ![disabledIdentifiers containsObject:extensionIdentifier]) {
      continue;
    }

    NSURL* backupURL = [backupDirectoryURL URLByAppendingPathComponent:extensionIdentifier
                                                           isDirectory:YES];
    [self copyProfileExtensionPackageFromURL:activeURL toURL:backupURL];
    [NSFileManager.defaultManager removeItemAtURL:activeURL error:nil];
  }
}

+ (NSArray<NSString*>*)disabledProfileExtensionIdentifiers {
  NSArray* disabledIdentifiers = [NSUserDefaults.standardUserDefaults
      arrayForKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey];
  if (![disabledIdentifiers isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* validIdentifiers = [NSMutableArray array];
  for (NSString* disabledIdentifier in disabledIdentifiers) {
    if ([disabledIdentifier isKindOfClass:NSString.class] &&
        [self isValidProfileExtensionIdentifier:disabledIdentifier]) {
      [validIdentifiers addObject:disabledIdentifier];
    }
  }
  return validIdentifiers;
}

+ (BOOL)isValidProfileExtensionIdentifier:(NSString*)extensionIdentifier {
  if (extensionIdentifier.length == 0) {
    return NO;
  }

  NSCharacterSet* invalidCharacters =
      [[NSCharacterSet alphanumericCharacterSet] invertedSet];
  return [extensionIdentifier rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound;
}

+ (void)copyProfileExtensionPackageFromURL:(NSURL*)sourceURL toURL:(NSURL*)destinationURL {
  [NSFileManager.defaultManager createDirectoryAtURL:[destinationURL URLByDeletingLastPathComponent]
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  [NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil];
  [NSFileManager.defaultManager copyItemAtURL:sourceURL
                                        toURL:destinationURL
                                        error:nil];
}

@end
