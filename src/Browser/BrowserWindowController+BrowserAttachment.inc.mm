// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)attachCreatedBrowser:(CefRefPtr<CefBrowser>)browser {
  if (browser->IsPopup()) {
    [self attachCreatedPopupBrowser:browser];
    return;
  }

  if (pendingDeveloperToolsTab_) {
    BabelBrowserTab* tab = pendingDeveloperToolsTab_;
    pendingDeveloperToolsTab_ = nil;
    [browserAttachmentCoordinator_ attachDeveloperToolsBrowser:browser toTab:tab];
    return;
  }

  [browserAttachmentCoordinator_ attachPageBrowser:browser];
}

- (void)attachCreatedPopupBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = pendingDeveloperToolsTab_;
  pendingDeveloperToolsTab_ = nil;
  if (!tab) {
    return;
  }

  [browserAttachmentCoordinator_ attachDeveloperToolsBrowser:browser toTab:tab];
  [self reparentDeveloperToolsBrowser:browser intoTab:tab];
  [self layoutBrowserViewsForTab:tab];
}

- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser {
  if ([browserAttachmentCoordinator_ detachClosedBrowser:browser
                                           selectedGroup:selectedGroup_
                                           isTerminating:isTerminating_]) {
    CefQuitMessageLoop();
  }
}

- (void)removeSelectedGroupTab:(BabelBrowserTab*)tab {
  [self removeTab:tab fromGroup:selectedGroup_ allowSelection:YES];
}

- (void)removeTab:(BabelBrowserTab*)tab {
  [self removeSelectedGroupTab:tab];
}

- (void)removeTab:(BabelBrowserTab*)tab
        fromGroup:(BabelBrowserGroup*)group
   allowSelection:(BOOL)allowSelection {
  [self closeDeveloperToolsForTab:tab];
  [browserAttachmentCoordinator_ removeTab:tab fromGroup:group];
  if (group == selectedGroup_) {
    [tabs_ removeObject:tab];
  }

  if (allowSelection && selectedTab_ == tab) {
    selectedTab_ = tabs_.lastObject;
    if (selectedTab_) {
      [self selectTab:selectedTab_];
    } else {
      [self clearAddressBar];
    }
  }

  if (group == selectedGroup_) {
    [self layoutTabItemsSelectingLastTab:NO];
  }
  [self saveGroupsState];
}
