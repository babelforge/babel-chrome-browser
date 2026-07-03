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
    [tab setDeveloperToolsBrowser:browser];
    [tab.developerToolsHostView setBrowser:browser];
    [tab.developerToolsHostView layoutSubtreeIfNeeded];
    return;
  }

  BabelBrowserTab* tab = pendingTabs_.firstObject;
  if (tab) {
    [pendingTabs_ removeObjectAtIndex:0];
  }

  if (!tab) {
    return;
  }

  [tab setBrowser:browser];
  [tab.hostView setBrowser:browser];
  [tab.hostView layoutSubtreeIfNeeded];
  [self enforceLivePageBrowserLimit];
}

- (void)attachCreatedPopupBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = pendingDeveloperToolsTab_;
  pendingDeveloperToolsTab_ = nil;
  if (!tab) {
    return;
  }

  [tab setDeveloperToolsBrowser:browser];
  [tab.developerToolsHostView setBrowser:browser];
  [self reparentDeveloperToolsBrowser:browser intoTab:tab];
  [self layoutBrowserViewsForTab:tab];
}

- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab developerToolsBrowser] && [tab developerToolsBrowser]->IsSame(browser)) {
        [self hideDeveloperToolsForTab:tab];
        return;
      }
    }
  }

  if (browser->IsPopup()) {
    return;
  }

  BabelBrowserTab* tabToRemove = nil;
  BabelBrowserGroup* groupToSelect = nil;
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tabToRemove = tab;
        groupToSelect = group;
        break;
      }
    }
    if (tabToRemove) {
      break;
    }
  }

  if (!tabToRemove) {
    return;
  }

  if ([liveBrowserEvictionPolicy_ isTabEvicting:tabToRemove]) {
    [liveBrowserEvictionPolicy_ unmarkTabEvicting:tabToRemove];
    [tabToRemove setBrowser:nullptr];
    [tabToRemove.hostView setBrowser:nullptr];
    return;
  }

  if (groupToSelect && groupToSelect != selectedGroup_) {
    [self selectGroup:groupToSelect];
  }
  [self removeTab:tabToRemove];

  if (isTerminating_ && [self totalTabCount] == 0) {
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
  [tab.tabItemView removeFromSuperview];
  [tab.hostView removeFromSuperview];
  [tab.developerToolsPanelView removeFromSuperview];
  [group.tabs removeObject:tab];
  if (group == selectedGroup_) {
    [tabs_ removeObject:tab];
  }
  [pendingTabs_ removeObject:tab];
  [liveBrowserEvictionPolicy_ removeTab:tab];

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
