// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || ![self stableServerURLStringRequestsStart:urlString]) {
    return NO;
  }

  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:urlString];
  if (navigationURLString.length == 0) {
    return NO;
  }

  NSString* requestedURLString = [self stableURLStringByRemovingInternalQueryParameters:urlString];
  NSArray<NSString*>* refreshURLStrings = [self refreshURLStringsForStableURLString:urlString];
  if (refreshURLStrings.count > 0) {
    [runtimeRefreshCoordinator_ enqueueRefreshURLStrings:refreshURLStrings
                                    forBrowserIdentifier:browser->GetIdentifier()];
  }

  tab.requestedURLString = requestedURLString;
  tab.urlString = navigationURLString;
  browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  [self saveGroupsState];
  return YES;
}

- (BOOL)isStableViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ isStableViewerURLString:urlString];
}

- (NSURL*)sourceURLForViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ sourceURLForViewerURLString:urlString];
}

- (NSString*)stableViewerFragmentForURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ fragmentForStableViewerURLString:urlString];
}

- (NSString*)stableViewerEscapedString:(NSString*)value {
  return [stableViewerURLResolver_ escapedStableViewerString:value];
}

- (NSString*)viewerKindForStableViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ viewerKindForStableViewerURLString:urlString];
}

- (NSString*)resolvedViewerKindForStableViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ resolvedViewerKindForStableViewerURLString:urlString];
}

- (NSString*)sourceKindForStableViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ sourceKindForStableViewerURLString:urlString];
}

- (NSString*)displayURLStringForStableViewerURLString:(NSString*)urlString {
  return [stableViewerURLResolver_ displayURLStringForStableViewerURLString:urlString];
}
