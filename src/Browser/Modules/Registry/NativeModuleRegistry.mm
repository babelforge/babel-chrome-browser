#import "Browser/Modules/Registry/NativeModuleRegistry.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"

static NSString* const kBabelNativeModuleRegistryErrorDomain = @"fr.babelforge.babel-chrome.native-module-registry";

@implementation BabelNativeModuleRegistry {
  NSString* modulesDirectoryPath_;
  NSArray<BabelNativeModuleManifest*>* cachedModules_;
}

- (instancetype)init {
  return [self initWithModulesDirectoryPath:nil];
}

- (instancetype)initWithModulesDirectoryPath:(NSString*)modulesDirectoryPath {
  self = [super init];
  if (self) {
    modulesDirectoryPath_ = modulesDirectoryPath.length > 0 ? [modulesDirectoryPath copy] : [[self class] defaultModulesDirectoryPath];
  }

  return self;
}

- (NSString*)modulesDirectoryPath {
  return modulesDirectoryPath_;
}

- (void)reload {
  cachedModules_ = nil;
}

- (NSArray<BabelNativeModuleManifest*>*)allModulesWithError:(NSError**)error {
  if (cachedModules_) {
    return cachedModules_;
  }

  NSArray<NSString*>* manifestPaths = [self manifestPathsWithError:error];
  if (!manifestPaths) {
    return nil;
  }

  NSMutableArray<BabelNativeModuleManifest*>* modules = [NSMutableArray array];
  for (NSString* manifestPath in manifestPaths) {
    NSString* modulePath = [manifestPath stringByDeletingLastPathComponent];
    NSData* data = [NSData dataWithContentsOfFile:manifestPath options:0 error:error];
    if (!data) {
      return nil;
    }

    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![decoded isKindOfClass:NSDictionary.class]) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module manifest is not a JSON object: %@", manifestPath]];
      return nil;
    }

    BabelNativeModuleManifest* manifest =
        [BabelNativeModuleManifest manifestWithDictionary:decoded modulePath:modulePath error:error];
    if (!manifest) {
      return nil;
    }

    [modules addObject:manifest];
  }

  cachedModules_ = [modules sortedArrayUsingComparator:^NSComparisonResult(BabelNativeModuleManifest* left,
                                                                           BabelNativeModuleManifest* right) {
    return [left.moduleIdentifier compare:right.moduleIdentifier];
  }];

  return cachedModules_;
}

- (NSArray<BabelNativeModuleManifest*>*)enabledModulesWithError:(NSError**)error {
  NSArray<BabelNativeModuleManifest*>* modules = [self allModulesWithError:error];
  if (!modules) {
    return nil;
  }

  NSMutableArray<BabelNativeModuleManifest*>* enabledModules = [NSMutableArray array];
  for (BabelNativeModuleManifest* module in modules) {
    if (module.enabled) {
      [enabledModules addObject:module];
    }
  }

  return enabledModules;
}

- (BabelNativeModuleManifest*)moduleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  if (moduleIdentifier.length == 0) {
    return nil;
  }

  NSArray<BabelNativeModuleManifest*>* modules = [self allModulesWithError:error];
  if (!modules) {
    return nil;
  }

  for (BabelNativeModuleManifest* module in modules) {
    if ([module.moduleIdentifier isEqualToString:moduleIdentifier]) {
      return module;
    }
  }

  return nil;
}

- (NSDictionary*)modulesSnapshotWithError:(NSError**)error {
  NSArray<BabelNativeModuleManifest*>* modules = [self allModulesWithError:error];
  if (!modules) {
    return nil;
  }

  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  for (BabelNativeModuleManifest* module in modules) {
    [rows addObject:[module dictionaryRepresentation]];
  }

  return @{
    @"modules" : rows,
    @"source" : @"native"
  };
}

- (NSString*)fileTypeHeaderValueWithError:(NSError**)error {
  NSArray<BabelNativeModuleManifest*>* modules = [self enabledModulesWithError:error];
  if (!modules) {
    return @"";
  }

  NSMutableOrderedSet<NSString*>* fileTypes = [NSMutableOrderedSet orderedSet];
  for (BabelNativeModuleManifest* module in modules) {
    for (NSString* fileType in module.fileTypeHandlerFileTypes) {
      if (fileType.length > 0) {
        [fileTypes addObject:fileType];
      }
    }
  }

  return [[fileTypes array] componentsJoinedByString:@","];
}

- (NSDictionary*)viewerRouteForURL:(NSURL*)url error:(NSError**)error {
  return [self viewerRouteForURL:url preferredViewerKind:nil error:error];
}

- (NSDictionary*)viewerRouteForURL:(NSURL*)url
               preferredViewerKind:(NSString*)preferredViewerKind
                              error:(NSError**)error {
  BabelNativeModuleManifest* module = [self viewerModuleForURL:url
                                           preferredViewerKind:preferredViewerKind
                                                        error:error];
  if (!module) {
    return nil;
  }

  NSDictionary* route = [self firstBabelChromeRouteForModule:module];
  NSString* host = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
  NSString* handler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
  if (host.length == 0 || handler.length == 0) {
    return nil;
  }

  return @{
    @"handled" : @YES,
    @"moduleId" : module.moduleIdentifier,
    @"moduleIdentifier" : module.moduleIdentifier,
    @"viewerKind" : host,
    @"route" : [NSString stringWithFormat:@"/module/%@/%@", module.moduleIdentifier, handler],
    @"handler" : handler
  };
}

- (NSDictionary*)addressBadgeForViewerURL:(NSURL*)url error:(NSError**)error {
  BabelNativeModuleManifest* module = [self viewerModuleForURL:url error:error];
  if (!module || module.badge.count == 0) {
    return nil;
  }

  NSMutableDictionary* badge = [module.badge mutableCopy];
  if (module.settingsRoute.length > 0) {
    badge[@"settingsRoute"] = module.settingsRoute;
  }

  return badge;
}

- (NSArray<NSString*>*)manifestPathsWithError:(NSError**)error {
  NSFileManager* fileManager = NSFileManager.defaultManager;
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:modulesDirectoryPath_ isDirectory:&isDirectory]) {
    return @[];
  }

  if (!isDirectory) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Modules path is not a directory: %@", modulesDirectoryPath_]];
    return nil;
  }

  NSArray<NSString*>* children = [fileManager contentsOfDirectoryAtPath:modulesDirectoryPath_ error:error];
  if (!children) {
    return nil;
  }

  NSMutableArray<NSString*>* manifestPaths = [NSMutableArray array];
  for (NSString* child in children) {
    if ([child containsString:@".backup"]) {
      continue;
    }

    NSString* manifestPath = [[modulesDirectoryPath_ stringByAppendingPathComponent:child]
        stringByAppendingPathComponent:@"manifest.json"];
    BOOL manifestIsDirectory = NO;
    if ([fileManager fileExistsAtPath:manifestPath isDirectory:&manifestIsDirectory] && !manifestIsDirectory) {
      [manifestPaths addObject:manifestPath];
    }
  }

  return [manifestPaths sortedArrayUsingSelector:@selector(compare:)];
}

- (BabelNativeModuleManifest*)viewerModuleForURL:(NSURL*)url
                             preferredViewerKind:(NSString*)preferredViewerKind
                                          error:(NSError**)error {
  if (![self canResolveViewerURL:url]) {
    return nil;
  }

  NSArray<BabelNativeModuleManifest*>* modules = [self enabledModulesWithError:error];
  if (!modules) {
    return nil;
  }

  BabelNativeModuleManifest* bestModule = nil;
  NSInteger bestScore = 0;
  for (BabelNativeModuleManifest* module in modules) {
    if (![self module:module matchesPreferredViewerKind:preferredViewerKind]) {
      continue;
    }

    NSInteger score = [self viewerScoreForModule:module URL:url];
    if (score > bestScore) {
      bestScore = score;
      bestModule = module;
    }
  }

  return bestModule;
}

- (BabelNativeModuleManifest*)viewerModuleForURL:(NSURL*)url error:(NSError**)error {
  return [self viewerModuleForURL:url preferredViewerKind:nil error:error];
}

- (BOOL)module:(BabelNativeModuleManifest*)module matchesPreferredViewerKind:(NSString*)preferredViewerKind {
  NSString* normalizedViewerKind =
      [preferredViewerKind stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (normalizedViewerKind.length == 0 || [normalizedViewerKind isEqualToString:@"viewer"]) {
    return YES;
  }

  NSDictionary* route = [self firstBabelChromeRouteForModule:module];
  NSString* host = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
  return [host isEqualToString:normalizedViewerKind];
}

- (BOOL)canResolveViewerURL:(NSURL*)url {
  NSString* scheme = url.scheme.lowercaseString ?: @"";
  return [scheme isEqualToString:@"file"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

- (NSInteger)viewerScoreForModule:(BabelNativeModuleManifest*)module URL:(NSURL*)url {
  NSDictionary* route = [self firstBabelChromeRouteForModule:module];
  if (!route) {
    return 0;
  }

  NSString* extension = url.pathExtension.lowercaseString ?: @"";
  NSString* path = url.path.lowercaseString ?: @"";
  NSInteger score = 0;

  if ([self stringList:module.fileTypeHandlerFileTypes containsString:extension]) {
    score += 50;
  } else if ([self stringList:module.fileTypes containsString:extension]) {
    score += 40;
  }

  BOOL fileNameContainsMatched = [self fileNameContainsForModule:module matchesPath:path];
  if (fileNameContainsMatched) {
    score += 25;
  }

  if ([module.moduleType isEqualToString:@"viewer"]) {
    score += 5;
  }

  if (score <= 5 && !fileNameContainsMatched) {
    return 0;
  }

  return score;
}

- (NSDictionary*)firstBabelChromeRouteForModule:(BabelNativeModuleManifest*)module {
  for (NSDictionary* route in module.routes) {
    NSString* scheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
    NSString* host = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
    NSString* handler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
    if ([scheme isEqualToString:@"babelchrome"] && host.length > 0 && handler.length > 0) {
      return route;
    }
  }

  return nil;
}

- (BOOL)fileNameContainsForModule:(BabelNativeModuleManifest*)module matchesPath:(NSString*)path {
  for (NSString* token in module.fileNameContains) {
    if (token.length > 0 && [path rangeOfString:token].location != NSNotFound) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)stringList:(NSArray<NSString*>*)strings containsString:(NSString*)candidate {
  if (candidate.length == 0) {
    return NO;
  }

  for (NSString* string in strings) {
    if ([string isEqualToString:candidate]) {
      return YES;
    }
  }

  return NO;
}

+ (NSString*)defaultModulesDirectoryPath {
  NSArray<NSURL*>* applicationSupportURLs =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
  NSURL* applicationSupportURL = applicationSupportURLs.firstObject;
  if (!applicationSupportURL) {
    applicationSupportURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
  }

  return [[[[applicationSupportURL URLByAppendingPathComponent:@"BabelForge" isDirectory:YES]
      URLByAppendingPathComponent:@"BabelChrome" isDirectory:YES]
      URLByAppendingPathComponent:@"Modules" isDirectory:YES] path];
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleRegistryErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Unable to load native module registry."}];
}

@end
