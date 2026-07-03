#import "Browser/TabURLMatcher.h"

#import "Browser/BrowserModels.h"

@implementation BabelTabURLMatcher

- (BOOL)tab:(BabelBrowserTab*)tab matchesURLString:(NSString*)urlString {
  if ([tab.urlString isEqualToString:urlString] ||
      [tab.requestedURLString isEqualToString:urlString]) {
    return YES;
  }

  NSString* normalizedURLString = [self URLStringByRemovingTrailingSlash:urlString];
  if ([[self URLStringByRemovingTrailingSlash:tab.urlString] isEqualToString:normalizedURLString] ||
      [[self URLStringByRemovingTrailingSlash:tab.requestedURLString] isEqualToString:normalizedURLString]) {
    return YES;
  }

  return [self rootURLString:urlString matchesURLString:tab.urlString] ||
         [self rootURLString:urlString matchesURLString:tab.requestedURLString];
}

- (NSString*)URLStringByRemovingTrailingSlash:(NSString*)urlString {
  if (urlString.length > 1 && [urlString hasSuffix:@"/"]) {
    return [urlString substringToIndex:urlString.length - 1];
  }
  return urlString ?: @"";
}

- (BOOL)rootURLString:(NSString*)rootURLString matchesURLString:(NSString*)candidateURLString {
  NSURLComponents* rootComponents = [NSURLComponents componentsWithString:rootURLString];
  NSURLComponents* candidateComponents = [NSURLComponents componentsWithString:candidateURLString];
  if (rootComponents.scheme.length == 0 || candidateComponents.scheme.length == 0) {
    return NO;
  }

  NSString* rootPath = rootComponents.path ?: @"";
  if (rootPath.length > 0 && ![rootPath isEqualToString:@"/"]) {
    return NO;
  }

  BOOL sameScheme = [rootComponents.scheme isEqualToString:candidateComponents.scheme];
  BOOL sameHost = [rootComponents.host isEqualToString:candidateComponents.host];
  NSNumber* rootPort = rootComponents.port ?: @([rootComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  NSNumber* candidatePort = candidateComponents.port ?:
      @([candidateComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  return sameScheme && sameHost && [rootPort isEqualToNumber:candidatePort];
}

@end
