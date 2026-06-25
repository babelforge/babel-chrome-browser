#import "Configuration/Configuration.h"

@implementation BabelChromeConfiguration

+ (NSString*)applicationName {
  return @"BabelChrome";
}

+ (NSURL*)profileDirectoryURL {
  return [[self applicationSupportDirectoryURL] URLByAppendingPathComponent:@"Profile"
                                                                isDirectory:YES];
}

+ (NSURL*)diskCacheRootDirectoryURL {
  return [self profileDirectoryURL];
}

+ (NSString*)httpDiskCacheSizeBytes {
  return @"536870912";
}

+ (NSString*)mediaDiskCacheSizeBytes {
  return @"268435456";
}

+ (NSURL*)profileExtensionBackupDirectoryURL {
  return [[self applicationSupportDirectoryURL] URLByAppendingPathComponent:@"Profile Extension Backups"
                                                                isDirectory:YES];
}

+ (NSURL*)groupsStateFileURL {
  return [[self applicationSupportDirectoryURL] URLByAppendingPathComponent:@"groups.json"
                                                                isDirectory:NO];
}

+ (NSURL*)faviconStoreFileURL {
  return [[self applicationSupportDirectoryURL] URLByAppendingPathComponent:@"favicons.json"
                                                                isDirectory:NO];
}

+ (NSURL*)applicationSupportDirectoryURL {
  NSFileManager* fileManager = NSFileManager.defaultManager;
  NSURL* applicationSupportURL =
      [fileManager URLForDirectory:NSApplicationSupportDirectory
                           inDomain:NSUserDomainMask
                  appropriateForURL:nil
                             create:YES
                              error:nil];
  return [applicationSupportURL URLByAppendingPathComponent:@"BabelForge/BabelChrome"
                                                isDirectory:YES];
}

+ (NSString*)defaultURLString {
  return @"https://www.google.fr";
}

+ (int)remoteDebuggingPort {
  return 9223;
}

+ (NSString*)extensionPathsDefaultsKey {
  return @"InstalledExtensionPaths";
}

+ (NSString*)disabledProfileExtensionIdentifiersDefaultsKey {
  return @"DisabledProfileExtensionIdentifiers";
}

+ (NSString*)pendingProfileExtensionRestartStatesDefaultsKey {
  return @"PendingProfileExtensionRestartStates";
}

@end
