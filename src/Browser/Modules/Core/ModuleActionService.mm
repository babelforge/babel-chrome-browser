#import "Browser/Modules/Core/ModuleActionService.h"

#import "Browser/Modules/Installation/NativeModuleInstaller.h"
#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Modules/Runtime/NativeModuleHTTPHost.h"
#import "Browser/Modules/Runtime/NativeModulePrewarmCoordinator.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"
#import "Browser/Modules/Settings/NativeModuleRequiredSettingsService.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"
#import "Browser/Navigation/Viewer/ViewerSourceRegistry.h"

static NSString* const kBabelModuleActionServiceErrorDomain =
    @"fr.babelforge.babel-chrome.module-action-service";

@implementation BabelModuleActionService {
  BabelNativeModuleRegistry* nativeModuleRegistry_;
  BabelNativeModuleInstaller* nativeModuleInstaller_;
  BabelNativeModuleRequiredSettingsService* nativeRequiredSettingsService_;
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
    nativeRequiredSettingsService_ =
        [[BabelNativeModuleRequiredSettingsService alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults];
    nativeProcessRuntimeManager_ =
        [[BabelNativeModuleProcessRuntimeManager alloc] initWithRequiredSettingsService:nativeRequiredSettingsService_];
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

  if (error) {
    *error = nativeError;
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
      if (nativeModule) {
        NSDictionary* readinessResponse = [self readinessStatusForNativeModule:nativeModule error:nil];
        readinessStatus = [self moduleDiagnosticStatusFromResponse:readinessResponse
                                                               key:@"readinessStatus"
                                                      failureState:@"failed"
                                                       booleanName:@"ready"];
      }
    }
    if (nativeModule) {
      runtimeStatus = [nativeProcessRuntimeManager_ runtimeStatusForModule:nativeModule];
      runtimeStatus = [self runtimeStatusByAddingPrewarmStatus:runtimeStatus
                                              moduleIdentifier:moduleIdentifier];
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
    if (error) {
      *error = nativeError;
    }
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
    if (![nativeRequiredSettingsService_ requiredSettingsAreSatisfiedForModule:module]) {
      return [nativeRequiredSettingsService_ settingsURLForModule:module];
    }
    return [nativeModuleHTTPHost_ moduleURLForIdentifier:moduleIdentifier
                                                   route:route
                                         sourceURLString:sourceURLString
                                                   error:error];
  }

  [self assignError:error
        description:[NSString stringWithFormat:@"Module \"%@\" runtime \"%@\" cannot expose native module URLs.",
                                               moduleIdentifier ?: @"",
                                               module.runtimeType ?: @"unknown"]];
  return nil;
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

- (NSString*)viewerModuleIdentifierForURL:(NSURL*)url preferredViewerKind:(NSString*)preferredViewerKind {
  NSDictionary* route = [nativeModuleRegistry_ viewerRouteForURL:url
                                             preferredViewerKind:preferredViewerKind
                                                          error:nil];
  return [route[@"moduleIdentifier"] isKindOfClass:NSString.class] ? route[@"moduleIdentifier"] : nil;
}

- (NSURL*)viewerURLForURL:(NSURL*)url
            markdownTheme:(NSString*)markdownTheme
                    error:(NSError**)error {
  return [self viewerURLForURL:url preferredViewerKind:nil markdownTheme:markdownTheme error:error];
}

- (NSURL*)viewerURLForURL:(NSURL*)url
      preferredViewerKind:(NSString*)preferredViewerKind
            markdownTheme:(NSString*)markdownTheme
                    error:(NSError**)error {
  NSDictionary* route = [nativeModuleRegistry_ viewerRouteForURL:url
                                             preferredViewerKind:preferredViewerKind
                                                          error:error];
  NSString* moduleIdentifier = [route[@"moduleIdentifier"] isKindOfClass:NSString.class]
      ? route[@"moduleIdentifier"]
      : @"";
  NSString* handler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
  NSString* viewerKind = [route[@"viewerKind"] isKindOfClass:NSString.class] ? route[@"viewerKind"] : @"";
  if (moduleIdentifier.length == 0 || handler.length == 0) {
    return nil;
  }

  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier error:nil];
  if (module && ![nativeRequiredSettingsService_ requiredSettingsAreSatisfiedForModule:module]) {
    return [nativeRequiredSettingsService_ settingsURLForModule:module];
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
  return [nativeRequiredSettingsService_ requiredSettingsAreSatisfiedForModule:module];
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
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (!module) {
    if (error) {
      *error = nativeError;
    }
    return nil;
  }

  NSDictionary* setupResult = [self setupResultForNativeModule:module error:error];
  if (!setupResult) {
    return nil;
  }

  return @{
    @"ok" : @YES,
    @"setup" : setupResult,
    @"readinessStatus" : [self readinessStatusForNativeModule:module error:nil][@"readinessStatus"] ?: @{}
  };
}

- (NSDictionary*)readinessStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module) {
    return [self readinessStatusForNativeModule:module error:error];
  }

  if (error) {
    *error = nativeError;
  }
  return nil;
}

- (NSDictionary*)runtimeStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module &&
      ([module.runtimeType isEqualToString:@"process-web"] || [module.runtimeType isEqualToString:@"process-runtime"])) {
    return [nativeProcessRuntimeManager_ runtimeStatusForModule:module];
  }

  if (module) {
    return [nativeProcessRuntimeManager_ runtimeStatusForModule:module];
  }

  if (error) {
    *error = nativeError;
  }
  return nil;
}

- (NSDictionary*)requiredSettingsStatusForModuleWithIdentifier:(NSString*)moduleIdentifier
                                                        error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (!module) {
    if (error) {
      *error = nativeError;
    }
    return nil;
  }

  return [nativeRequiredSettingsService_ statusForModule:module];
}

- (BOOL)setRequiredSettingValue:(NSString*)value
                         forKey:(NSString*)key
           moduleWithIdentifier:(NSString*)moduleIdentifier
                          error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (!module) {
    if (error) {
      *error = nativeError;
    }
    return NO;
  }

  BOOL didSave = [nativeRequiredSettingsService_ setValue:value forKey:key module:module error:error];
  if (didSave) {
    [nativeProcessRuntimeManager_ stopRuntimeForModuleIdentifier:moduleIdentifier];
  }
  return didSave;
}

- (NSDictionary*)restartRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module && [module.runtimeType isEqualToString:@"process-web"]) {
    return [nativeProcessRuntimeManager_ restartProcessWebRuntimeForModule:module error:error];
  }

  [self assignError:error
        description:[NSString stringWithFormat:@"Module \"%@\" runtime cannot be restarted natively.",
                                               moduleIdentifier ?: @""]];
  return nil;
}

- (NSDictionary*)stopRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module &&
      ([module.runtimeType isEqualToString:@"process-web"] || [module.runtimeType isEqualToString:@"process-runtime"])) {
    return [nativeProcessRuntimeManager_ stopRuntimeForModule:module error:error];
  }

  [self assignError:error
        description:[NSString stringWithFormat:@"Module \"%@\" runtime cannot be stopped natively.",
                                               moduleIdentifier ?: @""]];
  return nil;
}

- (void)stopRuntimeForMutationOfModuleWithIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return;
  }

  [nativeProcessRuntimeManager_ stopRuntimeForModuleIdentifier:moduleIdentifier];
}

- (NSDictionary*)dispatchModuleLifecycleHook:(NSString*)hook error:(NSError**)error {
  NSString* normalizedHook =
      [hook stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (normalizedHook.length == 0) {
    [self assignError:error description:@"Missing module lifecycle hook."];
    return nil;
  }

  NSError* nativeError = nil;
  NSArray<BabelNativeModuleManifest*>* modules = [nativeModuleRegistry_ enabledModulesWithError:&nativeError];
  if (!modules) {
    if (error) {
      *error = nativeError;
    }
    return nil;
  }

  NSMutableArray<NSDictionary*>* results = [NSMutableArray array];
  for (BabelNativeModuleManifest* module in modules) {
    if (![module.hooks containsObject:normalizedHook]) {
      continue;
    }

    NSString* route = [self lifecycleRouteForModule:module];
    if (route.length == 0) {
      [results addObject:@{
        @"moduleId" : module.moduleIdentifier ?: @"",
        @"ok" : @NO,
        @"error" : @"Module declares the lifecycle hook but no internal lifecycle route."
      }];
      continue;
    }

    NSError* routeError = nil;
    NSURL* url = [nativeModuleHTTPHost_ moduleURLForIdentifier:module.moduleIdentifier
                                                         route:route
                                               sourceURLString:nil
                                                    queryItems:@[
                                                      [NSURLQueryItem queryItemWithName:@"hook"
                                                                                 value:normalizedHook]
                                                    ]
                                                         error:&routeError];
    NSDictionary* payload = url ? [self JSONDictionaryFromURL:url error:&routeError] : nil;
    if (!payload) {
      [results addObject:@{
        @"moduleId" : module.moduleIdentifier ?: @"",
        @"ok" : @NO,
        @"error" : routeError.localizedDescription ?: @"Lifecycle route failed."
      }];
      continue;
    }

    [results addObject:@{
      @"moduleId" : module.moduleIdentifier ?: @"",
      @"ok" : @YES,
      @"payload" : payload
    }];
  }

  return @{
    @"ok" : @YES,
    @"hook" : normalizedHook,
    @"results" : results
  };
}

- (NSDictionary*)readinessStatusForNativeModule:(BabelNativeModuleManifest*)module error:(NSError**)error {
  NSDictionary* requiredSettingsStatus = [nativeRequiredSettingsService_ statusForModule:module];
  NSMutableDictionary* status = [requiredSettingsStatus mutableCopy];
  status[@"canSetup"] = @(module.setup.count > 0);

  if (![requiredSettingsStatus[@"ready"] boolValue]) {
    return @{
      @"ok" : @YES,
      @"readinessStatus" : status
    };
  }

  if (module.readiness.count == 0) {
    return @{
      @"ok" : @YES,
      @"readinessStatus" : status
    };
  }

  NSDictionary* readiness = module.readiness;
  NSString* type = [readiness[@"type"] isKindOfClass:NSString.class] ? readiness[@"type"] : @"";
  if (![type isEqualToString:@"command"]) {
    status[@"ready"] = @NO;
    status[@"state"] = @"unsupported";
    status[@"messages"] = @[ [NSString stringWithFormat:@"Unsupported readiness type \"%@\".", type ?: @""] ];
    return @{
      @"ok" : @YES,
      @"readinessStatus" : status
    };
  }

  NSError* commandError = nil;
  NSDictionary* execution = [nativeProcessRuntimeManager_ runManifestCommand:readiness
                                                                    forModule:module
                                                             defaultTimeoutMs:5000
                                                                         error:&commandError];
  if (!execution) {
    status[@"ready"] = @NO;
    status[@"state"] = @"failed";
    status[@"messages"] = @[ commandError.localizedDescription ?: @"Readiness command failed." ];
    return @{
      @"ok" : @YES,
      @"readinessStatus" : status
    };
  }

  NSDictionary* commandStatus = [self readinessStatusFromCommandExecution:execution
                                                                 module:module
                                                              readiness:readiness];
  return @{
    @"ok" : @YES,
    @"readinessStatus" : commandStatus
  };
}

- (NSDictionary*)setupResultForNativeModule:(BabelNativeModuleManifest*)module error:(NSError**)error {
  if (module.setup.count == 0) {
    return @{
      @"ok" : @NO,
      @"state" : @"missing-setup",
      @"messages" : @[ @"Module does not declare a setup command." ],
      @"stdout" : @"",
      @"stderr" : @"",
      @"exitCode" : [NSNull null],
      @"timedOut" : @NO
    };
  }

  NSError* commandError = nil;
  NSDictionary* execution = [nativeProcessRuntimeManager_ runManifestCommand:module.setup
                                                                    forModule:module
                                                             defaultTimeoutMs:600000
                                                                         error:&commandError];
  if (!execution) {
    if (error) {
      *error = commandError;
    }
    return nil;
  }

  return [self setupResultFromCommandExecution:execution setup:module.setup];
}

- (NSDictionary*)readinessStatusFromCommandExecution:(NSDictionary*)execution
                                              module:(BabelNativeModuleManifest*)module
                                           readiness:(NSDictionary*)readiness {
  if ([execution[@"timedOut"] boolValue]) {
    NSInteger timeoutMs = [readiness[@"timeoutMs"] isKindOfClass:NSNumber.class] ? [readiness[@"timeoutMs"] integerValue] : 5000;
    return @{
      @"state" : @"timeout",
      @"ready" : @NO,
      @"messages" : @[ [NSString stringWithFormat:@"Readiness command timed out after %ld ms.",
                                                  static_cast<long>(timeoutMs)] ],
      @"canSetup" : @(module.setup.count > 0),
      @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
      @"stderr" : execution[@"stderr"] ?: @""
    };
  }

  NSString* stdoutText = [execution[@"stdout"] isKindOfClass:NSString.class] ? execution[@"stdout"] : @"";
  NSDictionary* decoded = [self JSONDictionaryFromString:stdoutText];
  if (!decoded) {
    NSInteger exitCode = [execution[@"exitCode"] isKindOfClass:NSNumber.class] ? [execution[@"exitCode"] integerValue] : -1;
    return @{
      @"state" : exitCode == 0 ? @"invalid-output" : @"failed",
      @"ready" : @NO,
      @"messages" : @[ @"Readiness command did not return a JSON object." ],
      @"canSetup" : @(module.setup.count > 0),
      @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
      @"stderr" : execution[@"stderr"] ?: @""
    };
  }

  BOOL ready = [decoded[@"ready"] boolValue];
  NSString* state = [decoded[@"status"] isKindOfClass:NSString.class]
      ? decoded[@"status"]
      : ready ? @"ready" : @"not-ready";
  NSArray* messages = [decoded[@"messages"] isKindOfClass:NSArray.class] ? decoded[@"messages"] : @[];
  id canSetup = [decoded[@"canSetup"] isKindOfClass:NSNumber.class] ? decoded[@"canSetup"] : @(module.setup.count > 0);

  return @{
    @"state" : state.length > 0 ? state : @"unknown",
    @"ready" : @(ready),
    @"messages" : [self stringListFromArray:messages],
    @"canSetup" : canSetup,
    @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
    @"stderr" : execution[@"stderr"] ?: @""
  };
}

- (NSDictionary*)setupResultFromCommandExecution:(NSDictionary*)execution setup:(NSDictionary*)setup {
  if ([execution[@"timedOut"] boolValue]) {
    NSInteger timeoutMs = [setup[@"timeoutMs"] isKindOfClass:NSNumber.class] ? [setup[@"timeoutMs"] integerValue] : 600000;
    return @{
      @"ok" : @NO,
      @"state" : @"timeout",
      @"messages" : @[ [NSString stringWithFormat:@"Setup command timed out after %ld ms.",
                                                  static_cast<long>(timeoutMs)] ],
      @"stdout" : execution[@"stdout"] ?: @"",
      @"stderr" : execution[@"stderr"] ?: @"",
      @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
      @"timedOut" : @YES
    };
  }

  NSString* stdoutText = [execution[@"stdout"] isKindOfClass:NSString.class] ? execution[@"stdout"] : @"";
  NSDictionary* decoded = [self JSONDictionaryFromString:stdoutText];
  if (decoded) {
    BOOL ok = [decoded[@"ok"] isKindOfClass:NSNumber.class]
        ? [decoded[@"ok"] boolValue]
        : [execution[@"exitCode"] integerValue] == 0;
    NSString* state = [decoded[@"status"] isKindOfClass:NSString.class]
        ? decoded[@"status"]
        : ok ? @"completed" : @"failed";
    NSArray* messages = [decoded[@"messages"] isKindOfClass:NSArray.class] ? decoded[@"messages"] : @[];
    return @{
      @"ok" : @(ok),
      @"state" : state.length > 0 ? state : @"unknown",
      @"messages" : [self stringListFromArray:messages],
      @"stdout" : execution[@"stdout"] ?: @"",
      @"stderr" : execution[@"stderr"] ?: @"",
      @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
      @"timedOut" : @NO
    };
  }

  BOOL ok = [execution[@"exitCode"] integerValue] == 0;
  return @{
    @"ok" : @(ok),
    @"state" : ok ? @"completed" : @"failed",
    @"messages" : @[ ok ? @"Setup command completed." : @"Setup command failed." ],
    @"stdout" : execution[@"stdout"] ?: @"",
    @"stderr" : execution[@"stderr"] ?: @"",
    @"exitCode" : execution[@"exitCode"] ?: [NSNull null],
    @"timedOut" : @NO
  };
}

- (NSString*)lifecycleRouteForModule:(BabelNativeModuleManifest*)module {
  for (NSDictionary* route in module.routes) {
    NSString* scheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
    NSString* handler = [route[@"handler"] isKindOfClass:NSString.class] ? route[@"handler"] : @"";
    if ([scheme isEqualToString:@"babelchrome-internal"] && handler.length > 0) {
      return handler;
    }
  }

  return @"";
}

- (NSDictionary*)JSONDictionaryFromURL:(NSURL*)url error:(NSError**)error {
  NSData* data = [NSData dataWithContentsOfURL:url options:0 error:error];
  if (data.length == 0) {
    [self assignError:error description:@"Module route returned an empty response."];
    return nil;
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![decoded isKindOfClass:NSDictionary.class]) {
    [self assignError:error description:@"Module route returned an invalid JSON response."];
    return nil;
  }

  return decoded;
}

- (NSDictionary*)JSONDictionaryFromString:(NSString*)string {
  NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
  if (!data) {
    return nil;
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : nil;
}

- (NSArray<NSString*>*)stringListFromArray:(NSArray*)array {
  NSMutableArray<NSString*>* strings = [NSMutableArray array];
  for (id item in array ?: @[]) {
    if ([item isKindOfClass:NSString.class] && [item length] > 0) {
      [strings addObject:item];
    }
  }
  return strings;
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelModuleActionServiceErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Module action failed."}];
}

@end
