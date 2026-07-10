#import "Browser/Modules/Core/ModuleActionService.h"

#import "Browser/Modules/Installation/NativeModuleInstaller.h"
#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Modules/Runtime/NativeModuleHTTPHost.h"
#import "Browser/Modules/Runtime/NativeModulePrewarmCoordinator.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"
#import "Browser/Navigation/Viewer/ViewerSourceRegistry.h"
#import "LocalServices/LocalServiceHost.h"

@implementation BabelModuleActionService {
  BabelNativeModuleRegistry* nativeModuleRegistry_;
  BabelNativeModuleInstaller* nativeModuleInstaller_;
  BabelNativeModuleProcessRuntimeManager* nativeProcessRuntimeManager_;
  BabelNativeModulePrewarmCoordinator* nativePrewarmCoordinator_;
  BabelNativeModuleHTTPHost* nativeModuleHTTPHost_;
  BabelViewerSourceRegistry* viewerSourceRegistry_;
  BabelStableViewerURLResolver* stableViewerURLResolver_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    nativeModuleRegistry_ = [[BabelNativeModuleRegistry alloc] init];
    nativeModuleInstaller_ =
        [[BabelNativeModuleInstaller alloc] initWithModulesDirectoryPath:nativeModuleRegistry_.modulesDirectoryPath];
    nativeProcessRuntimeManager_ = [[BabelNativeModuleProcessRuntimeManager alloc] init];
    nativePrewarmCoordinator_ =
        [[BabelNativeModulePrewarmCoordinator alloc] initWithRuntimeManager:nativeProcessRuntimeManager_];
    viewerSourceRegistry_ = [[BabelViewerSourceRegistry alloc] init];
    stableViewerURLResolver_ = [[BabelStableViewerURLResolver alloc] init];
    nativeModuleHTTPHost_ = [[BabelNativeModuleHTTPHost alloc] initWithModuleRegistry:nativeModuleRegistry_
                                                                       runtimeManager:nativeProcessRuntimeManager_
                                                                        sourceRegistry:viewerSourceRegistry_];
  }

  return self;
}

- (void)dealloc {
  [nativeModuleHTTPHost_ stop];
  [nativeProcessRuntimeManager_ stopAllRuntimes];
}

- (NSDictionary*)modulesSnapshotWithError:(NSError**)error {
  NSError* nativeError = nil;
  NSDictionary* nativeSnapshot = [nativeModuleRegistry_ modulesSnapshotWithError:&nativeError];
  if (nativeSnapshot) {
    return [self snapshotByAddingDiagnosticsToNativeSnapshot:nativeSnapshot];
  }

  NSError* hostError = nil;
  NSDictionary* hostSnapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&hostError];
  if (hostSnapshot) {
    return hostSnapshot;
  }

  if (error) {
    *error = nativeError ?: hostError;
  }
  return nil;
}

- (NSDictionary*)snapshotByAddingDiagnosticsToNativeSnapshot:(NSDictionary*)snapshot {
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSMutableArray<NSDictionary*>* enrichedModules = [NSMutableArray arrayWithCapacity:modules.count];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSMutableDictionary* enrichedModule = [module mutableCopy];
    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    BabelNativeModuleManifest* nativeModule = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier error:nil];
    NSDictionary* readinessStatus = nil;
    NSDictionary* runtimeStatus = nil;
    if (moduleIdentifier.length > 0) {
      NSDictionary* readinessResponse =
          [BabelLocalServiceHost.sharedHost readinessStatusForModuleWithIdentifier:moduleIdentifier error:nil];
      readinessStatus = [self moduleDiagnosticStatusFromResponse:readinessResponse
                                                             key:@"readinessStatus"
                                                    failureState:@"failed"
                                                     booleanName:@"ready"];
    }
    if (nativeModule) {
      runtimeStatus = [nativeProcessRuntimeManager_ runtimeStatusForModule:nativeModule];
      runtimeStatus = [self runtimeStatusByAddingPrewarmStatus:runtimeStatus
                                              moduleIdentifier:moduleIdentifier];
    }
    if (!runtimeStatus && moduleIdentifier.length > 0) {
      NSDictionary* runtimeResponse =
          [BabelLocalServiceHost.sharedHost runtimeStatusForModuleWithIdentifier:moduleIdentifier
                                                                           error:nil];
      runtimeStatus = [self moduleDiagnosticStatusFromResponse:runtimeResponse
                                                           key:@"runtimeStatus"
                                                  failureState:@"unavailable"
                                                   booleanName:@"running"];
    }

    enrichedModule[@"readinessStatus"] = readinessStatus ?: @{@"ready" : @NO, @"state" : @"unknown"};
    enrichedModule[@"runtimeStatus"] = runtimeStatus ?: @{@"running" : @NO, @"state" : @"unknown"};
    [enrichedModules addObject:enrichedModule];
  }

  NSMutableDictionary* enrichedSnapshot = [snapshot mutableCopy];
  enrichedSnapshot[@"modules"] = enrichedModules;
  return enrichedSnapshot;
}

- (NSDictionary*)moduleDiagnosticStatusFromResponse:(NSDictionary*)response
                                                key:(NSString*)key
                                       failureState:(NSString*)failureState
                                        booleanName:(NSString*)booleanName {
  if (![response isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSDictionary* nestedStatus = [response[key] isKindOfClass:NSDictionary.class] ? response[key] : nil;
  if (nestedStatus) {
    return nestedStatus;
  }

  if ([response[@"state"] isKindOfClass:NSString.class] ||
      [response[booleanName] isKindOfClass:NSNumber.class]) {
    return response;
  }

  NSString* errorMessage = [response[@"error"] isKindOfClass:NSString.class] ? response[@"error"] : @"";
  if (errorMessage.length > 0) {
    return @{
      booleanName : @NO,
      @"state" : failureState ?: @"failed",
      @"messages" : @[ errorMessage ]
    };
  }

  return nil;
}

- (NSDictionary*)runtimeStatusByAddingPrewarmStatus:(NSDictionary*)runtimeStatus
                                   moduleIdentifier:(NSString*)moduleIdentifier {
  NSDictionary* prewarmStatus =
      [nativePrewarmCoordinator_ prewarmStatusForModuleIdentifier:moduleIdentifier];
  if (!prewarmStatus || runtimeStatus.count == 0) {
    return runtimeStatus;
  }

  NSMutableDictionary* enrichedStatus = [runtimeStatus mutableCopy];
  enrichedStatus[@"prewarmStatus"] = prewarmStatus;
  return enrichedStatus;
}

- (NSDictionary*)moduleRouteForBabelChromeComponents:(NSURLComponents*)components
                                               error:(NSError**)error {
  NSError* nativeError = nil;
  NSDictionary* snapshot = [nativeModuleRegistry_ modulesSnapshotWithError:&nativeError];
  if (!snapshot) {
    snapshot = [self modulesSnapshotWithError:error];
  }

  if (!snapshot) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme ?: @"";
  NSString* host = components.host ?: @"";
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      NSString* routeHandler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
      if ([routeScheme isEqualToString:scheme] && [routeHost isEqualToString:host] &&
          moduleIdentifier.length > 0 && routeHandler.length > 0) {
        return @{
          @"moduleIdentifier" : moduleIdentifier,
          @"route" : routeHandler
        };
      }
    }
  }

  return nil;
}

- (NSString*)moduleIdentifierForBabelChromeComponents:(NSURLComponents*)components {
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  if ([components.host isEqualToString:@"modules"]) {
    NSArray<NSString*>* pathComponents = [components.path pathComponents];
    if (pathComponents.count >= 3) {
      return pathComponents[1];
    }
  }

  NSError* error = nil;
  NSDictionary* route = [self moduleRouteForBabelChromeComponents:components error:&error];
  return [route[@"moduleIdentifier"] isKindOfClass:NSString.class] ? route[@"moduleIdentifier"] : nil;
}

- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                           error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module && module.enabled &&
      ([module.runtimeType isEqualToString:@"process-web"] || [module.runtimeType isEqualToString:@"process-runtime"])) {
    return [nativeModuleHTTPHost_ moduleURLForIdentifier:moduleIdentifier
                                                   route:route
                                         sourceURLString:sourceURLString
                                                   error:error];
  }

  return [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                           route:route
                                                 sourceURLString:sourceURLString
                                                           error:error];
}

- (BOOL)supportsViewerURL:(NSURL*)url {
  return [nativeModuleRegistry_ viewerRouteForURL:url error:nil] != nil;
}

- (NSString*)viewerKindForURL:(NSURL*)url {
  NSDictionary* route = [nativeModuleRegistry_ viewerRouteForURL:url error:nil];
  return [route[@"viewerKind"] isKindOfClass:NSString.class] ? route[@"viewerKind"] : nil;
}

- (NSString*)viewerModuleIdentifierForURL:(NSURL*)url {
  NSDictionary* route = [nativeModuleRegistry_ viewerRouteForURL:url error:nil];
  return [route[@"moduleIdentifier"] isKindOfClass:NSString.class] ? route[@"moduleIdentifier"] : nil;
}

- (NSURL*)viewerURLForURL:(NSURL*)url
            markdownTheme:(NSString*)markdownTheme
                    error:(NSError**)error {
  NSDictionary* route = [nativeModuleRegistry_ viewerRouteForURL:url error:error];
  NSString* moduleIdentifier = [route[@"moduleIdentifier"] isKindOfClass:NSString.class]
      ? route[@"moduleIdentifier"]
      : @"";
  NSString* handler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
  NSString* viewerKind = [route[@"viewerKind"] isKindOfClass:NSString.class] ? route[@"viewerKind"] : @"";
  if (moduleIdentifier.length == 0 || handler.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceType = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* sourceIdentifier = [viewerSourceRegistry_ registerSourceWithType:sourceType
                                                                       value:sourceValue
                                                                       error:error];
  if (sourceIdentifier.length == 0) {
    return nil;
  }

  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"sourceId" value:sourceIdentifier]];
  if ([sourceType isEqualToString:@"file"]) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"file" value:sourceValue]];
  } else {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"url" value:sourceValue]];
  }
  if ([viewerKind isEqualToString:@"markdown"] && markdownTheme.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"theme" value:markdownTheme]];
  }

  return [nativeModuleHTTPHost_ moduleURLForIdentifier:moduleIdentifier
                                                 route:handler
                                       sourceURLString:url.absoluteString
                                            queryItems:queryItems
                                                 error:error];
}

- (NSDictionary*)addressBadgeForStableViewerURL:(NSURL*)stableViewerURL {
  NSURL* sourceURL = [stableViewerURLResolver_ sourceURLForViewerURLString:stableViewerURL.absoluteString];
  if (!sourceURL) {
    return nil;
  }

  return [nativeModuleRegistry_ addressBadgeForViewerURL:sourceURL error:nil];
}

- (NSString*)localServiceModuleIdentifierForURLComponents:(NSURLComponents*)components {
  NSString* scheme = components.scheme.lowercaseString ?: @"";
  NSString* host = components.host.lowercaseString ?: @"";
  if ((![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) ||
      ![host isEqualToString:@"127.0.0.1"]) {
    return nil;
  }

  NSArray<NSString*>* pathComponents = [components.path pathComponents];
  if (pathComponents.count < 3 || ![pathComponents[1] isEqualToString:@"module"]) {
    return nil;
  }

  return pathComponents[2];
}

- (NSString*)defaultGroupNameForModuleIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return nil;
  }

  NSError* error = nil;
  NSDictionary* snapshot = [nativeModuleRegistry_ modulesSnapshotWithError:&error];
  if (!snapshot || error) {
    error = nil;
    snapshot = [self modulesSnapshotWithError:&error];
  }

  if (!snapshot || error) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* identifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (![identifier isEqualToString:moduleIdentifier]) {
      continue;
    }

    NSString* defaultGroup = [module[@"defaultGroup"] isKindOfClass:NSString.class]
        ? [module[@"defaultGroup"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    return defaultGroup.length > 0 ? defaultGroup : nil;
  }

  return nil;
}

- (BOOL)moduleWithIdentifierUsesPrewarmStartPolicy:(NSString*)moduleIdentifier {
  NSError* error = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&error];
  return [self moduleUsesPrewarmStartPolicy:module];
}

- (NSDictionary*)prewarmModuleWithIdentifierIfNeeded:(NSString*)moduleIdentifier
                                               error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (!module || ![self moduleUsesPrewarmStartPolicy:module]) {
    if (error && nativeError) {
      *error = nativeError;
    }
    return nil;
  }

  return [nativePrewarmCoordinator_ prewarmModule:module error:error];
}

- (void)schedulePrewarmModulesExcludingIdentifiers:(NSSet<NSString*>*)excludedIdentifiers {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSError* error = nil;
    NSArray<BabelNativeModuleManifest*>* modules = [nativeModuleRegistry_ enabledModulesWithError:&error];
    if (!modules) {
      if (error) {
        NSLog(@"BabelChrome module prewarm discovery failed: %@", error.localizedDescription);
      }
      return;
    }

    NSMutableArray<BabelNativeModuleManifest*>* eligibleModules = [NSMutableArray array];
    for (BabelNativeModuleManifest* module in modules) {
      if (![self moduleUsesPrewarmStartPolicy:module] ||
          ![self moduleReadinessAllowsPrewarm:module]) {
        continue;
      }

      [eligibleModules addObject:module];
    }

    [nativePrewarmCoordinator_ schedulePrewarmModules:eligibleModules
                                 excludingIdentifiers:excludedIdentifiers ?: [NSSet set]];
  });
}

- (BOOL)moduleUsesPrewarmStartPolicy:(BabelNativeModuleManifest*)module {
  return module.enabled &&
         [module.runtimeType isEqualToString:@"process-web"] &&
         [module.processWeb.startPolicy isEqualToString:@"prewarm"];
}

- (BOOL)moduleReadinessAllowsPrewarm:(BabelNativeModuleManifest*)module {
  if (module.readiness.count == 0) {
    return YES;
  }

  NSDictionary* readinessResponse =
      [BabelLocalServiceHost.sharedHost readinessStatusForModuleWithIdentifier:module.moduleIdentifier
                                                                         error:nil];
  NSDictionary* readinessStatus = [self moduleDiagnosticStatusFromResponse:readinessResponse
                                                                       key:@"readinessStatus"
                                                              failureState:@"failed"
                                                               booleanName:@"ready"];
  NSNumber* ready = [readinessStatus[@"ready"] isKindOfClass:NSNumber.class] ? readinessStatus[@"ready"] : nil;
  return ready ? [ready boolValue] : NO;
}

- (BOOL)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error {
  NSString* moduleIdentifier = [nativeModuleInstaller_ moduleIdentifierInZipAtPath:zipPath
                                                                             error:nil];
  if (moduleIdentifier.length > 0) {
    [self stopRuntimeForMutationOfModuleWithIdentifier:moduleIdentifier];
  }

  if ([nativeModuleInstaller_ installModuleZipAtPath:zipPath error:error]) {
    [nativeModuleRegistry_ reload];
    return YES;
  }

  return NO;
}

- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled error:(NSError**)error {
  if (!enabled) {
    [self stopRuntimeForMutationOfModuleWithIdentifier:moduleIdentifier];
  }

  if ([nativeModuleInstaller_ setModuleWithIdentifier:moduleIdentifier enabled:enabled error:error]) {
    [nativeModuleRegistry_ reload];
    return YES;
  }

  return NO;
}

- (BOOL)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  [self stopRuntimeForMutationOfModuleWithIdentifier:moduleIdentifier];

  if ([nativeModuleInstaller_ removeModuleWithIdentifier:moduleIdentifier error:error]) {
    [nativeModuleRegistry_ reload];
    return YES;
  }

  return NO;
}

- (NSDictionary*)setupModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost setupModuleWithIdentifier:moduleIdentifier error:error];
}

- (NSDictionary*)readinessStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost readinessStatusForModuleWithIdentifier:moduleIdentifier error:error];
}

- (NSDictionary*)runtimeStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module &&
      ([module.runtimeType isEqualToString:@"process-web"] || [module.runtimeType isEqualToString:@"process-runtime"])) {
    return [nativeProcessRuntimeManager_ runtimeStatusForModule:module];
  }

  NSError* hostError = nil;
  NSDictionary* hostStatus = [BabelLocalServiceHost.sharedHost runtimeStatusForModuleWithIdentifier:moduleIdentifier
                                                                                              error:&hostError];
  if (hostStatus) {
    return hostStatus;
  }

  if (module) {
    return [nativeProcessRuntimeManager_ runtimeStatusForModule:module];
  }

  if (error) {
    *error = nativeError ?: hostError;
  }
  return nil;
}

- (NSDictionary*)restartRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module && [module.runtimeType isEqualToString:@"process-web"]) {
    return [nativeProcessRuntimeManager_ restartProcessWebRuntimeForModule:module error:error];
  }

  return [BabelLocalServiceHost.sharedHost restartRuntimeForModuleWithIdentifier:moduleIdentifier error:error];
}

- (NSDictionary*)stopRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module &&
      ([module.runtimeType isEqualToString:@"process-web"] || [module.runtimeType isEqualToString:@"process-runtime"])) {
    return [nativeProcessRuntimeManager_ stopRuntimeForModule:module error:error];
  }

  return [BabelLocalServiceHost.sharedHost stopRuntimeForModuleWithIdentifier:moduleIdentifier error:error];
}

- (void)stopRuntimeForMutationOfModuleWithIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return;
  }

  NSError* stopError = nil;
  [nativeProcessRuntimeManager_ stopRuntimeForModuleIdentifier:moduleIdentifier];
  [BabelLocalServiceHost.sharedHost stopRuntimeForModuleWithIdentifier:moduleIdentifier error:&stopError];
}

@end
