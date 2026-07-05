#import "Browser/BabelBrowserWindowAddressAndSuggestionsActions.h"

#import "Browser/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowAddressAndSuggestionsActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)selectTabWithOffset:(NSInteger)offset {
  if (!owner_->selectedTab_ || owner_->tabs_.count < 2) {
    return;
  }

  NSUInteger currentIndex = [owner_->tabs_ indexOfObject:owner_->selectedTab_];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSInteger tabCount = (NSInteger)owner_->tabs_.count;
  NSInteger nextIndex = ((NSInteger)currentIndex + offset + tabCount) % tabCount;
  [owner_ selectTab:owner_->tabs_[(NSUInteger)nextIndex] deferringBrowserCreation:YES];
}

- (void)selectTab:(BabelBrowserTab*)tab {
  [owner_ selectTab:tab deferringBrowserCreation:NO];
}

- (void)selectTab:(BabelBrowserTab*)tab deferringBrowserCreation:(BOOL)deferringBrowserCreation {
  owner_->selectedTab_ = tab;
  [owner_->linkStatusBarController_ hideStatusBar:owner_->linkStatusBarView_];
  owner_->selectedGroup_.selectedTabIdentifier = tab.identifier;
  [owner_ touchRecentlyUsedTab:tab];
  for (BabelBrowserTab* currentTab in owner_->tabs_) {
    currentTab.hostView.hidden = currentTab != tab;
    currentTab.developerToolsPanelView.hidden = currentTab != tab ||
                                                !currentTab.developerToolsVisible;
    currentTab.tabItemView.selected = currentTab == tab;
    [owner_ layoutBrowserViewsForTab:currentTab];
  }
  [owner_ updateAddressBarForTab:tab];
  [owner_ updateWindowTitleForSelectedTab];
  [owner_ layoutTabItemsSelectingLastTab:NO];
  if (owner_->isRestoringSession_) {
    [owner_->browserPageLifecycleController_ markNeedsInitialRestoredBrowserCreation];
    [owner_ saveGroupsState];
    return;
  }

  if (!owner_->isTerminating_) {
    if (deferringBrowserCreation) {
      [owner_ scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
    } else {
      [owner_->browserPageLifecycleController_ cancelKeyboardBrowserCreation];
      [owner_ createBrowserForTabIfNeeded:tab];
      [owner_ scheduleAdjacentTabPreloadForSelectedTab];
    }
  }
  [owner_ saveGroupsState];
}

- (void)updateWindowTitleForSelectedTab {
  NSString* pageTitle = owner_->selectedTab_.title.length > 0 ? owner_->selectedTab_.title : owner_->selectedTab_.urlString;
  owner_.window.title =
      [owner_->browserPresentationFormatter_ windowTitleWithApplicationName:BabelChromeConfiguration.applicationName
                                                          pageTitle:pageTitle];
}

- (void)layoutAddressTextFieldContent {
  BabelAddressFieldLayout* layout =
      [owner_->addressFieldLayoutCalculator_ layoutForBounds:owner_->addressTextFieldContainer_.bounds
                                            hasBadge:!owner_->viewerBadgeLabel_.hidden];
  owner_->viewerBadgeLabel_.frame = layout.badgeFrame;
  owner_->urlTextField_.frame = layout.textFieldFrame;
}

- (void)setAddressBadge:(NSDictionary*)badge {
  NSString* normalizedBadgeString = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  BOOL hasBadge = normalizedBadgeString.length > 0;
  NSString* textColorString = [badge[@"textColor"] isKindOfClass:NSString.class] ? badge[@"textColor"] : @"#ffffff";
  NSString* backgroundColorString = [badge[@"backgroundColor"] isKindOfClass:NSString.class] ? badge[@"backgroundColor"] : @"#000000";
  NSString* settingsRoute = [badge[@"settingsRoute"] isKindOfClass:NSString.class] ? badge[@"settingsRoute"] : @"";
  owner_->viewerBadgeLabel_.hidden = !hasBadge;
  owner_->viewerBadgeLabel_.settingsRoute = hasBadge ? settingsRoute : @"";
  [owner_->viewerBadgeLabel_ configureWithText:normalizedBadgeString
                             textColor:[owner_->browserPresentationFormatter_ colorFromHexString:textColorString
                                                                            fallbackColor:NSColor.whiteColor]
                       backgroundColor:[owner_->browserPresentationFormatter_ colorFromHexString:backgroundColorString
                                                                            fallbackColor:NSColor.clearColor]];
  [owner_ layoutAddressTextFieldContent];
}

- (void)openAddressBadgeSettingsFromMenu:(NSMenuItem*)sender {
  NSString* settingsRoute = [sender.representedObject isKindOfClass:NSString.class]
      ? sender.representedObject
      : @"";
  if (settingsRoute.length == 0) {
    return;
  }

  [owner_ handleInternalNavigationURLString:settingsRoute];
}

- (void)updateAddressBarForTab:(BabelBrowserTab*)tab {
  owner_->addressLabel_.stringValue = @"URL";
  [owner_ setAddressBadge:[owner_->addressBarDisplayResolver_ addressBadgeForTab:tab]];
  owner_->urlTextField_.stringValue = [owner_->addressBarDisplayResolver_ displayURLStringForTab:tab];
}

- (void)clearAddressBar {
  owner_->addressLabel_.stringValue = @"URL";
  [owner_ setAddressBadge:nil];
  owner_->urlTextField_.stringValue = @"";
}

- (void)navigateFromAddressField:(id)sender {
  if (!owner_->selectedTab_) {
    return;
  }

  [owner_ hideOmniboxSuggestions];
  BabelAddressNavigationRequest* request =
      [owner_->addressNavigationRequestResolver_ navigationRequestForAddressString:owner_->urlTextField_.stringValue
                                                               selectedTab:owner_->selectedTab_];
  if (request.shouldRestoreAddressBar) {
    [owner_ updateAddressBarForTab:owner_->selectedTab_];
    return;
  }

  owner_->selectedTab_.urlString = request.navigationURLString;
  owner_->selectedTab_.requestedURLString = request.requestedURLString;
  [owner_ updateAddressBarForTab:owner_->selectedTab_];

  if ([owner_->selectedTab_ browser]) {
    [owner_->selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(request.navigationURLString.UTF8String));
    [owner_ saveGroupsState];
    return;
  }

  [owner_ selectTab:owner_->selectedTab_];
  [owner_ saveGroupsState];
}

- (void)closeSelectedTab {
  if (!owner_->selectedTab_) {
    return;
  }

  [owner_ closeTabFromItem:owner_->selectedTab_.tabItemView];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (notification.object == owner_->urlTextField_) {
    [owner_ hideOmniboxSuggestions];
  }

  NSNumber* movement = notification.userInfo[@"NSTextMovement"];
  if (movement.integerValue == NSReturnTextMovement) {
    [owner_ navigateFromAddressField:notification.object];
  }
}

- (void)controlTextDidChange:(NSNotification*)notification {
  if (notification.object != owner_->urlTextField_) {
    return;
  }

  [owner_ updateOmniboxSuggestionsForQuery:owner_->urlTextField_.stringValue];
}

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
doCommandBySelector:(SEL)commandSelector {
  if (control != owner_->urlTextField_) {
    return NO;
  }

  if (commandSelector == @selector(moveDown:)) {
    [owner_ selectNextOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(moveUp:)) {
    [owner_ selectPreviousOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(insertNewline:)) {
    if ([owner_ acceptSelectedOmniboxSuggestion]) {
      return YES;
    }
    [owner_ navigateFromAddressField:control];
    return YES;
  }

  if (commandSelector == @selector(cancelOperation:)) {
    [owner_ hideOmniboxSuggestions];
    owner_->urlTextField_.stringValue = owner_->selectedTab_
        ? [owner_->addressBarDisplayResolver_ displayURLStringForTab:owner_->selectedTab_]
        : @"";
    return YES;
  }

  return NO;
}
- (void)updateOmniboxSuggestionsForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [owner_->omniboxSuggestionsController_ removeAllSuggestions];
  [owner_->googleSuggestionScheduler_ cancelPendingSuggestions];

  if (trimmedQuery.length == 0) {
    [owner_ hideOmniboxSuggestions];
    return;
  }

  NSArray<NSDictionary*>* openTabRows =
      [owner_->omniboxSuggestionContextBuilder_ openTabRowsForGroups:owner_->groups_
                                            defaultGroupName:kDefaultGroupName
                                        internalTabPredicate:^BOOL(BabelBrowserTab* tab) {
    return [owner_ isInternalPageTab:tab];
  }];
  NSArray<NSDictionary*>* closedTabRows =
      [owner_->omniboxSuggestionContextBuilder_ closedTabRowsForClosedTabs:[owner_->recentlyClosedTabStore_ allClosedTabs]
                                                  defaultGroupName:kDefaultGroupName];

  NSArray<NSDictionary*>* localSuggestions =
      [owner_->omniboxLocalSuggestionBuilder_ localSuggestionsForQuery:trimmedQuery
                                                   openTabRows:openTabRows
                                                 closedTabRows:closedTabRows
                                                  maximumCount:kOmniboxSuggestionMaximumCount];
  for (NSDictionary* localSuggestion in localSuggestions) {
    NSMutableDictionary* suggestion = [localSuggestion mutableCopy];
    NSString* title = [suggestion[@"title"] isKindOfClass:NSString.class] ? suggestion[@"title"] : @"";
    NSString* urlString = [suggestion[@"url"] isKindOfClass:NSString.class] ? suggestion[@"url"] : @"";
    NSImage* faviconImage = [owner_ faviconImageForSuggestionTitle:title urlString:urlString];
    if (faviconImage) {
      suggestion[@"icon"] = faviconImage;
    }
    [owner_->omniboxSuggestionsController_ addSuggestion:suggestion];
  }

  [owner_ showOmniboxSuggestions];
  [owner_ scheduleGoogleSuggestionsForQuery:trimmedQuery];
}

- (void)scheduleGoogleSuggestionsForQuery:(NSString*)query {
  __weak BabelBrowserWindowController* weakSelf = owner_;
  [owner_->googleSuggestionScheduler_ scheduleSuggestionsForQuery:query
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
  if (![query isEqualToString:owner_->urlTextField_.stringValue] ||
      ![owner_ googleSuggestEnabled]) {
    return;
  }

  NSMutableSet<NSString*>* seenSuggestionKeys = [NSMutableSet set];
  for (NSDictionary* suggestion in [owner_->omniboxSuggestionsController_ suggestions]) {
    NSString* action = suggestion[@"action"] ?: @"";
    NSString* key = [NSString stringWithFormat:@"%@|%@", action, suggestion[@"url"] ?: @""];
    [seenSuggestionKeys addObject:key];
  }

  for (NSString* suggestion in suggestions) {
    if ([owner_->omniboxSuggestionsController_ suggestionCount] >= kOmniboxSuggestionMaximumCount) {
      break;
    }

    [owner_ addOmniboxSuggestionWithTitle:suggestion
                              urlString:[owner_->googleSuggestClient_ googleSearchURLStringForQuery:suggestion]
                              groupName:@"Google Search"
                          tabIdentifier:nil
                                  action:@"google-search"
                                seenKeys:seenSuggestionKeys];
  }

  [owner_ showOmniboxSuggestions];
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
  NSImage* faviconImage = [owner_ faviconImageForSuggestionTitle:title urlString:urlString];
  if (faviconImage) {
    suggestion[@"icon"] = faviconImage;
  }
  [owner_->omniboxSuggestionsController_ addSuggestion:suggestion];
}

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title urlString:(NSString*)urlString {
  return [owner_->omniboxSuggestionContextBuilder_ faviconImageForSuggestionTitle:title
                                                                urlString:urlString
                                                             faviconStore:owner_->faviconStore_];
}

- (void)showOmniboxSuggestions {
  if ([owner_->omniboxSuggestionsController_ suggestionCount] == 0) {
    [owner_ hideOmniboxSuggestions];
    return;
  }

  [owner_ layoutInterfaceForCurrentSplitViewSize];
  [owner_->omniboxSuggestionsController_ showWithTarget:self
                                         action:@selector(selectOmniboxSuggestionFromRow:)
                                      rowHeight:kOmniboxSuggestionRowHeight];
}

- (void)hideOmniboxSuggestions {
  [owner_->omniboxSuggestionsController_ hide];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
}

- (void)selectNextOmniboxSuggestion {
  if ([owner_->omniboxSuggestionsController_ suggestionCount] == 0) {
    [owner_ updateOmniboxSuggestionsForQuery:owner_->urlTextField_.stringValue];
  }

  if ([owner_->omniboxSuggestionsController_ suggestionCount] == 0) {
    return;
  }

  [owner_->omniboxSuggestionsController_ selectNextSuggestion];
}

- (void)selectPreviousOmniboxSuggestion {
  if ([owner_->omniboxSuggestionsController_ suggestionCount] == 0) {
    [owner_ updateOmniboxSuggestionsForQuery:owner_->urlTextField_.stringValue];
  }

  if ([owner_->omniboxSuggestionsController_ suggestionCount] == 0) {
    return;
  }

  [owner_->omniboxSuggestionsController_ selectPreviousSuggestion];
}

- (void)selectOmniboxSuggestionFromRow:(BabelOmniboxSuggestionRowView*)row {
  [owner_->omniboxSuggestionsController_ selectSuggestionAtIndex:row.tag];
  [owner_ acceptSelectedOmniboxSuggestion];
}

- (BOOL)acceptSelectedOmniboxSuggestion {
  NSDictionary* suggestion = [owner_->omniboxSuggestionsController_ selectedSuggestion];
  if (!suggestion) {
    return NO;
  }

  NSString* action = suggestion[@"action"];
  if ([action isEqualToString:@"focus-tab"]) {
    NSString* tabIdentifier = suggestion[@"tabId"];
    for (BabelBrowserGroup* group in owner_->groups_) {
      BabelBrowserTab* tab = [owner_ tabWithIdentifier:tabIdentifier inGroup:group];
      if (!tab) {
        continue;
      }

      [owner_ hideOmniboxSuggestions];
      [owner_ selectGroup:group];
      [owner_ selectTab:tab];
      [owner_ showMainWindow];
      return YES;
    }
  }

  NSString* urlString = suggestion[@"url"];
  if (urlString.length == 0) {
    return NO;
  }

  owner_->addressLabel_.stringValue = @"URL";
  [owner_ setAddressBadge:nil];
  owner_->urlTextField_.stringValue = urlString;
  [owner_ hideOmniboxSuggestions];
  [owner_ navigateFromAddressField:owner_->urlTextField_];
  return YES;
}

- (NSString*)compactTitleForString:(NSString*)value {
  return [owner_->browserPresentationFormatter_ compactTitleForString:value];
}
- (BOOL)shouldPropagateBrowserClose {
  return owner_->isTerminating_;
}

- (void)refreshBabelChromeFileTypeCapabilities {
  if (owner_->browserClient_) {
    owner_->browserClient_->RefreshFileTypesHeaderValue();
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  [owner_->browserMetadataEventController_ updateBrowser:browser title:title];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  [owner_->browserMetadataEventController_ updateBrowser:browser urlString:urlString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  [owner_->browserMetadataEventController_ updateBrowser:browser statusText:statusText];
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  [owner_->browserMetadataEventController_ copyURLStringToPasteboard:urlString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  [owner_->browserMetadataEventController_ updateBrowser:browser faviconImage:faviconImage];
}


@end
