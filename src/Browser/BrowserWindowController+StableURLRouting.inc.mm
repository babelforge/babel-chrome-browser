// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)viewerURLStringForSupportedURLString:(NSString*)urlString {
  NSURL* url = [self sourceURLForViewerURLString:urlString];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSError* serviceError = nil;
  if (![BabelLocalServiceHost.sharedHost startIfNeededWithError:&serviceError]) {
    [self showLocalServiceStartupAlert:serviceError];
    return nil;
  }

  NSURL* viewerURL = [BabelLocalServiceHost.sharedHost viewerURLForURL:url];
  NSURLComponents* viewerComponents = viewerURL ? [NSURLComponents componentsWithURL:viewerURL
                                                             resolvingAgainstBaseURL:NO] : nil;
  NSString* viewerKind = [self resolvedViewerKindForStableViewerURLString:urlString];
  if (viewerKind.length == 0) {
    viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  }
  if (viewerComponents && [viewerKind isEqualToString:@"markdown"]) {
    NSMutableArray<NSURLQueryItem*>* queryItems =
        [viewerComponents.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"theme" value:[self markdownTheme]]];
    viewerComponents.queryItems = queryItems;
    viewerURL = viewerComponents.URL;
  }

  NSString* viewerURLString = viewerURL.absoluteString;
  NSString* fragment = [self stableViewerFragmentForURLString:urlString];
  if (viewerURLString.length > 0 && fragment.length > 0) {
    return [viewerURLString stringByAppendingString:fragment];
  }

  return viewerURLString;
}

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString {
  NSURL* sourceURL = [self sourceURLForViewerURLString:urlString];
  NSString* sourceDisplayString = sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString;
  if (sourceDisplayString.length == 0) {
    sourceDisplayString = urlString ?: @"";
  }

  NSString* extension = sourceURL.pathExtension.lowercaseString ?: @"";
  NSString* title = @"No viewer installed for this file type";
  NSString* detail = extension.length > 0
      ? [NSString stringWithFormat:@"No enabled BabelChrome viewer module currently handles .%@ files.", extension]
      : @"No enabled BabelChrome viewer module currently handles this source.";
  NSString* html = [NSString stringWithFormat:
      @"<!doctype html>"
       "<html><head><meta charset='utf-8'>"
       "<style>"
       "body{margin:0;background:#f5f6f8;color:#1f2328;font:15px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;}"
       "main{max-width:760px;margin:92px auto;padding:0 28px;}"
       "h1{font-size:28px;line-height:1.2;margin:0 0 14px;font-weight:700;}"
       "p{line-height:1.55;margin:0 0 18px;color:#59636e;}"
       "code{display:block;background:#fff;border:1px solid #d8dee4;border-radius:8px;padding:14px 16px;white-space:pre-wrap;word-break:break-all;color:#1f2328;}"
       "</style></head><body><main>"
       "<h1>%@</h1>"
       "<p>%@</p>"
       "<code>%@</code>"
       "</main></body></html>",
      [self htmlEscapedString:title],
      [self htmlEscapedString:detail],
      [self htmlEscapedString:sourceDisplayString]];
  return [self dataURLStringForHTML:html];
}

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString {
  if ([self isStableViewerURLString:urlString]) {
    return urlString;
  }

  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url || ![BabelLocalServiceHost.sharedHost supportsURL:url]) {
    return nil;
  }

  NSString* viewerKind = [BabelLocalServiceHost.sharedHost viewerKindForURL:url];
  if (viewerKind.length == 0) {
    return nil;
  }

  BOOL isRemoteURL = [url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"];
  NSString* sourceKind = isRemoteURL ? @"url" : @"file";
  NSString* sourceValue = isRemoteURL ? url.absoluteString : url.path;
  NSString* encodedSourceValue = [self stableViewerEscapedString:sourceValue];
  if (encodedSourceValue.length == 0) {
    return nil;
  }

  return [NSString stringWithFormat:@"babelchrome://%@/%@/%@",
                                    viewerKind,
                                    sourceKind,
                                    encodedSourceValue];
}

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
  if (![self isStableBabelChromeURLString:urlString]) {
    return nil;
  }

  NSString* viewerURLString = [self viewerURLStringForSupportedURLString:urlString];
  if (viewerURLString.length > 0) {
    return viewerURLString;
  }

  if ([self isStableViewerURLString:urlString]) {
    return [self noViewerInstalledPageURLStringForStableViewerURLString:urlString];
  }

  return [self moduleNavigationURLStringForStableBabelChromeURLString:urlString];
}

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
    if ([item.name isEqualToString:kInternalStartQueryParameter] &&
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
    if (![item.name isEqualToString:kInternalRefreshQueryParameter] || item.value.length == 0) {
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
    if ([item.name isEqualToString:kInternalStartQueryParameter] ||
        [item.name isEqualToString:kInternalRefreshQueryParameter]) {
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

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab {
  NSString* requestedURLString = tab.requestedURLString ?: @"";
  if (![self isStableServerURLString:requestedURLString]) {
    return requestedURLString;
  }

  NSURLComponents* requestedComponents =
      [NSURLComponents componentsWithString:requestedURLString];
  NSURLComponents* actualComponents =
      [NSURLComponents componentsWithString:tab.urlString ?: @""];
  NSString* actualScheme = actualComponents.scheme.lowercaseString ?: @"";
  if (![actualScheme isEqualToString:@"http"] && ![actualScheme isEqualToString:@"https"]) {
    return requestedURLString;
  }

  NSString* actualPath = actualComponents.percentEncodedPath ?: actualComponents.path ?: @"";
  if ([actualPath hasPrefix:@"/module/"]) {
    return requestedURLString;
  }

  NSString* projectPath = [self stableServerProjectPathForURLComponents:requestedComponents];
  if (actualPath.length > 0 && ![actualPath isEqualToString:@"/"]) {
    requestedComponents.percentEncodedPath = [projectPath stringByAppendingString:actualPath];
  } else {
    requestedComponents.percentEncodedPath = projectPath;
  }

  requestedComponents.percentEncodedQuery = actualComponents.percentEncodedQuery;
  requestedComponents.percentEncodedFragment = actualComponents.percentEncodedFragment;

  return requestedComponents.string ?: requestedURLString;
}

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString {
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
    NSDictionary* moduleRoute = [self moduleRouteForBabelChromeComponents:components error:&error];
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
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:moduleIdentifier
                                                                       route:route
                                                             sourceURLString:sourceURLString
                                                                       error:&error];
  return moduleURL.absoluteString;
}
