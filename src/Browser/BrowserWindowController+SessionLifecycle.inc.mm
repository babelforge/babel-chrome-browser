// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)restoreSessionByPriority {
  [self restoreSessionPositionState];

  NSData* stateData = [self persistedGroupsAndTabsStateData];
  NSDictionary* state = [self persistedGroupsAndTabsStateFromData:stateData];

  isRestoringSession_ = YES;
  [self restoreSessionTabsFromState:state];
  [self restoreSessionGroupsFromState:state];
  isRestoringSession_ = NO;

  [self restoreSessionInitialBrowsers];
  [self restoreSessionModulesLifecycle];
}

- (void)restoreSessionPositionState {
  [self restoreSessionWindowFrame];
  [self restoreSessionSidebarState];
}

- (void)restoreSessionWindowFrame {
  [self restoreMainWindowFrame];
}

- (void)restoreSessionWindowZoom {
  [self restoreMainWindowZoomStateIfNeeded];
}

- (void)restoreSessionSidebarCollapsedState {
  sidebarCollapsed_ = [windowStateStore_ restoredSidebarCollapsed];
}

- (void)restoreSessionSidebarExpandedWidth {
  expandedSidebarWidth_ = [self restoredExpandedSidebarWidth];
}

- (void)restoreSessionSidebarState {
  [self restoreSessionSidebarCollapsedState];
  [self restoreSessionSidebarExpandedWidth];
}

- (void)applySessionSidebarDividerPosition {
  if (didApplyInitialSidebarRestore_) {
    return;
  }

  didApplyInitialSidebarRestore_ = YES;
  BOOL previousBuildingState = isBuildingInterface_;
  isBuildingInterface_ = YES;
  [self layoutInterfaceForCurrentSplitViewSize];
  isBuildingInterface_ = previousBuildingState;
}

- (void)restoreSessionSidebarAfterInitialLayout {
  [self restoreSessionSidebarState];
  [self applySessionSidebarDividerPosition];
}

- (void)restoreSessionInitialBrowsers {
  [self createInitialRestoredBrowserIfNeeded];
}

- (void)restoreSessionModulesLifecycle {
  [self dispatchApplicationDidStartModuleLifecycleHook];
}

- (void)maximizeWindowToVisibleFrame:(id)sender {
  NSScreen* screen = self.window.screen ?: NSScreen.mainScreen;
  if (!screen) {
    return;
  }

  [self.window setFrame:screen.visibleFrame display:YES animate:YES];
}

- (void)dispatchApplicationDidStartModuleLifecycleHook {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSError* error = nil;
    NSDictionary* response =
        [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.did-start" error:&error];
    if (error) {
      NSLog(@"BabelChrome module lifecycle app.did-start failed: %@", error.localizedDescription);
    }
    NSArray<NSString*>* restoredProjectIdentifiers =
        [self restoredProjectIdentifiersFromLifecycleResponse:response];
    if (restoredProjectIdentifiers.count > 0) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadServerTabsWithProjectIdentifiers:restoredProjectIdentifiers];
      });
    }
  });
}

- (void)dispatchApplicationWillQuitModuleLifecycleHook {
  NSError* error = nil;
  [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.will-quit" error:&error];
  if (error) {
    NSLog(@"BabelChrome module lifecycle app.will-quit failed: %@", error.localizedDescription);
  }
}
