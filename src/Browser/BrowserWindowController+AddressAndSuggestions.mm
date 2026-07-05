#import "Browser/BrowserWindowController+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation BabelBrowserWindowController (AddressAndSuggestions)

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
  [linkStatusBarController_ hideStatusBar:linkStatusBarView_];
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
    [browserPageLifecycleController_ markNeedsInitialRestoredBrowserCreation];
    [self saveGroupsState];
    return;
  }

  if (!isTerminating_) {
    if (deferringBrowserCreation) {
      [self scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
    } else {
      [browserPageLifecycleController_ cancelKeyboardBrowserCreation];
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

- (void)layoutAddressTextFieldContent {
  BabelAddressFieldLayout* layout =
      [addressFieldLayoutCalculator_ layoutForBounds:addressTextFieldContainer_.bounds
                                            hasBadge:!viewerBadgeLabel_.hidden];
  viewerBadgeLabel_.frame = layout.badgeFrame;
  urlTextField_.frame = layout.textFieldFrame;
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
                             textColor:[browserPresentationFormatter_ colorFromHexString:textColorString
                                                                            fallbackColor:NSColor.whiteColor]
                       backgroundColor:[browserPresentationFormatter_ colorFromHexString:backgroundColorString
                                                                            fallbackColor:NSColor.clearColor]];
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
  [self setAddressBadge:[addressBarDisplayResolver_ addressBadgeForTab:tab]];
  urlTextField_.stringValue = [addressBarDisplayResolver_ displayURLStringForTab:tab];
}

- (void)clearAddressBar {
  addressLabel_.stringValue = @"URL";
  [self setAddressBadge:nil];
  urlTextField_.stringValue = @"";
}

- (void)navigateFromAddressField:(id)sender {
  if (!selectedTab_) {
    return;
  }

  [self hideOmniboxSuggestions];
  BabelAddressNavigationRequest* request =
      [addressNavigationRequestResolver_ navigationRequestForAddressString:urlTextField_.stringValue
                                                               selectedTab:selectedTab_];
  if (request.shouldRestoreAddressBar) {
    [self updateAddressBarForTab:selectedTab_];
    return;
  }

  selectedTab_.urlString = request.navigationURLString;
  selectedTab_.requestedURLString = request.requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(request.navigationURLString.UTF8String));
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
    urlTextField_.stringValue = selectedTab_
        ? [addressBarDisplayResolver_ displayURLStringForTab:selectedTab_]
        : @"";
    return YES;
  }

  return NO;
}
- (void)updateOmniboxSuggestionsForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [omniboxSuggestionsController_ removeAllSuggestions];
  [googleSuggestionScheduler_ cancelPendingSuggestions];

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
  [self scheduleGoogleSuggestionsForQuery:trimmedQuery];
}

- (void)scheduleGoogleSuggestionsForQuery:(NSString*)query {
  __weak BabelBrowserWindowController* weakSelf = self;
  [googleSuggestionScheduler_ scheduleSuggestionsForQuery:query
                                         delayNanoseconds:kGoogleSuggestDebounceDelayNanoseconds
                                     currentQueryProvider:^NSString* {
                                       BabelBrowserWindowController* strongSelf = weakSelf;
                                       return strongSelf ? strongSelf->urlTextField_.stringValue : @"";
                                     }
                                           enabledProvider:^BOOL {
                                             BabelBrowserWindowController* strongSelf = weakSelf;
                                             return strongSelf ? [strongSelf googleSuggestEnabled] : NO;
                                           }
                                             resultHandler:^(NSString* suggestedQuery,
                                                             NSArray<NSString*>* suggestions) {
                                               BabelBrowserWindowController* strongSelf = weakSelf;
                                               [strongSelf appendGoogleSuggestions:suggestions
                                                                          forQuery:suggestedQuery];
                                             }];
}

- (void)appendGoogleSuggestions:(NSArray<NSString*>*)suggestions
                       forQuery:(NSString*)query {
  if (![query isEqualToString:urlTextField_.stringValue] ||
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
  [browserMetadataEventController_ updateBrowser:browser title:title];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  [browserMetadataEventController_ updateBrowser:browser urlString:urlString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  [browserMetadataEventController_ updateBrowser:browser statusText:statusText];
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  [browserMetadataEventController_ copyURLStringToPasteboard:urlString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  [browserMetadataEventController_ updateBrowser:browser faviconImage:faviconImage];
}

@end

#pragma clang diagnostic pop
