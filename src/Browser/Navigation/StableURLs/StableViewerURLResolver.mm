#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"

#import "LocalServices/LocalServiceHost.h"

@implementation BabelStableViewerURLResolver

- (BOOL)isStableViewerURLString:(NSString*)urlString {
  return [self viewerKindForStableViewerURLString:urlString].length > 0 &&
         [self sourceKindForStableViewerURLString:urlString].length > 0;
}

- (NSURL*)sourceURLForViewerURLString:(NSString*)urlString {
  NSString* sourceKind = nil;
  NSString* encodedSourceValue = nil;
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if ([components.scheme isEqualToString:@"babelchrome"] && components.host.length > 0) {
    NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
    if (pathComponents.count >= 3) {
      NSString* candidateSourceKind = pathComponents[1];
      if ([candidateSourceKind isEqualToString:@"file"] || [candidateSourceKind isEqualToString:@"url"]) {
        sourceKind = candidateSourceKind;
        NSString* prefix = [NSString stringWithFormat:@"/%@/", candidateSourceKind];
        encodedSourceValue = [components.path hasPrefix:prefix]
            ? [components.path substringFromIndex:prefix.length]
            : @"";
      }
    }
  }

  if (encodedSourceValue.length > 0) {
    NSString* sourceValue = encodedSourceValue.stringByRemovingPercentEncoding ?: encodedSourceValue;
    if ([sourceKind isEqualToString:@"file"]) {
      return [NSURL fileURLWithPath:sourceValue];
    }
    return [NSURL URLWithString:sourceValue];
  }

  return [NSURL URLWithString:urlString ?: @""];
}

- (NSString*)fragmentForStableViewerURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return @"";
  }

  NSRange fragmentRange = [urlString rangeOfString:@"#"];
  if (fragmentRange.location == NSNotFound) {
    return @"";
  }

  return [urlString substringFromIndex:fragmentRange.location];
}

- (NSString*)escapedStableViewerString:(NSString*)value {
  NSMutableCharacterSet* allowedCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
  [allowedCharacters addCharactersInString:@"-._~"];
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)viewerKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  return sourceKind.length > 0 ? components.host : nil;
}

- (NSString*)resolvedViewerKindForStableViewerURLString:(NSString*)urlString {
  NSString* viewerKind = [self viewerKindForStableViewerURLString:urlString];
  if (![viewerKind isEqualToString:@"viewer"]) {
    return viewerKind;
  }

  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (!sourceURL) {
    return nil;
  }

  return [BabelLocalServiceHost.sharedHost viewerKindForURL:sourceURL];
}

- (NSString*)sourceKindForStableViewerURLString:(NSString*)urlString {
  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (![components.scheme isEqualToString:@"babelchrome"] || components.host.length == 0) {
    return nil;
  }

  NSArray<NSString*>* pathComponents = [components.path componentsSeparatedByString:@"/"];
  if (pathComponents.count >= 3 &&
      ([pathComponents[1] isEqualToString:@"file"] || [pathComponents[1] isEqualToString:@"url"])) {
    return pathComponents[1];
  }
  return nil;
}

- (NSString*)displayURLStringForStableViewerURLString:(NSString*)urlString {
  if (![self isStableViewerURLString:urlString]) {
    return urlString ?: @"";
  }

  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString] ?:
      [self viewerKindForStableViewerURLString:urlString];
  NSString* sourceKind = [self sourceKindForStableViewerURLString:urlString];
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  if (viewerKind.length == 0 || sourceKind.length == 0 || !sourceURL) {
    return urlString.stringByRemovingPercentEncoding ?: urlString ?: @"";
  }

  NSString* sourceDisplayString = [sourceKind isEqualToString:@"file"]
      ? sourceURL.path
      : sourceURL.absoluteString;
  NSString* fragment = [self fragmentForStableViewerURLString:urlString];

  return [sourceDisplayString stringByAppendingString:fragment ?: @""];
}

@end
