#import "LocalServices/LocalServiceHost.h"

#include <netinet/in.h>
#include <signal.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static NSString* const kLocalServiceHostErrorDomain = @"fr.babelforge.babel-chrome.local-service";
static NSUInteger const kLegacyViewerCacheKeyLengthThreshold = 64;

@implementation BabelLocalServiceHost {
  NSTask* task_;
  NSUInteger port_;
  NSString* token_;
  NSString* stateDirectoryPath_;
}

+ (instancetype)sharedHost {
  static BabelLocalServiceHost* sharedHost = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedHost = [[BabelLocalServiceHost alloc] init];
  });
  return sharedHost;
}

- (BOOL)startIfNeededWithError:(NSError**)error {
  if (task_.isRunning) {
    return YES;
  }

  NSString* phpPath = [self PHPExecutablePath];
  if (phpPath.length == 0) {
    [self assignError:error message:@"Unable to find a PHP executable for local viewers."];
    return NO;
  }

  NSURL* serviceDirectoryURL = [NSBundle.mainBundle.resourceURL
      URLByAppendingPathComponent:@"ExtensionHost"
                      isDirectory:YES];
  NSURL* publicDirectoryURL = [serviceDirectoryURL URLByAppendingPathComponent:@"public"
                                                                  isDirectory:YES];
  NSURL* routerURL = [publicDirectoryURL URLByAppendingPathComponent:@"index.php"
                                                        isDirectory:NO];
  if (![NSFileManager.defaultManager fileExistsAtPath:routerURL.path]) {
    [self assignError:error message:@"Unable to find the local viewer service router."];
    return NO;
  }

  port_ = [self availablePort];
  if (port_ == 0) {
    [self assignError:error message:@"Unable to allocate a local viewer service port."];
    return NO;
  }

  token_ = NSUUID.UUID.UUIDString;
  NSString* viewerCacheKey = [self viewerCacheKey];
  [self pruneViewerCacheDirectoriesKeepingCacheKey:viewerCacheKey];
  [self terminateStaleLocalServiceProcess];

  task_ = [[NSTask alloc] init];
  task_.executableURL = [NSURL fileURLWithPath:phpPath];
  task_.currentDirectoryURL = publicDirectoryURL;
  task_.arguments = @[
    @"-S",
    [NSString stringWithFormat:@"127.0.0.1:%lu", (unsigned long)port_],
    @"-t",
    publicDirectoryURL.path,
    routerURL.path
  ];

  NSMutableDictionary<NSString*, NSString*>* environment =
      [NSProcessInfo.processInfo.environment mutableCopy];
  [environment removeObjectForKey:@"BABELCHROME_VIEWER_TOKEN"];
  [environment removeObjectForKey:@"BABELCHROME_VIEWER_STATE_DIR"];
  [environment removeObjectForKey:@"BABELCHROME_VIEWER_CACHE_KEY"];
  environment[@"BABELCHROME_VIEWER_TOKEN"] = token_;
  environment[@"BABELCHROME_VIEWER_STATE_DIR"] = [self viewerStateDirectoryPath];
  environment[@"BABELCHROME_VIEWER_CACHE_KEY"] = viewerCacheKey;
  environment[@"APP_ENV"] = @"prod";
  environment[@"APP_DEBUG"] = @"0";
  task_.environment = environment;

  NSString* logPath = [self viewerLogFilePath];
  NSFileHandle* logHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
  if (logHandle) {
    [logHandle seekToEndOfFile];
    task_.standardOutput = logHandle;
    task_.standardError = logHandle;
  }

  NSError* launchError = nil;
  if (![task_ launchAndReturnError:&launchError]) {
    if (error) {
      *error = launchError;
    }
    task_ = nil;
    return NO;
  }
  [self writeLocalServicePidFile];

  if (![self waitUntilHealthy]) {
    [self stop];
    [self assignError:error
              message:[NSString stringWithFormat:
                  @"The local viewer service did not become ready. Log: %@", logPath]];
    return NO;
  }

  return YES;
}

- (void)stop {
  if (task_.isRunning) {
    [task_ terminate];
  }
  task_ = nil;
  port_ = 0;
  token_ = nil;
  [NSFileManager.defaultManager removeItemAtPath:[self viewerPidFilePath] error:nil];
}

- (BOOL)supportsFileURL:(NSURL*)fileURL {
  return [self supportsURL:fileURL];
}

- (BOOL)supportsURL:(NSURL*)url {
  return [self viewerRouteForURL:url].length > 0;
}

- (NSString*)viewerKindForURL:(NSURL*)url {
  NSDictionary* routeMetadata = [self viewerRouteMetadataForURL:url];
  NSString* viewerKind = [routeMetadata[@"viewerKind"] isKindOfClass:NSString.class]
      ? routeMetadata[@"viewerKind"]
      : nil;
  return viewerKind.length > 0 ? viewerKind : nil;
}

- (NSDictionary*)addressBadgeForURL:(NSURL*)url {
  if (!url) {
    return nil;
  }

  NSDictionary* response = [self internalJSONWithPath:@"/internal/address-badge"
                                           queryItems:@[
                                             [NSURLQueryItem queryItemWithName:@"url"
                                                                        value:url.absoluteString ?: @""]
                                           ]
                                                error:nil];
  NSNumber* handled = [response[@"handled"] isKindOfClass:NSNumber.class] ? response[@"handled"] : nil;
  NSDictionary* badge = [response[@"badge"] isKindOfClass:NSDictionary.class] ? response[@"badge"] : nil;
  if (![handled boolValue] || !badge) {
    return nil;
  }

  NSMutableDictionary* enrichedBadge = [NSMutableDictionary dictionaryWithDictionary:badge];
  if ([response[@"moduleId"] isKindOfClass:NSString.class]) {
    enrichedBadge[@"moduleId"] = response[@"moduleId"];
  }
  if ([response[@"settingsRoute"] isKindOfClass:NSString.class]) {
    enrichedBadge[@"settingsRoute"] = response[@"settingsRoute"];
  }

  return enrichedBadge;
}

- (NSURL*)viewerURLForURL:(NSURL*)url {
  NSString* route = [self viewerRouteForURL:url];
  if (route.length == 0 || port_ == 0 || token_.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceType = isRemoteURL ? @"url" : @"file";
  NSString* sourceParameterValue = isRemoteURL ? url.absoluteString : url.path;
  if (sourceParameterValue.length == 0) {
    return nil;
  }

  NSString* sourceIdentifier = [self registerSourceWithType:sourceType value:sourceParameterValue];
  if (sourceIdentifier.length == 0) {
    return nil;
  }

  NSURLComponents* components = [[NSURLComponents alloc] init];
  components.scheme = @"http";
  components.host = @"127.0.0.1";
  components.port = @(port_);
  if ([route hasPrefix:@"/module/"]) {
    components.path = route;
    components.queryItems = @[
      [NSURLQueryItem queryItemWithName:@"token" value:token_],
      [NSURLQueryItem queryItemWithName:@"sourceId" value:sourceIdentifier]
    ];
  } else {
    components.path = [route stringByAppendingPathComponent:sourceIdentifier];
    components.queryItems = @[
      [NSURLQueryItem queryItemWithName:@"token" value:token_]
    ];
  }
  return components.URL;
}

- (NSURL*)viewerURLForFileURL:(NSURL*)fileURL {
  return [self viewerURLForURL:fileURL];
}

- (NSDictionary*)modulesSnapshotWithError:(NSError**)error {
  return [self internalJSONWithPath:@"/internal/modules"
                         queryItems:@[]
                              error:error];
}

- (NSString*)fileTypeHeaderValueWithError:(NSError**)error {
  NSDictionary* response = [self internalJSONWithPath:@"/internal/file-types"
                                           queryItems:@[]
                                                error:error];
  NSString* headerValue = [response[@"headerValue"] isKindOfClass:NSString.class] ? response[@"headerValue"] : nil;
  return headerValue.length > 0 ? headerValue : nil;
}

- (NSDictionary*)dispatchModuleLifecycleHook:(NSString*)hook error:(NSError**)error {
  if (hook.length == 0) {
    [self assignError:error message:@"Missing module lifecycle hook."];
    return nil;
  }

  return [self internalJSONWithPath:@"/internal/module-lifecycle"
                         queryItems:@[
                           [NSURLQueryItem queryItemWithName:@"hook" value:hook]
                         ]
                              error:error];
}

- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                           error:(NSError**)error {
  return [self moduleURLForIdentifier:moduleIdentifier
                                route:route
                      sourceURLString:nil
                                error:error];
}

- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                           error:(NSError**)error {
  if (moduleIdentifier.length == 0) {
    [self assignError:error message:@"Missing module identifier."];
    return nil;
  }

  NSString* routeName = route.length > 0 ? route : @"index";
  if (![self startIfNeededWithError:error]) {
    return nil;
  }

  NSString* path = [NSString stringWithFormat:@"/module/%@/%@",
                                              moduleIdentifier,
                                              routeName];
  NSArray<NSURLQueryItem*>* queryItems = sourceURLString.length > 0
      ? @[[NSURLQueryItem queryItemWithName:@"sourceUrl" value:sourceURLString]]
      : @[];
  return [self internalURLWithPath:path queryItems:queryItems];
}

- (NSDictionary*)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error {
  if (zipPath.length == 0) {
    [self assignError:error message:@"Missing module zip path."];
    return nil;
  }

  return [self internalJSONWithPath:@"/internal/modules/install"
                         queryItems:@[
                           [NSURLQueryItem queryItemWithName:@"zip" value:zipPath]
                         ]
                              error:error];
}

- (NSDictionary*)setModuleWithIdentifier:(NSString*)moduleIdentifier
                                 enabled:(BOOL)enabled
                                   error:(NSError**)error {
  if (moduleIdentifier.length == 0) {
    [self assignError:error message:@"Missing module identifier."];
    return nil;
  }

  return [self internalJSONWithPath:(enabled ? @"/internal/modules/enable"
                                            : @"/internal/modules/disable")
                         queryItems:@[
                           [NSURLQueryItem queryItemWithName:@"moduleId" value:moduleIdentifier]
                         ]
                              error:error];
}

- (NSDictionary*)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  if (moduleIdentifier.length == 0) {
    [self assignError:error message:@"Missing module identifier."];
    return nil;
  }

  return [self internalJSONWithPath:@"/internal/modules/remove"
                         queryItems:@[
                           [NSURLQueryItem queryItemWithName:@"moduleId" value:moduleIdentifier]
                         ]
                              error:error];
}

- (NSString*)viewerRouteForURL:(NSURL*)url {
  NSDictionary* routeMetadata = [self viewerRouteMetadataForURL:url];
  NSString* route = [routeMetadata[@"route"] isKindOfClass:NSString.class] ? routeMetadata[@"route"] : nil;
  return route.length > 0 ? route : nil;
}

- (NSDictionary*)viewerRouteMetadataForURL:(NSURL*)url {
  if (!url) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  if (!url.isFileURL && !isRemoteURL) {
    return nil;
  }

  NSDictionary* response = [self internalJSONWithPath:@"/internal/viewer-route"
                                           queryItems:@[
                                             [NSURLQueryItem queryItemWithName:@"url"
                                                                        value:url.absoluteString ?: @""]
                                           ]
                                                error:nil];
  NSNumber* handled = [response[@"handled"] isKindOfClass:NSNumber.class] ? response[@"handled"] : nil;
  if (![handled boolValue]) {
    return nil;
  }

  return response;
}

- (NSDictionary*)internalJSONWithPath:(NSString*)path
                            queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                                 error:(NSError**)error {
  if (![self startIfNeededWithError:error]) {
    return nil;
  }

  NSURL* url = [self internalURLWithPath:path queryItems:queryItems];
  if (!url) {
    [self assignError:error message:@"Unable to build local service URL."];
    return nil;
  }

  NSData* data = [NSData dataWithContentsOfURL:url options:0 error:error];
  if (data.length == 0) {
    if (error && !*error) {
      [self assignError:error message:@"Local service returned an empty response."];
    }
    return nil;
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    [self assignError:error message:@"Local service returned an invalid JSON response."];
    return nil;
  }

  NSDictionary* response = decoded;
  id okValue = response[@"ok"];
  if ([okValue isKindOfClass:NSNumber.class] && ![okValue boolValue]) {
    NSString* message = [response[@"error"] isKindOfClass:NSString.class]
        ? response[@"error"]
        : @"Local service operation failed.";
    [self assignError:error message:message];
    return nil;
  }

  id errorValue = response[@"error"];
  if ([errorValue isKindOfClass:NSString.class]) {
    [self assignError:error message:errorValue];
    return nil;
  }

  return response;
}

- (NSURL*)internalURLWithPath:(NSString*)path
                   queryItems:(NSArray<NSURLQueryItem*>*)queryItems {
  if (port_ == 0 || token_.length == 0 || path.length == 0) {
    return nil;
  }

  NSURLComponents* components = [[NSURLComponents alloc] init];
  components.scheme = @"http";
  components.host = @"127.0.0.1";
  components.port = @(port_);
  components.path = path;

  NSMutableArray<NSURLQueryItem*>* items = [NSMutableArray arrayWithArray:queryItems ?: @[]];
  [items addObject:[NSURLQueryItem queryItemWithName:@"token" value:token_]];
  components.queryItems = items;
  return components.URL;
}

- (NSString*)PHPExecutablePath {
  NSArray<NSString*>* candidates = @[
    @"/opt/homebrew/bin/php",
    @"/usr/local/bin/php",
    @"/usr/local/opt/php@8.4/bin/php",
    @"/usr/bin/php"
  ];

  for (NSString* candidate in candidates) {
    if ([NSFileManager.defaultManager isExecutableFileAtPath:candidate]) {
      return candidate;
    }
  }

  return nil;
}

- (NSString*)viewerStateDirectoryPath {
  if (stateDirectoryPath_.length > 0) {
    return stateDirectoryPath_;
  }

  NSArray<NSURL*>* applicationSupportURLs =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask];
  NSURL* baseURL = applicationSupportURLs.firstObject;
  if (!baseURL) {
    stateDirectoryPath_ = [NSTemporaryDirectory() stringByAppendingPathComponent:@"BabelChrome/LocalServiceHost"];
    return stateDirectoryPath_;
  }

  NSURL* stateURL = [baseURL URLByAppendingPathComponent:@"BabelForge/BabelChrome/LocalServiceHost"
                                             isDirectory:YES];
  [NSFileManager.defaultManager createDirectoryAtURL:stateURL
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  stateDirectoryPath_ = stateURL.path;
  return stateDirectoryPath_;
}

- (NSString*)viewerLogFilePath {
  NSString* logDirectoryPath = [[self viewerStateDirectoryPath] stringByAppendingPathComponent:@"log"];
  [NSFileManager.defaultManager createDirectoryAtPath:logDirectoryPath
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  NSString* logPath = [logDirectoryPath stringByAppendingPathComponent:@"php-server.log"];
  if (![NSFileManager.defaultManager fileExistsAtPath:logPath]) {
    [NSFileManager.defaultManager createFileAtPath:logPath contents:nil attributes:nil];
  }
  return logPath;
}

- (NSString*)viewerPidFilePath {
  return [[self viewerStateDirectoryPath] stringByAppendingPathComponent:@"php-server.pid"];
}

- (void)terminateStaleLocalServiceProcess {
  NSString* pidPath = [self viewerPidFilePath];
  NSString* pidText = [NSString stringWithContentsOfFile:pidPath
                                                encoding:NSUTF8StringEncoding
                                                   error:nil];
  pid_t pid = (pid_t)pidText.integerValue;
  if (pid <= 0) {
    [NSFileManager.defaultManager removeItemAtPath:pidPath error:nil];
    return;
  }

  if (kill(pid, 0) != 0) {
    [NSFileManager.defaultManager removeItemAtPath:pidPath error:nil];
    return;
  }

  kill(pid, SIGTERM);
  for (NSUInteger attempt = 0; attempt < 20; ++attempt) {
    if (kill(pid, 0) != 0) {
      break;
    }
    [NSThread sleepForTimeInterval:0.05];
  }

  if (kill(pid, 0) == 0) {
    kill(pid, SIGKILL);
  }
  [NSFileManager.defaultManager removeItemAtPath:pidPath error:nil];
}

- (void)writeLocalServicePidFile {
  if (!task_) {
    return;
  }

  NSString* pidText = [NSString stringWithFormat:@"%d\n", task_.processIdentifier];
  [pidText writeToFile:[self viewerPidFilePath]
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:nil];
}

- (NSString*)viewerCacheKey {
  NSMutableArray<NSString*>* parts = [NSMutableArray array];
  NSArray<NSString*>* paths = @[
    NSBundle.mainBundle.executablePath ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Kernel.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Controller/ViewerController.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/DocumentSource.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Service/AssetPathResolver.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Service/SourceLoader.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Service/SourceRegistry.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Service/MarkdownDocumentRenderer.php"] path] ?: @"",
    [[NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"ExtensionHost/src/Service/OpenApiDocumentRenderer.php"] path] ?: @""
  ];

  NSURL* moduleDirectoryURL = [NSBundle.mainBundle.resourceURL
      URLByAppendingPathComponent:@"ExtensionHost/src/Module"
                      isDirectory:YES];
  NSMutableArray<NSString*>* mutablePaths = [NSMutableArray arrayWithArray:paths];
  NSDirectoryEnumerator<NSURL*>* moduleEnumerator =
      [NSFileManager.defaultManager enumeratorAtURL:moduleDirectoryURL
                         includingPropertiesForKeys:nil
                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                       errorHandler:nil];
  for (NSURL* moduleURL in moduleEnumerator) {
    if ([moduleURL.pathExtension isEqualToString:@"php"]) {
      [mutablePaths addObject:moduleURL.path ?: @""];
    }
  }
  paths = mutablePaths;

  for (NSString* path in paths) {
    NSDictionary<NSFileAttributeKey, id>* attributes =
        [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    NSDate* modificationDate = attributes[NSFileModificationDate];
    if (modificationDate) {
      [parts addObject:[NSString stringWithFormat:@"%lld",
                                                  (long long)modificationDate.timeIntervalSince1970]];
    }
  }

  if (parts.count > 0) {
    return [NSString stringWithFormat:@"app-%016llx",
                                      (unsigned long long)[self stableHashForString:
                                          [parts componentsJoinedByString:@"-"]]];
  }

  NSString* version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
  return version.length > 0 ? version : @"default";
}

- (uint64_t)stableHashForString:(NSString*)value {
  const char* bytes = [value UTF8String];
  uint64_t hash = 1469598103934665603ULL;
  while (bytes && *bytes) {
    hash ^= (uint8_t)*bytes;
    hash *= 1099511628211ULL;
    ++bytes;
  }
  return hash;
}

- (void)pruneViewerCacheDirectoriesKeepingCacheKey:(NSString*)currentCacheKey {
  NSString* cacheDirectoryPath = [[[self viewerStateDirectoryPath] stringByAppendingPathComponent:@"cache"]
      stringByAppendingPathComponent:@"prod"];
  NSURL* cacheDirectoryURL = [NSURL fileURLWithPath:cacheDirectoryPath isDirectory:YES];
  NSArray<NSURLResourceKey>* resourceKeys = @[
    NSURLIsDirectoryKey,
    NSURLNameKey
  ];
  NSArray<NSURL*>* cacheURLs =
      [NSFileManager.defaultManager contentsOfDirectoryAtURL:cacheDirectoryURL
                                  includingPropertiesForKeys:resourceKeys
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];

  for (NSURL* cacheURL in cacheURLs) {
    NSDictionary<NSURLResourceKey, id>* values = [cacheURL resourceValuesForKeys:resourceKeys error:nil];
    NSNumber* isDirectory = values[NSURLIsDirectoryKey];
    NSString* name = values[NSURLNameKey];
    if (![isDirectory boolValue] || name.length == 0 || [name isEqualToString:currentCacheKey]) {
      continue;
    }

    BOOL isLegacyVerboseCache =
        [name hasPrefix:@"app-"] && name.length > kLegacyViewerCacheKeyLengthThreshold;
    if (isLegacyVerboseCache) {
      [NSFileManager.defaultManager removeItemAtURL:cacheURL error:nil];
    }
  }
}

- (NSString*)registerSourceWithType:(NSString*)type value:(NSString*)value {
  NSString* identifier = NSUUID.UUID.UUIDString.lowercaseString;
  NSString* stateDirectoryPath = [self viewerStateDirectoryPath];
  if (stateDirectoryPath.length == 0) {
    return nil;
  }

  NSString* registryPath = [stateDirectoryPath stringByAppendingPathComponent:@"sources.json"];
  NSMutableDictionary* registry = [NSMutableDictionary dictionary];
  NSData* existingData = [NSData dataWithContentsOfFile:registryPath];
  if (existingData.length > 0) {
    id parsedRegistry = [NSJSONSerialization JSONObjectWithData:existingData
                                                        options:NSJSONReadingMutableContainers
                                                          error:nil];
    if ([parsedRegistry isKindOfClass:NSDictionary.class]) {
      [registry addEntriesFromDictionary:parsedRegistry];
    }
  }

  registry[identifier] = @{
    @"type": type ?: @"",
    @"value": value ?: @"",
    @"createdAt": @((NSInteger)NSDate.date.timeIntervalSince1970)
  };

  NSData* data = [NSJSONSerialization dataWithJSONObject:registry
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  if (data.length == 0) {
    return nil;
  }

  if (![data writeToFile:registryPath atomically:YES]) {
    return nil;
  }

  return identifier;
}

- (NSUInteger)availablePort {
  int socketDescriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (socketDescriptor < 0) {
    return 0;
  }

  sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = 0;

  if (bind(socketDescriptor, (struct sockaddr*)&address, sizeof(address)) != 0) {
    close(socketDescriptor);
    return 0;
  }

  socklen_t addressLength = sizeof(address);
  if (getsockname(socketDescriptor, (struct sockaddr*)&address, &addressLength) != 0) {
    close(socketDescriptor);
    return 0;
  }

  NSUInteger port = ntohs(address.sin_port);
  close(socketDescriptor);
  return port;
}

- (BOOL)waitUntilHealthy {
  NSURL* healthURL = [NSURL URLWithString:
      [NSString stringWithFormat:@"http://127.0.0.1:%lu/health", (unsigned long)port_]];

  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:30.0];
  while ([deadline timeIntervalSinceNow] > 0) {
    NSData* data = [NSData dataWithContentsOfURL:healthURL];
    NSString* response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([response isEqualToString:@"ok"]) {
      return YES;
    }

    [NSThread sleepForTimeInterval:0.1];
  }

  return NO;
}

- (void)assignError:(NSError**)error message:(NSString*)message {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kLocalServiceHostErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Local service error."}];
}

- (void)dealloc {
  [self stop];
}

@end
