#import "Browser/Modules/Core/ModuleActionService.h"

#import "Browser/Modules/Installation/NativeModuleInstaller.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"
#import "LocalServices/LocalServiceHost.h"

@implementation BabelModuleActionService {
  BabelNativeModuleRegistry* nativeModuleRegistry_;
  BabelNativeModuleInstaller* nativeModuleInstaller_;
  BabelNativeModuleProcessRuntimeManager* nativeProcessRuntimeManager_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    nativeModuleRegistry_ = [[BabelNativeModuleRegistry alloc] init];
    nativeModuleInstaller_ =
        [[BabelNativeModuleInstaller alloc] initWithModulesDirectoryPath:nativeModuleRegistry_.modulesDirectoryPath];
    nativeProcessRuntimeManager_ = [[BabelNativeModuleProcessRuntimeManager alloc] init];
  }

  return self;
}

- (NSDictionary*)modulesSnapshotWithError:(NSError**)error {
  NSError* nativeError = nil;
  NSDictionary* nativeSnapshot = [nativeModuleRegistry_ modulesSnapshotWithError:&nativeError];
  if (nativeSnapshot) {
    return nativeSnapshot;
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
  NSError* hostError = nil;
  NSDictionary* hostStatus = [BabelLocalServiceHost.sharedHost runtimeStatusForModuleWithIdentifier:moduleIdentifier
                                                                                              error:&hostError];
  if (hostStatus) {
    return hostStatus;
  }

  NSError* nativeError = nil;
  BabelNativeModuleManifest* module = [nativeModuleRegistry_ moduleWithIdentifier:moduleIdentifier
                                                                            error:&nativeError];
  if (module) {
    return [nativeProcessRuntimeManager_ runtimeStatusForModule:module];
  }

  if (error) {
    *error = nativeError ?: hostError;
  }
  return nil;
}

- (NSDictionary*)restartRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost restartRuntimeForModuleWithIdentifier:moduleIdentifier error:error];
}

- (NSDictionary*)stopRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost stopRuntimeForModuleWithIdentifier:moduleIdentifier error:error];
}

- (void)stopRuntimeForMutationOfModuleWithIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return;
  }

  NSError* stopError = nil;
  [BabelLocalServiceHost.sharedHost stopRuntimeForModuleWithIdentifier:moduleIdentifier error:&stopError];
}

@end
