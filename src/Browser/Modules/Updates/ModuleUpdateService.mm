#import "Browser/Modules/Updates/ModuleUpdateService.h"

#include <cmath>

@implementation BabelModuleUpdateService {
  NSUserDefaults* userDefaults_;
  NSString* updateURLDefaultsKey_;
  NSString* updateLocalDirectoryDefaultsKey_;
  NSString* localIndexFilePath_;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults
                 updateURLDefaultsKey:(NSString*)updateURLDefaultsKey
       updateLocalDirectoryDefaultsKey:(NSString*)updateLocalDirectoryDefaultsKey
                    localIndexFilePath:(NSString*)localIndexFilePath {
  self = [super init];
  if (self) {
    userDefaults_ = userDefaults;
    updateURLDefaultsKey_ = updateURLDefaultsKey;
    updateLocalDirectoryDefaultsKey_ = updateLocalDirectoryDefaultsKey;
    localIndexFilePath_ = localIndexFilePath;
  }
  return self;
}

- (NSString*)updateURLString {
  NSString* value = [userDefaults_ stringForKey:updateURLDefaultsKey_];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (void)setUpdateURLString:(NSString*)updateURLString {
  NSString* value =
      [updateURLString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (value.length == 0) {
    [userDefaults_ removeObjectForKey:updateURLDefaultsKey_];
  } else {
    [userDefaults_ setObject:value forKey:updateURLDefaultsKey_];
  }
  [userDefaults_ synchronize];
}

- (NSString*)localDirectoryPath {
  NSString* value = [userDefaults_ stringForKey:updateLocalDirectoryDefaultsKey_];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (void)setLocalDirectoryPath:(NSString*)localDirectoryPath {
  NSString* value =
      [localDirectoryPath stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (value.length == 0) {
    [userDefaults_ removeObjectForKey:updateLocalDirectoryDefaultsKey_];
  } else {
    [userDefaults_ setObject:value forKey:updateLocalDirectoryDefaultsKey_];
  }
  [userDefaults_ synchronize];
}

- (NSDictionary*)releaseManifestResult {
  NSString* updateURLString = [self updateURLString];
  NSError* urlError = nil;
  if (updateURLString.length > 0) {
    NSDictionary* result = [self releaseManifestResultFromURLString:updateURLString error:&urlError];
    if (result) {
      return result;
    }
  }

  NSString* localDirectory = [self localDirectoryPath];
  if (localDirectory.length > 0) {
    NSError* error = nil;
    NSDictionary* result = [self releaseManifestResultFromLocalPath:localDirectory error:&error];
    if (result) {
      return result;
    }
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"Local fallback: %@", localDirectory],
      @"error" : error.localizedDescription ?: @"Unable to read the local update folder."
    };
  }

  if (updateURLString.length > 0) {
    return @{
      @"sourceLabel" : [NSString stringWithFormat:@"URL: %@", updateURLString],
      @"error" : urlError.localizedDescription ?: @"Unable to read the update URL and no local fallback is configured."
    };
  }

  return @{
    @"sourceLabel" : @"No source configured",
    @"error" : @"Configure an update URL or a local update folder."
  };
}

- (NSDictionary*)releaseModulesByIdentifier:(NSArray*)releaseModules {
  NSMutableDictionary* modulesByIdentifier = [NSMutableDictionary dictionary];
  for (NSDictionary* releaseModule in releaseModules) {
    if (![releaseModule isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length > 0) {
      modulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  return modulesByIdentifier;
}

- (NSDictionary*)releaseModuleWithIdentifier:(NSString*)moduleIdentifier
                                updateResult:(NSDictionary*)updateResult {
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  return [self releaseModulesByIdentifier:releaseModules][moduleIdentifier ?: @""];
}

- (NSString*)resolvedUpdateZipPathForReleaseModule:(NSDictionary*)releaseModule
                                      updateResult:(NSDictionary*)updateResult
                                             error:(NSError**)error {
  NSString* zipName = [releaseModule[@"zip"] isKindOfClass:NSString.class] ? releaseModule[@"zip"] : @"";
  if (zipName.length == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest entry does not declare a zip file."}];
    }
    return @"";
  }

  NSString* sourceKind = [updateResult[@"sourceKind"] isKindOfClass:NSString.class] ? updateResult[@"sourceKind"] : @"";
  if ([sourceKind isEqualToString:@"local"]) {
    NSString* basePath = [updateResult[@"basePath"] isKindOfClass:NSString.class] ? updateResult[@"basePath"] : @"";
    NSString* zipPath = [basePath stringByAppendingPathComponent:zipName];
    if ([NSFileManager.defaultManager fileExistsAtPath:zipPath]) {
      return zipPath;
    }
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Update zip not found: %@", zipPath]}];
    }
    return @"";
  }

  NSString* baseURLString = [updateResult[@"baseURL"] isKindOfClass:NSString.class] ? updateResult[@"baseURL"] : @"";
  NSURL* baseURL = [NSURL URLWithString:baseURLString];
  NSURL* zipURL = [NSURL URLWithString:zipName relativeToURL:baseURL];
  if (!zipURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey : @"The update zip URL is invalid."}];
    }
    return @"";
  }

  NSData* data = [NSData dataWithContentsOfURL:zipURL options:0 error:error];
  if (!data) {
    return @"";
  }

  NSString* targetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:zipName.lastPathComponent];
  if (![data writeToFile:targetPath options:NSDataWritingAtomic error:error]) {
    return @"";
  }

  return targetPath;
}

- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion {
  return [leftVersion compare:rightVersion options:NSNumericSearch];
}

- (NSURL*)manifestURLForURLString:(NSString*)urlString {
  NSString* trimmedString =
      [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedString.length == 0) {
    return nil;
  }

  NSURL* sourceURL = [NSURL URLWithString:trimmedString];
  if (!sourceURL.scheme.length) {
    return nil;
  }

  if ([sourceURL.path.lastPathComponent isEqualToString:@"modules-release-manifest.json"] ||
      [sourceURL.pathExtension.lowercaseString isEqualToString:@"json"]) {
    return sourceURL;
  }

  NSString* separator = [trimmedString hasSuffix:@"/"] ? @"" : @"/";
  return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@modules-release-manifest.json",
                                                         trimmedString,
                                                         separator]];
}

- (NSDictionary*)releaseManifestResultFromURLString:(NSString*)urlString error:(NSError**)error {
  NSURL* manifestURL = [self manifestURLForURLString:urlString];
  if (!manifestURL) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"The configured update URL is invalid."}];
    }
    return nil;
  }

  NSData* data = [NSData dataWithContentsOfURL:manifestURL options:0 error:error];
  if (!data) {
    return nil;
  }

  NSDictionary* manifest = [self releaseManifestFromData:data error:error];
  if (!manifest) {
    return nil;
  }

  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"url",
    @"sourceLabel" : manifestURL.absoluteString ?: @"URL",
    @"baseURL" : [manifestURL URLByDeletingLastPathComponent].absoluteString ?: @""
  };
}

- (NSDictionary*)releaseManifestResultFromLocalPath:(NSString*)path error:(NSError**)error {
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:6
                               userInfo:@{NSLocalizedDescriptionKey : @"The local update source must be a folder containing module zips."}];
    }
    return nil;
  }

  NSArray* directoryEntries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:error];
  if (!directoryEntries) {
    return nil;
  }

  NSDictionary* cachedIndex = [self localIndex];
  NSDictionary* cachedItems = [cachedIndex[@"items"] isKindOfClass:NSDictionary.class] ? cachedIndex[@"items"] : @{};
  NSMutableDictionary* nextCachedItems = [NSMutableDictionary dictionary];
  NSMutableDictionary* latestModulesByIdentifier = [NSMutableDictionary dictionary];

  for (NSString* entryName in directoryEntries) {
    if (![entryName isKindOfClass:NSString.class] ||
        ![entryName.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      continue;
    }

    NSString* zipPath = [path stringByAppendingPathComponent:entryName];
    NSDictionary* releaseModule = [self releaseModuleFromLocalZipAtPath:zipPath
                                                               fileName:entryName
                                                            cachedItems:cachedItems];
    if (!releaseModule) {
      continue;
    }

    nextCachedItems[zipPath] = releaseModule;
    NSString* moduleIdentifier = [releaseModule[@"id"] isKindOfClass:NSString.class] ? releaseModule[@"id"] : @"";
    if (moduleIdentifier.length == 0) {
      continue;
    }

    NSDictionary* currentModule = latestModulesByIdentifier[moduleIdentifier];
    if (!currentModule || [self shouldPreferReleaseModule:releaseModule overReleaseModule:currentModule]) {
      latestModulesByIdentifier[moduleIdentifier] = releaseModule;
    }
  }

  [self writeLocalIndex:@{
    @"version" : @1,
    @"items" : nextCachedItems
  }];

  NSArray* modules = [latestModulesByIdentifier.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* leftModule,
                                                                                                         NSDictionary* rightModule) {
    NSString* leftIdentifier = [leftModule[@"id"] isKindOfClass:NSString.class] ? leftModule[@"id"] : @"";
    NSString* rightIdentifier = [rightModule[@"id"] isKindOfClass:NSString.class] ? rightModule[@"id"] : @"";
    return [leftIdentifier compare:rightIdentifier options:NSCaseInsensitiveSearch];
  }];
  if (modules.count == 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:7
                               userInfo:@{NSLocalizedDescriptionKey : @"No valid module zip was found in the local update folder."}];
    }
    return nil;
  }

  NSDictionary* manifest = @{
    @"generatedAt" : [NSDate.date descriptionWithLocale:nil],
    @"modules" : modules
  };
  return @{
    @"manifest" : manifest,
    @"sourceKind" : @"local",
    @"sourceLabel" : [NSString stringWithFormat:@"Local folder: %@", path],
    @"basePath" : path
  };
}

- (NSDictionary*)releaseModuleFromLocalZipAtPath:(NSString*)zipPath
                                        fileName:(NSString*)fileName
                                     cachedItems:(NSDictionary*)cachedItems {
  NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:zipPath error:nil];
  NSDate* modificationDate = [attributes[NSFileModificationDate] isKindOfClass:NSDate.class]
      ? attributes[NSFileModificationDate]
      : NSDate.distantPast;
  NSNumber* fileSize = [attributes[NSFileSize] isKindOfClass:NSNumber.class] ? attributes[NSFileSize] : @0;
  NSNumber* modifiedAt = @((NSInteger)floor(modificationDate.timeIntervalSince1970));

  NSDictionary* cachedItem = [cachedItems[zipPath] isKindOfClass:NSDictionary.class] ? cachedItems[zipPath] : nil;
  if (cachedItem &&
      [cachedItem[@"filemtime"] isEqual:modifiedAt] &&
      [cachedItem[@"size"] isEqual:fileSize] &&
      [cachedItem[@"id"] isKindOfClass:NSString.class] &&
      [cachedItem[@"version"] isKindOfClass:NSString.class]) {
    return cachedItem;
  }

  NSError* manifestError = nil;
  NSDictionary* moduleManifest = [self moduleManifestFromZipAtPath:zipPath error:&manifestError];
  if (!moduleManifest) {
    NSLog(@"Unable to read module update zip manifest at %@: %@", zipPath, manifestError.localizedDescription);
    return nil;
  }

  NSString* moduleIdentifier = [moduleManifest[@"id"] isKindOfClass:NSString.class] ? moduleManifest[@"id"] : @"";
  NSString* moduleVersion = [moduleManifest[@"version"] isKindOfClass:NSString.class] ? moduleManifest[@"version"] : @"";
  if (moduleIdentifier.length == 0 || moduleVersion.length == 0) {
    NSLog(@"Skipping module update zip without id or version: %@", zipPath);
    return nil;
  }

  NSString* moduleName = [moduleManifest[@"name"] isKindOfClass:NSString.class] ? moduleManifest[@"name"] : moduleIdentifier;
  NSMutableDictionary* releaseModule = [NSMutableDictionary dictionaryWithDictionary:moduleManifest];
  releaseModule[@"id"] = moduleIdentifier;
  releaseModule[@"name"] = moduleName;
  releaseModule[@"version"] = moduleVersion;
  releaseModule[@"zip"] = fileName ?: zipPath.lastPathComponent;
  releaseModule[@"path"] = zipPath;
  releaseModule[@"filemtime"] = modifiedAt;
  releaseModule[@"size"] = fileSize;
  return releaseModule;
}

- (BOOL)shouldPreferReleaseModule:(NSDictionary*)candidateModule overReleaseModule:(NSDictionary*)currentModule {
  NSString* candidateVersion = [candidateModule[@"version"] isKindOfClass:NSString.class] ? candidateModule[@"version"] : @"";
  NSString* currentVersion = [currentModule[@"version"] isKindOfClass:NSString.class] ? currentModule[@"version"] : @"";
  NSComparisonResult versionComparison = [self compareVersion:candidateVersion toVersion:currentVersion];
  if (versionComparison == NSOrderedDescending) {
    return YES;
  }
  if (versionComparison == NSOrderedAscending) {
    return NO;
  }

  NSNumber* candidateModifiedAt = [candidateModule[@"filemtime"] isKindOfClass:NSNumber.class] ? candidateModule[@"filemtime"] : @0;
  NSNumber* currentModifiedAt = [currentModule[@"filemtime"] isKindOfClass:NSNumber.class] ? currentModule[@"filemtime"] : @0;
  return [candidateModifiedAt compare:currentModifiedAt] == NSOrderedDescending;
}

- (NSDictionary*)moduleManifestFromZipAtPath:(NSString*)zipPath error:(NSError**)error {
  NSData* manifestData = [self dataFromZipAtPath:zipPath innerPath:@"manifest.json" error:nil];
  if (!manifestData) {
    manifestData = [self dataFromZipAtPath:zipPath innerPath:@"*/manifest.json" error:error];
  }
  if (!manifestData) {
    return nil;
  }

  return [self releaseManifestFromData:manifestData error:error];
}

- (NSData*)dataFromZipAtPath:(NSString*)zipPath innerPath:(NSString*)innerPath error:(NSError**)error {
  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
  task.arguments = @[@"-p", zipPath, innerPath];

  NSPipe* outputPipe = [NSPipe pipe];
  NSPipe* errorPipe = [NSPipe pipe];
  task.standardOutput = outputPipe;
  task.standardError = errorPipe;

  NSError* launchError = nil;
  if (![task launchAndReturnError:&launchError]) {
    if (error) {
      *error = launchError;
    }
    return nil;
  }

  NSData* outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
  NSData* errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (task.terminationStatus != 0 || outputData.length == 0) {
    if (error) {
      NSString* unzipError = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:8
                               userInfo:@{NSLocalizedDescriptionKey : unzipError.length > 0
                                                                    ? unzipError
                                                                    : @"Unable to extract manifest.json from the module zip."}];
    }
    return nil;
  }

  return outputData;
}

- (NSDictionary*)localIndex {
  NSData* data = [NSData dataWithContentsOfFile:localIndexFilePath_];
  if (!data) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (void)writeLocalIndex:(NSDictionary*)index {
  NSString* indexDirectory = localIndexFilePath_.stringByDeletingLastPathComponent;
  [NSFileManager.defaultManager createDirectoryAtPath:indexDirectory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:index
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  if (data) {
    [data writeToFile:localIndexFilePath_ options:NSDataWritingAtomic error:nil];
  }
}

- (NSDictionary*)releaseManifestFromData:(NSData*)data error:(NSError**)error {
  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    if (error) {
      *error = [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : @"The update manifest is not a JSON object."}];
    }
    return nil;
  }

  return decoded;
}

@end
