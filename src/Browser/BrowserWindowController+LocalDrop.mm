#import "Browser/BrowserWindowController+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation BabelBrowserWindowController (LocalDrop)

- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths {
  [localDropSessionController_ didReceiveLocalDragPaths:paths
                                                browser:browser
                                            selectedTab:selectedTab_];
}

- (BOOL)pageContainerSupportsLocalDrop:(BabelPageContainerView*)container {
  if (!container) {
    return NO;
  }

  for (BabelBrowserTab* tab in tabs_) {
    if (tab.hostView == container) {
      BOOL supported = [self tabSupportsLocalDropPaths:tab];
      [self appendLocalDropLogLine:[NSString stringWithFormat:
          @"AppKit drag probe tab=%@ requestedURL=%@ supported=%@",
          tab.identifier ?: @"",
          tab.requestedURLString ?: tab.urlString ?: @"",
          supported ? @"YES" : @"NO"]];
      return supported;
    }
  }

  [self appendLocalDropLogLine:@"AppKit drag probe had no matching tab."];
  return NO;
}

- (void)pageContainerDidReceiveLocalDrop:(BabelPageContainerView*)container {
  NSArray<NSString*>* paths = [container localDropPaths];
  [self appendLocalDropLogLine:[NSString stringWithFormat:@"AppKit drop accepted paths=%@", paths ?: @[]]];
  [self browser:[container browser] didReceiveLocalDragPaths:paths];
}

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser {
  [localDropSessionController_ browserDidFinishLoading:browser];
}

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser {
  return [localDropSessionController_ shouldSuppressLocalFileNavigationForBrowser:browser
                                                                     selectedTab:selectedTab_];
}

- (void)appendLocalDropLogLine:(NSString*)line {
  [localDropSessionController_ appendLogLine:line];
}

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab {
  return [localDropSessionController_ tabSupportsLocalDropPaths:tab];
}

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString {
  return [localDropSupportResolver_ URLStringSupportsLocalDropPaths:urlString];
}

@end

#pragma clang diagnostic pop
