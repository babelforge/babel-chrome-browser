#import "Browser/ExtensionsPageDataSource.h"

#import "Browser/ExtensionProfileStore.h"
#import "Browser/ExtensionsPageRenderer.h"

@implementation BabelExtensionsPageDataSource {
  BabelExtensionProfileStore* extensionProfileStore_;
}

- (instancetype)initWithExtensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore {
  self = [super init];
  if (self) {
    extensionProfileStore_ = extensionProfileStore;
  }
  return self;
}

- (NSArray<NSDictionary*>*)profileExtensionRows {
  NSArray<NSDictionary*>* profileExtensions = [extensionProfileStore_ profileInstalledExtensions];
  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  for (NSDictionary* extension in profileExtensions ?: @[]) {
    NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
        ? extension[@"id"]
        : @"";
    BOOL enabled = [extension[@"enabled"] boolValue];
    NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
    NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
    NSString* status = [extensionProfileStore_ profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                                enabled:enabled];
    [rows addObject:@{
      BabelExtensionProfileNameKey : [extension[@"name"] isKindOfClass:NSString.class] ? extension[@"name"] : @"",
      BabelExtensionProfileIdentifierKey : extensionIdentifier ?: @"",
      BabelExtensionProfileVersionKey : [extension[@"version"] isKindOfClass:NSString.class] ? extension[@"version"] : @"",
      BabelExtensionProfilePathKey : [extension[@"path"] isKindOfClass:NSString.class] ? extension[@"path"] : @"",
      BabelExtensionProfileStatusKey : status ?: @"",
      BabelExtensionProfileToggleActionKey : toggleAction,
      BabelExtensionProfileToggleLabelKey : toggleLabel,
      BabelExtensionProfileRequiresRestartKey : @([extensionProfileStore_ profileExtensionRequiresRestart:extensionIdentifier]),
    }];
  }
  return rows;
}

- (NSArray<NSDictionary*>*)unpackedExtensionRows {
  NSArray<NSString*>* extensionPaths = [extensionProfileStore_ installedExtensionPaths];
  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  for (NSString* extensionPath in extensionPaths ?: @[]) {
    NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
    BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
    NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
    [rows addObject:@{
      BabelUnpackedExtensionNameKey : extensionPath.lastPathComponent ?: @"",
      BabelUnpackedExtensionPathKey : extensionPath ?: @"",
      BabelUnpackedExtensionStatusKey : [NSString stringWithFormat:@"%@ - %@", status, extensionPath ?: @""],
    }];
  }
  return rows;
}

@end
