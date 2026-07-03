// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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

- (NSDictionary*)moduleUpdateLocalIndex {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSData* data = [NSData dataWithContentsOfFile:indexPath];
  if (!data) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (void)writeModuleUpdateLocalIndex:(NSDictionary*)index {
  NSString* indexPath = [self moduleUpdateLocalIndexPath];
  NSString* indexDirectory = indexPath.stringByDeletingLastPathComponent;
  [NSFileManager.defaultManager createDirectoryAtPath:indexDirectory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
  if (data) {
    [data writeToFile:indexPath options:NSDataWritingAtomic error:nil];
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

- (NSDictionary*)releaseModuleWithIdentifier:(NSString*)moduleIdentifier updateResult:(NSDictionary*)updateResult {
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
