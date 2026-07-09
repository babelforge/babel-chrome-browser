#import "Browser/Modules/Installation/NativeModuleInstaller.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"

static NSString* const kBabelNativeModuleInstallerErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-installer";

@implementation BabelNativeModuleInstaller {
  NSString* modulesDirectoryPath_;
}

- (instancetype)initWithModulesDirectoryPath:(NSString*)modulesDirectoryPath {
  self = [super init];
  if (self) {
    modulesDirectoryPath_ = [modulesDirectoryPath copy];
  }

  return self;
}

- (BOOL)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error {
  if (zipPath.length == 0 || ![NSFileManager.defaultManager isReadableFileAtPath:zipPath]) {
    [self assignError:error description:@"Module zip not found or not readable."];
    return NO;
  }

  if (![self ensureModulesDirectoryWithError:error]) {
    return NO;
  }

  NSString* temporaryDirectory = [self temporaryDirectoryWithError:error];
  if (!temporaryDirectory) {
    return NO;
  }

  BOOL installed = [self installModuleZipAtPath:zipPath
                             temporaryDirectory:temporaryDirectory
                                          error:error];
  [self removeItemAtPath:temporaryDirectory ignoringErrors:YES];

  return installed;
}

- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier
                        enabled:(BOOL)enabled
                          error:(NSError**)error {
  if (![self isValidModuleIdentifier:moduleIdentifier]) {
    [self assignError:error description:[NSString stringWithFormat:@"Module id \"%@\" is invalid.", moduleIdentifier]];
    return NO;
  }

  NSString* manifestPath = [[self targetDirectoryForModuleIdentifier:moduleIdentifier]
      stringByAppendingPathComponent:@"manifest.json"];
  NSMutableDictionary* manifestData = [[self manifestDataAtPath:manifestPath error:error] mutableCopy];
  if (!manifestData) {
    return NO;
  }

  manifestData[@"enabled"] = @(enabled);
  return [self writeManifestData:manifestData toPath:manifestPath error:error];
}

- (BOOL)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  if (![self isValidModuleIdentifier:moduleIdentifier]) {
    [self assignError:error description:[NSString stringWithFormat:@"Module id \"%@\" is invalid.", moduleIdentifier]];
    return NO;
  }

  NSString* targetDirectory = [self targetDirectoryForModuleIdentifier:moduleIdentifier];
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:targetDirectory isDirectory:&isDirectory] || !isDirectory) {
    [self assignError:error description:[NSString stringWithFormat:@"Module \"%@\" is not installed.", moduleIdentifier]];
    return NO;
  }

  return [self removeItemAtPath:targetDirectory ignoringErrors:NO error:error];
}

- (NSString*)moduleIdentifierInZipAtPath:(NSString*)zipPath error:(NSError**)error {
  if (zipPath.length == 0 || ![NSFileManager.defaultManager isReadableFileAtPath:zipPath]) {
    [self assignError:error description:@"Module zip not found or not readable."];
    return nil;
  }

  NSString* temporaryDirectory = [self temporaryDirectoryWithError:error];
  if (!temporaryDirectory) {
    return nil;
  }

  NSString* moduleIdentifier = [self moduleIdentifierInZipAtPath:zipPath
                                              temporaryDirectory:temporaryDirectory
                                                           error:error];
  [self removeItemAtPath:temporaryDirectory ignoringErrors:YES];

  return moduleIdentifier;
}

- (BOOL)installModuleZipAtPath:(NSString*)zipPath
            temporaryDirectory:(NSString*)temporaryDirectory
                         error:(NSError**)error {
  NSArray<NSString*>* zipEntries = [self zipEntriesForArchiveAtPath:zipPath error:error];
  if (!zipEntries || ![self validateZipEntries:zipEntries error:error]) {
    return NO;
  }

  if (![self extractZipAtPath:zipPath toDirectory:temporaryDirectory error:error]) {
    return NO;
  }

  if (![self rejectSymbolicLinksInDirectory:temporaryDirectory error:error]) {
    return NO;
  }

  NSString* moduleRoot = [self resolvedExtractedModuleRoot:temporaryDirectory error:error];
  if (!moduleRoot) {
    return NO;
  }

  NSDictionary* manifestData = [self manifestDataAtPath:[moduleRoot stringByAppendingPathComponent:@"manifest.json"]
                                                  error:error];
  if (!manifestData) {
    return NO;
  }

  BabelNativeModuleManifest* manifest =
      [BabelNativeModuleManifest manifestWithDictionary:manifestData modulePath:moduleRoot error:error];
  if (!manifest) {
    return NO;
  }

  NSString* targetDirectory = [self targetDirectoryForModuleIdentifier:manifest.moduleIdentifier];
  BOOL isDirectory = NO;
  BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:targetDirectory isDirectory:&isDirectory];
  if (exists && !isDirectory) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module target path is not a directory: %@", targetDirectory]];
    return NO;
  }

  if (exists) {
    return [self replaceExistingModuleAtPath:moduleRoot
                              targetDirectory:targetDirectory
                                   moduleName:manifest.moduleIdentifier
                                        error:error];
  }

  return [self moveModuleAtPath:moduleRoot toTargetDirectory:targetDirectory error:error];
}

- (NSString*)moduleIdentifierInZipAtPath:(NSString*)zipPath
                       temporaryDirectory:(NSString*)temporaryDirectory
                                    error:(NSError**)error {
  NSArray<NSString*>* zipEntries = [self zipEntriesForArchiveAtPath:zipPath error:error];
  if (!zipEntries || ![self validateZipEntries:zipEntries error:error]) {
    return nil;
  }

  if (![self extractZipAtPath:zipPath toDirectory:temporaryDirectory error:error]) {
    return nil;
  }

  if (![self rejectSymbolicLinksInDirectory:temporaryDirectory error:error]) {
    return nil;
  }

  NSString* moduleRoot = [self resolvedExtractedModuleRoot:temporaryDirectory error:error];
  if (!moduleRoot) {
    return nil;
  }

  NSDictionary* manifestData = [self manifestDataAtPath:[moduleRoot stringByAppendingPathComponent:@"manifest.json"]
                                                  error:error];
  if (!manifestData) {
    return nil;
  }

  BabelNativeModuleManifest* manifest =
      [BabelNativeModuleManifest manifestWithDictionary:manifestData modulePath:moduleRoot error:error];
  return manifest.moduleIdentifier;
}

- (NSArray<NSString*>*)zipEntriesForArchiveAtPath:(NSString*)zipPath error:(NSError**)error {
  NSString* output = [self runToolAtPath:@"/usr/bin/zipinfo"
                               arguments:@[@"-1", zipPath]
                                   error:error];
  if (!output) {
    return nil;
  }

  NSArray<NSString*>* rows = [output componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
  NSMutableArray<NSString*>* entries = [NSMutableArray array];
  for (NSString* row in rows) {
    NSString* entry = [row stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (entry.length > 0) {
      [entries addObject:entry];
    }
  }

  if (entries.count == 0) {
    [self assignError:error description:@"Module zip is empty."];
    return nil;
  }

  return entries;
}

- (BOOL)validateZipEntries:(NSArray<NSString*>*)entries error:(NSError**)error {
  for (NSString* entry in entries) {
    if (entry.length == 0 || [entry hasPrefix:@"/"] || [entry containsString:@"\\"]) {
      [self assignError:error description:[NSString stringWithFormat:@"Module zip contains an unsafe entry \"%@\".", entry]];
      return NO;
    }

    NSArray<NSString*>* components = [entry componentsSeparatedByString:@"/"];
    for (NSUInteger index = 0; index < components.count; ++index) {
      NSString* component = components[index];
      BOOL isTrailingDirectoryComponent = index == components.count - 1 && component.length == 0;
      if (isTrailingDirectoryComponent) {
        continue;
      }

      if (component.length == 0 || [component isEqualToString:@".."]) {
        [self assignError:error
              description:[NSString stringWithFormat:@"Module zip contains an unsafe entry \"%@\".", entry]];
        return NO;
      }
    }
  }

  return YES;
}

- (BOOL)extractZipAtPath:(NSString*)zipPath toDirectory:(NSString*)temporaryDirectory error:(NSError**)error {
  return [self runToolAtPath:@"/usr/bin/ditto"
                   arguments:@[@"-x", @"-k", zipPath, temporaryDirectory]
                       error:error] != nil;
}

- (BOOL)rejectSymbolicLinksInDirectory:(NSString*)directory error:(NSError**)error {
  NSArray<NSString*>* subpaths = [NSFileManager.defaultManager subpathsOfDirectoryAtPath:directory error:error];
  if (!subpaths) {
    return NO;
  }

  for (NSString* subpath in subpaths) {
    NSString* path = [directory stringByAppendingPathComponent:subpath];
    NSDictionary<NSFileAttributeKey, id>* attributes =
        [NSFileManager.defaultManager attributesOfItemAtPath:path error:error];
    if (!attributes) {
      return NO;
    }

    if ([attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module zip contains a symbolic link \"%@\".", subpath]];
      return NO;
    }
  }

  return YES;
}

- (NSString*)resolvedExtractedModuleRoot:(NSString*)temporaryDirectory error:(NSError**)error {
  NSString* rootManifest = [temporaryDirectory stringByAppendingPathComponent:@"manifest.json"];
  BOOL isDirectory = NO;
  if ([NSFileManager.defaultManager fileExistsAtPath:rootManifest isDirectory:&isDirectory] && !isDirectory) {
    return temporaryDirectory;
  }

  NSArray<NSString*>* children = [NSFileManager.defaultManager contentsOfDirectoryAtPath:temporaryDirectory error:error];
  if (!children) {
    return nil;
  }

  NSMutableArray<NSString*>* candidateDirectories = [NSMutableArray array];
  for (NSString* child in children) {
    if ([child isEqualToString:@"__MACOSX"] || [child isEqualToString:@".DS_Store"]) {
      continue;
    }

    NSString* childPath = [temporaryDirectory stringByAppendingPathComponent:child];
    BOOL childIsDirectory = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:childPath isDirectory:&childIsDirectory] && childIsDirectory) {
      [candidateDirectories addObject:childPath];
    }
  }

  if (candidateDirectories.count != 1) {
    [self assignError:error description:@"Module zip must contain manifest.json at its root or inside one top-level directory."];
    return nil;
  }

  NSString* moduleRoot = candidateDirectories.firstObject;
  NSString* nestedManifest = [moduleRoot stringByAppendingPathComponent:@"manifest.json"];
  if (![NSFileManager.defaultManager fileExistsAtPath:nestedManifest isDirectory:&isDirectory] || isDirectory) {
    [self assignError:error description:@"Module zip does not contain manifest.json."];
    return nil;
  }

  return moduleRoot;
}

- (BOOL)replaceExistingModuleAtPath:(NSString*)moduleRoot
                     targetDirectory:(NSString*)targetDirectory
                          moduleName:(NSString*)moduleName
                               error:(NSError**)error {
  NSString* replacementManifestPath = [moduleRoot stringByAppendingPathComponent:@"manifest.json"];
  NSMutableDictionary* replacementManifest = [[self manifestDataAtPath:replacementManifestPath error:error] mutableCopy];
  if (!replacementManifest) {
    return NO;
  }

  NSDictionary* existingManifest =
      [self manifestDataAtPath:[targetDirectory stringByAppendingPathComponent:@"manifest.json"] error:nil];
  if ([existingManifest[@"enabled"] isKindOfClass:NSNumber.class]) {
    replacementManifest[@"enabled"] = existingManifest[@"enabled"];
    if (![self writeManifestData:replacementManifest toPath:replacementManifestPath error:error]) {
      return NO;
    }
  }

  NSString* backupDirectory =
      [targetDirectory stringByAppendingFormat:@".backup-%@", [NSUUID UUID].UUIDString];
  NSFileManager* fileManager = NSFileManager.defaultManager;
  if (![fileManager moveItemAtPath:targetDirectory toPath:backupDirectory error:error]) {
    return NO;
  }

  if (![fileManager moveItemAtPath:moduleRoot toPath:targetDirectory error:error]) {
    [fileManager removeItemAtPath:targetDirectory error:nil];
    [fileManager moveItemAtPath:backupDirectory toPath:targetDirectory error:nil];
    [self assignError:error description:[NSString stringWithFormat:@"Unable to replace module \"%@\".", moduleName]];
    return NO;
  }

  return [self removeItemAtPath:backupDirectory ignoringErrors:NO error:error];
}

- (BOOL)moveModuleAtPath:(NSString*)moduleRoot
       toTargetDirectory:(NSString*)targetDirectory
                   error:(NSError**)error {
  return [NSFileManager.defaultManager moveItemAtPath:moduleRoot toPath:targetDirectory error:error];
}

- (NSDictionary*)manifestDataAtPath:(NSString*)manifestPath error:(NSError**)error {
  NSData* data = [NSData dataWithContentsOfFile:manifestPath options:0 error:error];
  if (!data) {
    return nil;
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    [self assignError:error description:@"Unable to decode module manifest."];
    return nil;
  }

  return decoded;
}

- (BOOL)writeManifestData:(NSDictionary*)manifestData toPath:(NSString*)manifestPath error:(NSError**)error {
  NSData* data = [NSJSONSerialization dataWithJSONObject:manifestData
                                                 options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                   error:error];
  if (!data) {
    return NO;
  }

  NSMutableData* output = [data mutableCopy];
  const char newline = '\n';
  [output appendBytes:&newline length:1];
  return [output writeToFile:manifestPath options:NSDataWritingAtomic error:error];
}

- (BOOL)ensureModulesDirectoryWithError:(NSError**)error {
  if (modulesDirectoryPath_.length == 0) {
    [self assignError:error description:@"Modules directory is not configured."];
    return NO;
  }

  return [NSFileManager.defaultManager createDirectoryAtPath:modulesDirectoryPath_
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:error];
}

- (NSString*)temporaryDirectoryWithError:(NSError**)error {
  NSString* path = [NSTemporaryDirectory()
      stringByAppendingPathComponent:[NSString stringWithFormat:@"babelchrome-module-install-%@",
                                                                 [NSUUID UUID].UUIDString]];
  if (![NSFileManager.defaultManager createDirectoryAtPath:path
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:error]) {
    return nil;
  }

  return path;
}

- (NSString*)targetDirectoryForModuleIdentifier:(NSString*)moduleIdentifier {
  return [modulesDirectoryPath_ stringByAppendingPathComponent:moduleIdentifier ?: @""];
}

- (NSString*)runToolAtPath:(NSString*)toolPath
                 arguments:(NSArray<NSString*>*)arguments
                     error:(NSError**)error {
  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:toolPath];
  task.arguments = arguments;

  NSPipe* pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = pipe;

  @try {
    [task launch];
  } @catch (NSException* exception) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Unable to launch %@: %@", toolPath, exception.reason ?: @""]];
    return nil;
  }

  NSData* data = [pipe.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];

  NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
  if (task.terminationStatus != 0) {
    [self assignError:error
          description:[NSString stringWithFormat:@"%@ failed with status %d. %@",
                                                 toolPath,
                                                 task.terminationStatus,
                                                 output]];
    return nil;
  }

  return output;
}

- (BOOL)removeItemAtPath:(NSString*)path ignoringErrors:(BOOL)ignoringErrors {
  return [self removeItemAtPath:path ignoringErrors:ignoringErrors error:nil];
}

- (BOOL)removeItemAtPath:(NSString*)path ignoringErrors:(BOOL)ignoringErrors error:(NSError**)error {
  if (path.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:path]) {
    return YES;
  }

  NSError* removeError = nil;
  BOOL removed = [NSFileManager.defaultManager removeItemAtPath:path error:&removeError];
  if (!removed && !ignoringErrors && error) {
    *error = removeError;
  }

  return removed || ignoringErrors;
}

- (BOOL)isValidModuleIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return NO;
  }

  NSRegularExpression* expression =
      [NSRegularExpression regularExpressionWithPattern:@"^[a-z0-9][a-z0-9.-]*[a-z0-9]$"
                                                options:0
                                                  error:nil];
  NSRange range = NSMakeRange(0, moduleIdentifier.length);
  return [expression numberOfMatchesInString:moduleIdentifier options:0 range:range] == 1;
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleInstallerErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Unable to manage module."}];
}

@end
