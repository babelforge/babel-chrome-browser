#import "Browser/LocalServiceURLClassifier.h"

@implementation BabelLocalServiceURLClassifier

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path hasPrefix:@"/module/"];
}

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.host isEqualToString:@"127.0.0.1"] ||
      (![components.scheme isEqualToString:@"http"] && ![components.scheme isEqualToString:@"https"])) {
    return NO;
  }

  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:@"token"] && item.value.length > 0) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  return ([components.scheme isEqualToString:@"http"] || [components.scheme isEqualToString:@"https"]) &&
         [components.host isEqualToString:@"127.0.0.1"] &&
         [path isEqualToString:@"/module/babelforge.project-launcher/index"];
}

@end

