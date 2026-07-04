// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)selectTabWithOffset:(NSInteger)offset {
  if (!selectedTab_ || tabs_.count < 2) {
    return;
  }

  NSUInteger currentIndex = [tabs_ indexOfObject:selectedTab_];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSInteger tabCount = (NSInteger)tabs_.count;
  NSInteger nextIndex = ((NSInteger)currentIndex + offset + tabCount) % tabCount;
  [self selectTab:tabs_[(NSUInteger)nextIndex] deferringBrowserCreation:YES];
}

- (void)selectTab:(BabelBrowserTab*)tab {
  [self selectTab:tab deferringBrowserCreation:NO];
}

- (void)selectTab:(BabelBrowserTab*)tab deferringBrowserCreation:(BOOL)deferringBrowserCreation {
  selectedTab_ = tab;
  linkStatusBarView_.hidden = YES;
  selectedGroup_.selectedTabIdentifier = tab.identifier;
  [self touchRecentlyUsedTab:tab];
  for (BabelBrowserTab* currentTab in tabs_) {
    currentTab.hostView.hidden = currentTab != tab;
    currentTab.developerToolsPanelView.hidden = currentTab != tab ||
                                                !currentTab.developerToolsVisible;
    currentTab.tabItemView.selected = currentTab == tab;
    [self layoutBrowserViewsForTab:currentTab];
  }
  [self updateAddressBarForTab:tab];
  [self updateWindowTitleForSelectedTab];
  [self layoutTabItemsSelectingLastTab:NO];
  if (isRestoringSession_) {
    needsInitialRestoredBrowserCreation_ = YES;
    [self saveGroupsState];
    return;
  }

  if (!isTerminating_) {
    if (deferringBrowserCreation) {
      [self scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
    } else {
      ++deferredBrowserCreationGeneration_;
      [self createBrowserForTabIfNeeded:tab];
      [self scheduleAdjacentTabPreloadForSelectedTab];
    }
  }
  [self saveGroupsState];
}

- (void)updateWindowTitleForSelectedTab {
  NSString* pageTitle = selectedTab_.title.length > 0 ? selectedTab_.title : selectedTab_.urlString;
  self.window.title =
      [browserPresentationFormatter_ windowTitleWithApplicationName:BabelChromeConfiguration.applicationName
                                                          pageTitle:pageTitle];
}

- (NSString*)displayURLStringForTab:(BabelBrowserTab*)tab {
  return [addressBarDisplayResolver_ displayURLStringForTab:tab];
}

- (NSDictionary*)addressBadgeForTab:(BabelBrowserTab*)tab {
  return [addressBarDisplayResolver_ addressBadgeForTab:tab];
}

- (NSColor*)colorFromHexString:(NSString*)hexString fallbackColor:(NSColor*)fallbackColor {
  return [browserPresentationFormatter_ colorFromHexString:hexString fallbackColor:fallbackColor];
}

- (void)layoutAddressTextFieldContent {
  NSRect bounds = addressTextFieldContainer_.bounds;
  BOOL hasBadge = !viewerBadgeLabel_.hidden;
  CGFloat badgeWidth = hasBadge ? 30.0 : 0.0;
  CGFloat leftInset = 8.0;
  CGFloat horizontalGap = hasBadge ? 8.0 : 0.0;
  CGFloat textX = leftInset + badgeWidth + horizontalGap;

  viewerBadgeLabel_.frame = NSMakeRect(leftInset,
                                       6.0,
                                       badgeWidth,
                                       MAX(0.0, bounds.size.height - 12.0));
  urlTextField_.frame = NSMakeRect(textX,
                                   4.0,
                                   MAX(0.0, bounds.size.width - textX - 8.0),
                                   MAX(0.0, bounds.size.height - 8.0));
}

- (void)setAddressBadge:(NSDictionary*)badge {
  NSString* normalizedBadgeString = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  BOOL hasBadge = normalizedBadgeString.length > 0;
  NSString* textColorString = [badge[@"textColor"] isKindOfClass:NSString.class] ? badge[@"textColor"] : @"#ffffff";
  NSString* backgroundColorString = [badge[@"backgroundColor"] isKindOfClass:NSString.class] ? badge[@"backgroundColor"] : @"#000000";
  NSString* settingsRoute = [badge[@"settingsRoute"] isKindOfClass:NSString.class] ? badge[@"settingsRoute"] : @"";
  viewerBadgeLabel_.hidden = !hasBadge;
  viewerBadgeLabel_.settingsRoute = hasBadge ? settingsRoute : @"";
  [viewerBadgeLabel_ configureWithText:normalizedBadgeString
                             textColor:[self colorFromHexString:textColorString fallbackColor:NSColor.whiteColor]
                       backgroundColor:[self colorFromHexString:backgroundColorString fallbackColor:NSColor.clearColor]];
  [self layoutAddressTextFieldContent];
}

- (void)openAddressBadgeSettingsFromMenu:(NSMenuItem*)sender {
  NSString* settingsRoute = [sender.representedObject isKindOfClass:NSString.class]
      ? sender.representedObject
      : @"";
  if (settingsRoute.length == 0) {
    return;
  }

  [self handleInternalNavigationURLString:settingsRoute];
}

- (void)updateAddressBarForTab:(BabelBrowserTab*)tab {
  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:[self addressBadgeForTab:tab]];
  urlTextField_.stringValue = [self displayURLStringForTab:tab];
}

- (void)clearAddressBar {
  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:nil];
  urlTextField_.stringValue = @"";
}

- (NSString*)addressFieldNavigationString {
  NSString* addressString = urlTextField_.stringValue ?: @"";
  if (!selectedTab_) {
    return addressString;
  }

  NSString* displayedURLString = [self displayURLStringForTab:selectedTab_];
  NSString* actualURLString = selectedTab_.requestedURLString ?: selectedTab_.urlString ?: @"";
  if (displayedURLString.length > 0 &&
      actualURLString.length > 0 &&
      [addressString isEqualToString:displayedURLString]) {
    return actualURLString;
  }

  return addressString;
}
- (void)navigateFromAddressField:(id)sender {
  if (!selectedTab_) {
    return;
  }

  [self hideOmniboxSuggestions];
  NSString* urlString = [self normalizedURLStringFromAddress:[self addressFieldNavigationString]];
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      [self updateAddressBarForTab:selectedTab_];
      return;
    }
    navigationURLString = urlString;
  }
  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
    [self saveGroupsState];
    return;
  }

  [self selectTab:selectedTab_];
  [self saveGroupsState];
}

- (void)closeSelectedTab {
  if (!selectedTab_) {
    return;
  }

  [self closeTabFromItem:selectedTab_.tabItemView];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (notification.object == urlTextField_) {
    [self hideOmniboxSuggestions];
  }

  NSNumber* movement = notification.userInfo[@"NSTextMovement"];
  if (movement.integerValue == NSReturnTextMovement) {
    [self navigateFromAddressField:notification.object];
  }
}

- (void)controlTextDidChange:(NSNotification*)notification {
  if (notification.object != urlTextField_) {
    return;
  }

  [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
}

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
doCommandBySelector:(SEL)commandSelector {
  if (control != urlTextField_) {
    return NO;
  }

  if (commandSelector == @selector(moveDown:)) {
    [self selectNextOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(moveUp:)) {
    [self selectPreviousOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(insertNewline:)) {
    if ([self acceptSelectedOmniboxSuggestion]) {
      return YES;
    }
    [self navigateFromAddressField:control];
    return YES;
  }

  if (commandSelector == @selector(cancelOperation:)) {
    [self hideOmniboxSuggestions];
    urlTextField_.stringValue = selectedTab_ ? [self displayURLStringForTab:selectedTab_] : @"";
    return YES;
  }

  return NO;
}
- (void)updateOmniboxSuggestionsForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [omniboxSuggestionsController_ removeAllSuggestions];
  ++googleSuggestGeneration_;

  if (trimmedQuery.length == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  NSArray<NSDictionary*>* openTabRows =
      [omniboxSuggestionContextBuilder_ openTabRowsForGroups:groups_
                                            defaultGroupName:kDefaultGroupName
                                        internalTabPredicate:^BOOL(BabelBrowserTab* tab) {
    return [self isInternalPageTab:tab];
  }];
  NSArray<NSDictionary*>* closedTabRows =
      [omniboxSuggestionContextBuilder_ closedTabRowsForClosedTabs:[recentlyClosedTabStore_ allClosedTabs]
                                                  defaultGroupName:kDefaultGroupName];

  NSArray<NSDictionary*>* localSuggestions =
      [omniboxLocalSuggestionBuilder_ localSuggestionsForQuery:trimmedQuery
                                                   openTabRows:openTabRows
                                                 closedTabRows:closedTabRows
                                                  maximumCount:kOmniboxSuggestionMaximumCount];
  for (NSDictionary* localSuggestion in localSuggestions) {
    NSMutableDictionary* suggestion = [localSuggestion mutableCopy];
    NSString* title = [suggestion[@"title"] isKindOfClass:NSString.class] ? suggestion[@"title"] : @"";
    NSString* urlString = [suggestion[@"url"] isKindOfClass:NSString.class] ? suggestion[@"url"] : @"";
    NSImage* faviconImage = [self faviconImageForSuggestionTitle:title urlString:urlString];
    if (faviconImage) {
      suggestion[@"icon"] = faviconImage;
    }
    [omniboxSuggestionsController_ addSuggestion:suggestion];
  }

  [self showOmniboxSuggestions];
  [self scheduleGoogleSuggestionsForQuery:trimmedQuery generation:googleSuggestGeneration_];
}

- (void)scheduleGoogleSuggestionsForQuery:(NSString*)query generation:(NSUInteger)generation {
  if (![self googleSuggestEnabled] || query.length < 2) {
    return;
  }

  NSArray<NSString*>* cachedSuggestions = [googleSuggestClient_ cachedSuggestionsForQuery:query];
  if (cachedSuggestions) {
    [self appendGoogleSuggestions:cachedSuggestions forQuery:query generation:generation];
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kGoogleSuggestDebounceDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != self->googleSuggestGeneration_ ||
        ![query isEqualToString:self->urlTextField_.stringValue]) {
      return;
    }

    [googleSuggestClient_ fetchSuggestionsForQuery:query
                                        completion:^(NSArray<NSString*>* suggestions) {
      [self appendGoogleSuggestions:suggestions ?: @[]
                            forQuery:query
                         generation:generation];
    }];
  });
}

- (void)appendGoogleSuggestions:(NSArray<NSString*>*)suggestions
                       forQuery:(NSString*)query
                    generation:(NSUInteger)generation {
  if (generation != googleSuggestGeneration_ ||
      ![query isEqualToString:urlTextField_.stringValue] ||
      ![self googleSuggestEnabled]) {
    return;
  }

  NSMutableSet<NSString*>* seenSuggestionKeys = [NSMutableSet set];
  for (NSDictionary* suggestion in [omniboxSuggestionsController_ suggestions]) {
    NSString* action = suggestion[@"action"] ?: @"";
    NSString* key = [NSString stringWithFormat:@"%@|%@", action, suggestion[@"url"] ?: @""];
    [seenSuggestionKeys addObject:key];
  }

  for (NSString* suggestion in suggestions) {
    if ([omniboxSuggestionsController_ suggestionCount] >= kOmniboxSuggestionMaximumCount) {
      break;
    }

    [self addOmniboxSuggestionWithTitle:suggestion
                              urlString:[googleSuggestClient_ googleSearchURLStringForQuery:suggestion]
                              groupName:@"Google Search"
                          tabIdentifier:nil
                                  action:@"google-search"
                                seenKeys:seenSuggestionKeys];
  }

  [self showOmniboxSuggestions];
}

- (void)addOmniboxSuggestionWithTitle:(NSString*)title
                            urlString:(NSString*)urlString
                            groupName:(NSString*)groupName
                        tabIdentifier:(NSString*)tabIdentifier
                                action:(NSString*)action
                              seenKeys:(NSMutableSet<NSString*>*)seenKeys {
  if (urlString.length == 0) {
    return;
  }

  NSString* key = [NSString stringWithFormat:@"%@|%@", action ?: @"", tabIdentifier ?: urlString];
  if ([seenKeys containsObject:key]) {
    return;
  }

  [seenKeys addObject:key];
  NSMutableDictionary* suggestion = [@{
    @"title": title.length > 0 ? title : urlString,
    @"url": urlString,
    @"group": groupName.length > 0 ? groupName : kDefaultGroupName,
    @"tabId": tabIdentifier ?: @"",
    @"action": action ?: @"navigate"
  } mutableCopy];
  NSImage* faviconImage = [self faviconImageForSuggestionTitle:title urlString:urlString];
  if (faviconImage) {
    suggestion[@"icon"] = faviconImage;
  }
  [omniboxSuggestionsController_ addSuggestion:suggestion];
}

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title urlString:(NSString*)urlString {
  return [omniboxSuggestionContextBuilder_ faviconImageForSuggestionTitle:title
                                                                urlString:urlString
                                                             faviconStore:faviconStore_];
}

- (void)showOmniboxSuggestions {
  if ([omniboxSuggestionsController_ suggestionCount] == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  [self layoutInterfaceForCurrentSplitViewSize];
  [omniboxSuggestionsController_ showWithTarget:self
                                         action:@selector(selectOmniboxSuggestionFromRow:)
                                      rowHeight:kOmniboxSuggestionRowHeight];
}

- (void)hideOmniboxSuggestions {
  [omniboxSuggestionsController_ hide];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)selectNextOmniboxSuggestion {
  if ([omniboxSuggestionsController_ suggestionCount] == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if ([omniboxSuggestionsController_ suggestionCount] == 0) {
    return;
  }

  [omniboxSuggestionsController_ selectNextSuggestion];
}

- (void)selectPreviousOmniboxSuggestion {
  if ([omniboxSuggestionsController_ suggestionCount] == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if ([omniboxSuggestionsController_ suggestionCount] == 0) {
    return;
  }

  [omniboxSuggestionsController_ selectPreviousSuggestion];
}

- (void)selectOmniboxSuggestionFromRow:(BabelOmniboxSuggestionRowView*)row {
  [omniboxSuggestionsController_ selectSuggestionAtIndex:row.tag];
  [self acceptSelectedOmniboxSuggestion];
}

- (BOOL)acceptSelectedOmniboxSuggestion {
  NSDictionary* suggestion = [omniboxSuggestionsController_ selectedSuggestion];
  if (!suggestion) {
    return NO;
  }

  NSString* action = suggestion[@"action"];
  if ([action isEqualToString:@"focus-tab"]) {
    NSString* tabIdentifier = suggestion[@"tabId"];
    for (BabelBrowserGroup* group in groups_) {
      BabelBrowserTab* tab = [self tabWithIdentifier:tabIdentifier inGroup:group];
      if (!tab) {
        continue;
      }

      [self hideOmniboxSuggestions];
      [self selectGroup:group];
      [self selectTab:tab];
      [self showMainWindow];
      return YES;
    }
  }

  NSString* urlString = suggestion[@"url"];
  if (urlString.length == 0) {
    return NO;
  }

  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:nil];
  urlTextField_.stringValue = urlString;
  [self hideOmniboxSuggestions];
  [self navigateFromAddressField:urlTextField_];
  return YES;
}

- (NSString*)normalizedURLStringFromAddress:(NSString*)address {
  return [addressNavigationNormalizer_ navigationStringFromAddress:address
                                                 defaultURLString:BabelChromeConfiguration.defaultURLString];
}

- (NSString*)compactTitleForString:(NSString*)value {
  return [browserPresentationFormatter_ compactTitleForString:value];
}
- (BOOL)shouldPropagateBrowserClose {
  return isTerminating_;
}

- (void)refreshBabelChromeFileTypeCapabilities {
  if (browserClient_) {
    browserClient_->RefreshFileTypesHeaderValue();
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab) {
    return;
  }

  BOOL isGeneratedTitle = [title hasPrefix:@"data:"] || [title containsString:@"data:text"];
  tab.title = title.length > 0 && !isGeneratedTitle ? title : tab.urlString;
  tab.tabItemView.title = [self compactTitleForString:tab.title];
  [self saveGroupsState];
  if (tab == selectedTab_) {
    [self updateWindowTitleForSelectedTab];
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || [urlString hasPrefix:@"data:"]) {
    return;
  }

  tab.urlString = urlString;
  if ([self isStableServerURLString:tab.requestedURLString]) {
    tab.requestedURLString = [self stableServerReloadURLStringForTab:tab];
  } else if (![self isStableBabelChromeURLString:tab.requestedURLString] ||
             ![self isLocalServiceRuntimeURLString:urlString]) {
    tab.requestedURLString = urlString;
  }
  if (![self isLocalServiceModuleURLString:urlString]) {
    NSArray<NSString*>* pendingRefreshURLStrings =
        [runtimeRefreshCoordinator_ consumeRefreshURLStringsForBrowserIdentifier:[tab browser]->GetIdentifier()];
    if (pendingRefreshURLStrings.count > 0) {
      [self reloadRequestedURLStrings:pendingRefreshURLStrings excludingTab:tab];
    }
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

  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab) {
    return;
  }

  tab.faviconImage = faviconImage;
  tab.tabItemView.faviconImage = faviconImage;
  [faviconStore_ cacheFaviconImage:faviconImage forURLString:tab.urlString];
}
