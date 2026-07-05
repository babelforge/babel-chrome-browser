#import "Browser/BabelBrowserWindowLocalDropActions.h"

#import "Browser/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowLocalDropActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths {
  [owner_->localDropSessionController_ didReceiveLocalDragPaths:paths
                                                browser:browser
                                            selectedTab:owner_->selectedTab_];
}

- (BOOL)pageContainerSupportsLocalDrop:(BabelPageContainerView*)container {
  if (!container) {
    return NO;
  }

  for (BabelBrowserTab* tab in owner_->tabs_) {
    if (tab.hostView == container) {
      BOOL supported = [owner_ tabSupportsLocalDropPaths:tab];
      [owner_ appendLocalDropLogLine:[NSString stringWithFormat:
          @"AppKit drag probe tab=%@ requestedURL=%@ supported=%@",
          tab.identifier ?: @"",
          tab.requestedURLString ?: tab.urlString ?: @"",
          supported ? @"YES" : @"NO"]];
      return supported;
    }
  }

  [owner_ appendLocalDropLogLine:@"AppKit drag probe had no matching tab."];
  return NO;
}

- (void)pageContainerDidReceiveLocalDrop:(BabelPageContainerView*)container {
  NSArray<NSString*>* paths = [container localDropPaths];
  [owner_ appendLocalDropLogLine:[NSString stringWithFormat:@"AppKit drop accepted paths=%@", paths ?: @[]]];
  [owner_ browser:[container browser] didReceiveLocalDragPaths:paths];
}

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser {
  [owner_->localDropSessionController_ browserDidFinishLoading:browser];
}

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser {
  return [owner_->localDropSessionController_ shouldSuppressLocalFileNavigationForBrowser:browser
                                                                     selectedTab:owner_->selectedTab_];
}

- (void)appendLocalDropLogLine:(NSString*)line {
  [owner_->localDropSessionController_ appendLogLine:line];
}

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab {
  return [owner_->localDropSessionController_ tabSupportsLocalDropPaths:tab];
}

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString {
  return [owner_->localDropSupportResolver_ URLStringSupportsLocalDropPaths:urlString];
}


@end
