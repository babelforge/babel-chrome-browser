// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)navigateSelectedTabToViewerURLString:(NSString*)urlString {
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  if (!selectedTab_) {
    BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
    tab.requestedURLString = requestedURLString;
    [self saveGroupsState];
    return;
  }

  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
  } else {
    [self selectTab:selectedTab_];
  }

  [self saveGroupsState];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html {
  [self openInternalPageWithURLString:internalURLString
                                title:title
                                 html:html
                              browser:nullptr];
}

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser {
  if (browser) {
    BabelBrowserTab* targetTab = [self tabForBrowser:browser];
    if (targetTab) {
      NSString* dataURLString = [self dataURLStringForHTML:html];
      targetTab.urlString = dataURLString;
      targetTab.requestedURLString = internalURLString;
      targetTab.title = title;
      targetTab.tabItemView.title = [self compactTitleForString:title];
      browser->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
      [self selectTab:targetTab];
      [self showMainWindow];
      [self saveGroupsState];
      return;
    }
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  [self selectGroup:group];

  BabelBrowserTab* existingTab = [self tabWithURLString:internalURLString inGroup:group];
  NSString* dataURLString = [self dataURLStringForHTML:html];
  if (existingTab) {
    existingTab.urlString = dataURLString;
    existingTab.requestedURLString = internalURLString;
    existingTab.title = title;
    existingTab.tabItemView.title = [self compactTitleForString:title];
    [self selectTab:existingTab];
    if ([existingTab browser]) {
      [existingTab browser]->GetMainFrame()->LoadURL(std::string(dataURLString.UTF8String));
    }
    [self showMainWindow];
    [self saveGroupsState];
    return;
  }

  BabelBrowserTab* tab = [self makeTabForURL:dataURLString identifier:nil title:title];
  tab.requestedURLString = internalURLString;
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (NSString*)dataURLStringForHTML:(NSString*)html {
  NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
  NSString* encodedHTML = [data base64EncodedStringWithOptions:0];
  return [NSString stringWithFormat:@"data:text/html;charset=utf-8;base64,%@", encodedHTML];
}
