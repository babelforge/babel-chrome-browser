#import "Browser/Navigation/StableURLs/StableServerURLResolver.h"

static NSString* const kBabelInternalStartQueryParameter = @"__babelchrome_start";
static NSString* const kBabelInternalRefreshQueryParameter = @"__babelchrome_refresh";

@implementation BabelStableServerURLResolver

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0;
}

- (BOOL)isStableServerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  return [components.scheme isEqualToString:@"babelchrome"] &&
         [components.host isEqualToString:@"server"] &&
         components.path.length > 1;
}

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString {
  if (![self isStableServerURLString:urlString]) {
    return NO;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kBabelInternalStartQueryParameter] &&
        ![item.value isEqualToString:@"0"]) {
      return YES;
    }
  }

  return NO;
}

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSMutableArray<NSString*>* refreshURLStrings = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if (![item.name isEqualToString:kBabelInternalRefreshQueryParameter] || item.value.length == 0) {
      continue;
    }

    NSString* refreshURLString = item.value.stringByRemovingPercentEncoding ?: item.value;
    if ([self isStableBabelChromeURLString:refreshURLString]) {
      [refreshURLStrings addObject:refreshURLString];
    }
  }

  return refreshURLStrings;
}

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (!components) {
    return urlString;
  }

  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:kBabelInternalStartQueryParameter] ||
        [item.name isEqualToString:kBabelInternalRefreshQueryParameter]) {
      continue;
    }

    [queryItems addObject:item];
  }

  components.queryItems = queryItems.count > 0 ? queryItems : nil;
  return components.string ?: urlString;
}

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components {
  NSString* path = components.percentEncodedPath ?: components.path ?: @"";
  NSArray<NSString*>* pathComponents = [path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 2 && pathComponents[1].length > 0) {
    return [@"/" stringByAppendingString:pathComponents[1]];
  }

  return path.length > 0 ? path : @"/";
}

- (NSString*)stableServerReloadURLStringForRequestedURLString:(NSString*)requestedURLString
                                             actualURLString:(NSString*)actualURLString {
  NSString* stableRequestedURLString = requestedURLString ?: @"";
  if (![self isStableServerURLString:stableRequestedURLString]) {
    return stableRequestedURLString;
  }

  NSURLComponents* requestedComponents =
      [NSURLComponents componentsWithString:stableRequestedURLString];
  NSURLComponents* actualComponents =
      [NSURLComponents componentsWithString:actualURLString ?: @""];
  NSString* actualScheme = actualComponents.scheme.lowercaseString ?: @"";
  if (![actualScheme isEqualToString:@"http"] && ![actualScheme isEqualToString:@"https"]) {
    return stableRequestedURLString;
  }

  NSString* actualPath = actualComponents.percentEncodedPath ?: actualComponents.path ?: @"";
  if ([actualPath hasPrefix:@"/module/"]) {
    return stableRequestedURLString;
  }

  NSString* projectPath = [self stableServerProjectPathForURLComponents:requestedComponents];
  if (actualPath.length > 0 && ![actualPath isEqualToString:@"/"]) {
    requestedComponents.percentEncodedPath = [projectPath stringByAppendingString:actualPath];
  } else {
    requestedComponents.percentEncodedPath = projectPath;
  }

  requestedComponents.percentEncodedQuery = actualComponents.percentEncodedQuery;
  requestedComponents.percentEncodedFragment = actualComponents.percentEncodedFragment;

  return requestedComponents.string ?: stableRequestedURLString;
}

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] ||
      ![components.host isEqualToString:@"server"]) {
    return @"";
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count < 2) {
    return @"";
  }

  return pathComponents[1].stringByRemovingPercentEncoding ?: pathComponents[1];
}

@end
