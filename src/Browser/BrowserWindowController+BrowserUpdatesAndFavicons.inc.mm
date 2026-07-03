// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (BOOL)shouldPropagateBrowserClose {
  return isTerminating_;
}

- (void)refreshBabelChromeFileTypeCapabilities {
  if (browserClient_) {
    browserClient_->RefreshFileTypesHeaderValue();
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        BOOL isGeneratedTitle = [title hasPrefix:@"data:"] || [title containsString:@"data:text"];
        tab.title = title.length > 0 && !isGeneratedTitle ? title : tab.urlString;
        tab.tabItemView.title = [self compactTitleForString:tab.title];
        [self saveGroupsState];
        if (tab == selectedTab_) {
          [self updateWindowTitleForSelectedTab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        if ([urlString hasPrefix:@"data:"]) {
          return;
        }

        tab.urlString = urlString;
        if ([self isStableServerURLString:tab.requestedURLString]) {
          tab.requestedURLString = [self stableServerReloadURLStringForTab:tab];
        } else if (![self isStableBabelChromeURLString:tab.requestedURLString] ||
                   ![self isLocalServiceRuntimeURLString:urlString]) {
          tab.requestedURLString = urlString;
        }
        NSNumber* browserIdentifier = @([tab browser]->GetIdentifier());
        NSArray<NSString*>* pendingRefreshURLStrings =
            pendingRefreshURLStringsByBrowserIdentifier_[browserIdentifier];
        if (pendingRefreshURLStrings.count > 0 &&
            ![self isLocalServiceModuleURLString:urlString]) {
          [pendingRefreshURLStringsByBrowserIdentifier_ removeObjectForKey:browserIdentifier];
          [self reloadRequestedURLStrings:pendingRefreshURLStrings excludingTab:tab];
        }
        NSArray<NSString*>* directRefreshURLStrings =
            [self refreshURLStringsForStableURLString:urlString];
        if (directRefreshURLStrings.count > 0) {
          [self reloadRequestedURLStrings:directRefreshURLStrings excludingTab:tab];
        }
        [self saveGroupsState];
        if (tab == selectedTab_ && !urlTextField_.currentEditor) {
          [self updateAddressBarForTab:tab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || tab != selectedTab_) {
    return;
  }

  NSString* displayedStatusText = statusText ?: @"";
  linkStatusBarLabel_.stringValue = displayedStatusText;
  linkStatusBarView_.hidden = displayedStatusText.length == 0;
  if (!linkStatusBarView_.hidden) {
    [rightView_ addSubview:linkStatusBarView_
                positioned:NSWindowAbove
                relativeTo:pagesPanel_];
  }
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  NSPasteboard* pasteboard = NSPasteboard.generalPasteboard;
  [pasteboard clearContents];
  [pasteboard setString:urlString forType:NSPasteboardTypeString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  if (!faviconImage) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tab.faviconImage = faviconImage;
        tab.tabItemView.faviconImage = faviconImage;
        [faviconStore_ cacheFaviconImage:faviconImage forURLString:tab.urlString];
        return;
      }
    }
  }
}
