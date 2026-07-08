#import "Browser/Window/Actions/Browser/BabelBrowserWindowBrowserControlsActions.h"

#import "Browser/Window/Controller/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowBrowserControlsActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab {
  return [owner_->internalPageTabClassifier_ isInternalPageTab:tab];
}

- (void)openDeveloperToolsForSelectedTab {
  if (!owner_->selectedTab_ || ![owner_->selectedTab_ browser]) {
    return;
  }

  [owner_ openDeveloperToolsForBrowser:[owner_->selectedTab_ browser] x:0 y:0];
}

- (void)openDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser x:(int)x y:(int)y {
  if (![owner_ canOpenDeveloperToolsForBrowser:browser]) {
    return;
  }

  BabelBrowserTab* tab = [owner_ tabForBrowser:browser];
  if (!tab) {
    return;
  }

  tab.developerToolsVisible = YES;
  tab.developerToolsPanelView.hidden = tab != owner_->selectedTab_;
  [owner_ layoutBrowserViewsForTab:tab];

  [owner_ loadDeveloperToolsForTab:tab inspectingBrowser:browser];
}

- (BOOL)canOpenDeveloperToolsForSelectedTab {
  if (!owner_->selectedTab_ || ![owner_->selectedTab_ browser]) {
    return NO;
  }
  return [owner_ canOpenDeveloperToolsForBrowser:[owner_->selectedTab_ browser]];
}

- (BOOL)canOpenDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = [owner_ tabForBrowser:browser];
  return tab && !tab.developerToolsVisible && ![tab developerToolsBrowser];
}

- (BOOL)canOpenViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  return [owner_->viewerSourceActionHandler_ canOpenViewerSourceForTab:[owner_ tabForBrowser:browser]];
}

- (void)openViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_->viewerSourceActionHandler_ openViewerSourceForTab:[owner_ tabForBrowser:browser]];
}

- (void)revealViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_->viewerSourceActionHandler_ revealViewerSourceForTab:[owner_ tabForBrowser:browser]];
}

- (void)closeDeveloperToolsFromButton:(NSButton*)sender {
  BabelBrowserTab* tab = [owner_ tabForDeveloperToolsControl:sender];
  [owner_ closeDeveloperToolsForTab:tab];
}

- (void)changeDeveloperToolsDockFromButton:(NSButton*)sender {
  NSString* dockMode = [owner_->developerToolsDockingPolicy_ dockModeForTag:sender.tag];
  if (dockMode.length == 0) {
    return;
  }

  owner_->developerToolsDockMode_ = dockMode;
  [owner_->developerToolsDockingStore_ setDockMode:dockMode
                              allowedModes:[owner_->developerToolsDockingPolicy_ allowedDockModes]];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
}

- (void)resizeDeveloperToolsFromHandle:(BabelDeveloperToolsResizeHandleView*)sender {
  NSRect bounds = owner_->pagesPanel_.bounds;
  CGFloat axisLength = [owner_ developerToolsDockModeIsHorizontal]
      ? bounds.size.height
      : bounds.size.width;
  if (axisLength <= 0.0) {
    return;
  }

  CGFloat signedDelta = sender.dragDelta;
  if ([owner_->developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeTop] ||
      [owner_->developerToolsDockMode_ isEqualToString:kDeveloperToolsDockModeRight]) {
    signedDelta = -signedDelta;
  }

  owner_->developerToolsSizeRatio_ =
      [owner_->developerToolsDockingStore_ setSizeRatio:owner_->developerToolsSizeRatio_ + (signedDelta / axisLength)];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
}

- (void)resizeSidebarFromHandle:(BabelDeveloperToolsResizeHandleView*)sender {
  if (owner_->sidebarCollapsed_) {
    return;
  }

  [owner_ saveExpandedSidebarWidth:owner_->expandedSidebarWidth_ + sender.dragDelta];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
}

- (void)toggleSidebarCollapsed:(id)sender {
  if (!owner_->sidebarCollapsed_) {
    [owner_ saveExpandedSidebarWidth:owner_->sidebarView_.frame.size.width];
  }
  owner_->sidebarCollapsed_ = !owner_->sidebarCollapsed_;
  [owner_->windowStateStore_ setSidebarCollapsed:owner_->sidebarCollapsed_];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
  [owner_->splitView_ setNeedsDisplay:YES];
  [owner_->sidebarView_ setNeedsDisplay:YES];
  [owner_->rightView_ setNeedsDisplay:YES];
}

- (BabelBrowserTab*)tabForDeveloperToolsControl:(NSView*)control {
  for (BabelBrowserGroup* group in owner_->groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([control isDescendantOf:tab.developerToolsPanelView]) {
        return tab;
      }
    }
  }
  return nil;
}

- (NSString*)restoredDeveloperToolsDockMode {
  return [owner_->developerToolsDockingStore_ restoredDockModeWithFallback:kDeveloperToolsDockModeBottom
                                                      allowedModes:[owner_->developerToolsDockingPolicy_ allowedDockModes]];
}

- (CGFloat)restoredDeveloperToolsSizeRatio {
  return [owner_->developerToolsDockingStore_ restoredSizeRatio];
}

- (BOOL)developerToolsDockModeIsHorizontal {
  return [owner_->developerToolsDockingPolicy_ isHorizontalDockMode:owner_->developerToolsDockMode_];
}

- (void)navigateSelectedTabBack {
  [owner_->browserNavigationController_ navigateTabBack:owner_->selectedTab_];
}

- (void)navigateSelectedTabForward {
  [owner_->browserNavigationController_ navigateTabForward:owner_->selectedTab_];
}

- (void)reloadSelectedTab {
  [owner_ reloadSelectedTabIgnoringCache:NO];
}

- (void)reloadSelectedTabFromButton:(id)sender {
  [owner_ reloadSelectedTab];
}

- (void)reloadSelectedTabIgnoringCache {
  [owner_ reloadSelectedTabIgnoringCache:YES];
}

- (void)reloadSelectedTabIgnoringCache:(BOOL)ignoringCache {
  if (!owner_->selectedTab_ || ![owner_->selectedTab_ browser]) {
    return;
  }

  CefRefPtr<CefBrowser> browser = [owner_->selectedTab_ browser];
  CefRefPtr<CefFrame> mainFrame = browser->GetMainFrame();
  NSString* requestedURLString =
      [owner_ stableServerReloadURLStringForTab:owner_->selectedTab_] ?: owner_->selectedTab_.requestedURLString;
  if ([owner_ isStableBabelChromeURLString:requestedURLString]) {
    NSString* navigationURLString =
        [owner_ navigationURLStringForStableBabelChromeURLString:requestedURLString];
    if (navigationURLString.length > 0) {
      owner_->selectedTab_.requestedURLString = requestedURLString;
      owner_->selectedTab_.urlString = navigationURLString;
      browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      [owner_ saveGroupsState];
      if (!ignoringCache) {
        return;
      }
    }
  }

  std::string currentURLString = mainFrame ? mainFrame->GetURL().ToString() : "";
  if (currentURLString.rfind("file://", 0) == 0) {
    mainFrame->LoadURL(currentURLString);
    return;
  }

  if (!ignoringCache) {
    [owner_->browserNavigationController_ reloadTab:owner_->selectedTab_];
    return;
  }

  [owner_->browserNavigationController_ reloadTabIgnoringCache:owner_->selectedTab_];
}

- (void)reloadMarkdownViewerTabsUsingCurrentTheme {
  for (BabelBrowserTab* tab in owner_->tabs_) {
    if (![[owner_->stableViewerURLResolver_ resolvedViewerKindForStableViewerURLString:tab.requestedURLString] isEqualToString:@"markdown"]) {
      continue;
    }

    NSString* navigationURLString = [owner_ viewerURLStringForSupportedURLString:tab.requestedURLString];
    if (navigationURLString.length == 0) {
      continue;
    }

    tab.urlString = navigationURLString;
    if ([tab browser]) {
      tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
    }
  }

  [owner_ saveGroupsState];
}


@end
