#import "Browser/Modules/Core/ModuleActionService.h"

#import "LocalServices/LocalServiceHost.h"

@implementation BabelModuleActionService

- (NSDictionary*)modulesSnapshotWithError:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:error];
}

- (NSDictionary*)moduleRouteForBabelChromeComponents:(NSURLComponents*)components
                                               error:(NSError**)error {
  NSDictionary* snapshot = [self modulesSnapshotWithError:error];
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
  NSDictionary* snapshot = [self modulesSnapshotWithError:&error];
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
  NSDictionary* response = [BabelLocalServiceHost.sharedHost installModuleZipAtPath:zipPath
                                                                              error:error];
  return response != nil;
}

- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled error:(NSError**)error {
  NSDictionary* response = [BabelLocalServiceHost.sharedHost setModuleWithIdentifier:moduleIdentifier
                                                                             enabled:enabled
                                                                               error:error];
  return response != nil;
}

- (BOOL)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  NSDictionary* response = [BabelLocalServiceHost.sharedHost removeModuleWithIdentifier:moduleIdentifier
                                                                                  error:error];
  return response != nil;
}

- (NSDictionary*)setupModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error {
  return [BabelLocalServiceHost.sharedHost setupModuleWithIdentifier:moduleIdentifier error:error];
}

@end
