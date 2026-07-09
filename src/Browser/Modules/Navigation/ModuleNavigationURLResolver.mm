#import "Browser/Modules/Navigation/ModuleNavigationURLResolver.h"

#import "Browser/Modules/Core/ModuleActionService.h"

@implementation BabelModuleNavigationURLResolver {
  BabelModuleActionService* moduleActionService_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
  }
  return self;
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* moduleIdentifier = nil;
  NSString* route = nil;
  NSString* sourceURLString = nil;
  if ([components.host isEqualToString:@"modules"]) {
    NSArray<NSString*>* pathComponents = [components.path pathComponents];
    if (pathComponents.count >= 3) {
      moduleIdentifier = pathComponents[1];
      route = pathComponents[2];
    }
  } else {
    NSError* error = nil;
    NSDictionary* moduleRoute =
        [moduleActionService_ moduleRouteForBabelChromeComponents:components error:&error];
    if (!moduleRoute) {
      return nil;
    }

    moduleIdentifier =
        [moduleRoute[@"moduleIdentifier"] isKindOfClass:NSString.class] ? moduleRoute[@"moduleIdentifier"] : @"";
    route = [moduleRoute[@"route"] isKindOfClass:NSString.class] ? moduleRoute[@"route"] : @"";
    sourceURLString = urlString;
  }

  if (moduleIdentifier.length == 0 || route.length == 0) {
    return nil;
  }

  NSError* error = nil;
  NSURL* moduleURL = [moduleActionService_ moduleURLForIdentifier:moduleIdentifier
                                                            route:route
                                                  sourceURLString:sourceURLString
                                                            error:&error];
  return moduleURL.absoluteString;
}

@end
