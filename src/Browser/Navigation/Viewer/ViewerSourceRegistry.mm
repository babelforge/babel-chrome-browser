#import "Browser/Navigation/Viewer/ViewerSourceRegistry.h"

static NSString* const kBabelViewerSourceRegistryErrorDomain =
    @"fr.babelforge.babel-chrome.viewer-source-registry";

@implementation BabelViewerSourceRegistry {
  NSString* stateDirectoryPath_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    stateDirectoryPath_ = [[self class] defaultStateDirectoryPath];
  }

  return self;
}

- (NSString*)stateDirectoryPath {
  [NSFileManager.defaultManager createDirectoryAtPath:stateDirectoryPath_
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];

  return stateDirectoryPath_;
}

- (NSString*)registerSourceWithType:(NSString*)type
                               value:(NSString*)value
                               error:(NSError**)error {
  NSString* normalizedType =
      [type stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString* normalizedValue =
      [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (normalizedType.length == 0 || normalizedValue.length == 0) {
    [self assignError:error description:@"Viewer source type and value are required."];
    return nil;
  }

  NSMutableDictionary* registry = [[self readRegistry] mutableCopy];
  NSString* identifier = [NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
  registry[identifier] = @{
    @"type" : normalizedType,
    @"value" : normalizedValue,
    @"createdAt" : @((NSInteger)NSDate.date.timeIntervalSince1970)
  };

  if (![self writeRegistry:registry error:error]) {
    return nil;
  }

  return identifier;
}

- (NSDictionary*)sourceWithIdentifier:(NSString*)sourceIdentifier {
  NSString* identifier =
      [sourceIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (identifier.length == 0) {
    return nil;
  }

  NSDictionary* registry = [self readRegistry];
  NSDictionary* entry = [registry[identifier] isKindOfClass:NSDictionary.class] ? registry[identifier] : nil;
  NSString* type = [entry[@"type"] isKindOfClass:NSString.class] ? entry[@"type"] : @"";
  NSString* value = [entry[@"value"] isKindOfClass:NSString.class] ? entry[@"value"] : @"";
  if (type.length == 0 || value.length == 0) {
    return nil;
  }

  return @{
    @"type" : type,
    @"value" : value
  };
}

+ (NSString*)defaultStateDirectoryPath {
  NSArray<NSURL*>* applicationSupportURLs =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask];
  NSURL* applicationSupportURL = applicationSupportURLs.firstObject;
  if (!applicationSupportURL) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"BabelChrome/NativeModuleHost"];
  }

  return [[applicationSupportURL URLByAppendingPathComponent:@"BabelForge/BabelChrome/NativeModuleHost"
                                                 isDirectory:YES] path];
}

- (NSString*)registryPath {
  return [[self stateDirectoryPath] stringByAppendingPathComponent:@"sources.json"];
}

- (NSDictionary*)readRegistry {
  NSString* path = [self registryPath];
  NSData* data = [NSData dataWithContentsOfFile:path];
  if (data.length == 0) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    return @{};
  }

  NSMutableDictionary* registry = [NSMutableDictionary dictionary];
  for (id key in (NSDictionary*)decoded) {
    id value = ((NSDictionary*)decoded)[key];
    if (![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* type = [value[@"type"] isKindOfClass:NSString.class] ? value[@"type"] : @"";
    NSString* sourceValue = [value[@"value"] isKindOfClass:NSString.class] ? value[@"value"] : @"";
    if (type.length == 0 || sourceValue.length == 0) {
      continue;
    }

    NSMutableDictionary* entry = [@{
      @"type" : type,
      @"value" : sourceValue
    } mutableCopy];
    if ([value[@"createdAt"] isKindOfClass:NSNumber.class]) {
      entry[@"createdAt"] = value[@"createdAt"];
    }
    registry[key] = entry;
  }

  return registry;
}

- (BOOL)writeRegistry:(NSDictionary*)registry error:(NSError**)error {
  NSData* data = [NSJSONSerialization dataWithJSONObject:registry ?: @{}
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:error];
  if (!data) {
    return NO;
  }

  if (![data writeToFile:[self registryPath] options:NSDataWritingAtomic error:error]) {
    return NO;
  }

  return YES;
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelViewerSourceRegistryErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Viewer source registry failed."}];
}

@end
