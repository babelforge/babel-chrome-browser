// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSDictionary*)moduleUpdateReleaseManifestResult {
  NSString* updateURLString = [self moduleUpdateURLString];
  NSError* urlError = nil;
  if (updateURLString.length > 0) {
    NSDictionary* result = [self releaseManifestResultFromURLString:updateURLString error:&urlError];
    if (result) {
      return result;
    }
  }

  NSString* localDirectory = [self moduleUpdateLocalDirectoryPath];
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

- (NSDictionary*)releaseManifestResultFromURLString:(NSString*)urlString error:(NSError**)error {
  NSURL* manifestURL = [self moduleUpdateManifestURLForURLString:urlString];
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

  NSDictionary* cachedIndex = [self moduleUpdateLocalIndex];
  NSDictionary* cachedItems = [cachedIndex[@"items"] isKindOfClass:NSDictionary.class] ? cachedIndex[@"items"] : @{};
  NSMutableDictionary* nextCachedItems = [NSMutableDictionary dictionary];
  NSMutableDictionary* latestModulesByIdentifier = [NSMutableDictionary dictionary];

  for (NSString* entryName in directoryEntries) {
    if (![entryName isKindOfClass:NSString.class] || ![entryName.pathExtension.lowercaseString isEqualToString:@"zip"]) {
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

  [self writeModuleUpdateLocalIndex:@{
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
