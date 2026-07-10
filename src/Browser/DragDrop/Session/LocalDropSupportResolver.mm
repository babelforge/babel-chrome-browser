#import "Browser/DragDrop/Session/LocalDropSupportResolver.h"

#import "Browser/Modules/Core/ModuleActionService.h"

@implementation BabelLocalDropSupportResolver {
  BabelModuleActionService* moduleActionService_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
  }
  return self;
}

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString {
  if (urlString.length == 0) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (!components) {
    return NO;
  }

  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  if (!snapshot || error) {
    return NO;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* scheme = components.scheme.lowercaseString ?: @"";
  NSString* host = components.host.lowercaseString ?: @"";
  NSString* localModuleIdentifier = [moduleActionService_ localServiceModuleIdentifierForURLComponents:components];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class] || ![module[@"enabled"] boolValue]) {
      continue;
    }

    NSArray* hooks = [module[@"hooks"] isKindOfClass:NSArray.class] ? module[@"hooks"] : @[];
    if (![hooks containsObject:@"drop.local-paths"]) {
      continue;
    }

    NSString* moduleIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (localModuleIdentifier.length > 0 && [moduleIdentifier isEqualToString:localModuleIdentifier]) {
      return YES;
    }

    NSArray* routes = [module[@"routes"] isKindOfClass:NSArray.class] ? module[@"routes"] : @[];
    for (NSDictionary* route in routes) {
      if (![route isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* routeScheme = [route[@"scheme"] isKindOfClass:NSString.class] ? route[@"scheme"] : @"";
      NSString* routeHost = [route[@"host"] isKindOfClass:NSString.class] ? route[@"host"] : @"";
      if ([routeScheme.lowercaseString isEqualToString:scheme] &&
          [routeHost.lowercaseString isEqualToString:host]) {
        return YES;
      }
    }
  }

  return NO;
}

@end
