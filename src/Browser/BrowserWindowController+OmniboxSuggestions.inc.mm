// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)updateOmniboxSuggestionsForQuery:(NSString*)query {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [omniboxSuggestions_ removeAllObjects];
  selectedOmniboxSuggestionIndex_ = -1;
  ++googleSuggestGeneration_;

  if (trimmedQuery.length == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  NSMutableArray<NSDictionary*>* openTabRows = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }

      [openTabRows addObject:@{
        BabelOmniboxLocalRowTitleKey : tab.title ?: @"",
        BabelOmniboxLocalRowURLStringKey : tab.urlString ?: @"",
        BabelOmniboxLocalRowRequestedURLStringKey : tab.requestedURLString ?: @"",
        BabelOmniboxLocalRowGroupNameKey : group.name ?: kDefaultGroupName,
        BabelOmniboxLocalRowTabIdentifierKey : tab.identifier ?: @"",
      }];
    }
  }

  NSMutableArray<NSDictionary*>* closedTabRows = [NSMutableArray array];
  NSArray<BabelClosedTab*>* closedTabs = [recentlyClosedTabStore_ allClosedTabs];
  for (NSInteger index = (NSInteger)closedTabs.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs[(NSUInteger)index];
    [closedTabRows addObject:@{
      BabelOmniboxLocalRowTitleKey : closedTab.title ?: @"",
      BabelOmniboxLocalRowURLStringKey : closedTab.urlString ?: @"",
      BabelOmniboxLocalRowRequestedURLStringKey : closedTab.requestedURLString ?: @"",
      BabelOmniboxLocalRowGroupNameKey : closedTab.groupName ?: kDefaultGroupName,
      BabelOmniboxLocalRowTabIdentifierKey : @"",
    }];
  }

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
    [omniboxSuggestions_ addObject:suggestion];
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
  for (NSDictionary* suggestion in omniboxSuggestions_) {
    NSString* action = suggestion[@"action"] ?: @"";
    NSString* key = [NSString stringWithFormat:@"%@|%@", action, suggestion[@"url"] ?: @""];
    [seenSuggestionKeys addObject:key];
  }

  for (NSString* suggestion in suggestions) {
    if (omniboxSuggestions_.count >= kOmniboxSuggestionMaximumCount) {
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
  [omniboxSuggestions_ addObject:suggestion];
}

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title urlString:(NSString*)urlString {
  NSImage* faviconImage = [faviconStore_ faviconImageForURLString:urlString];
  if (faviconImage) {
    return faviconImage;
  }

  NSString* normalizedTitle = [self normalizedFaviconLookupString:title];
  if (normalizedTitle.length == 0) {
    return nil;
  }

  return [faviconStore_ faviconImageMatchingNormalizedTitle:normalizedTitle];
}

- (NSString*)normalizedFaviconLookupString:(NSString*)string {
  NSString* lowercaseString = string.lowercaseString ?: @"";
  NSCharacterSet* charactersToKeep =
      [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789 "];
  NSMutableString* normalizedString = [NSMutableString string];
  BOOL previousWasSpace = YES;
  for (NSUInteger index = 0; index < lowercaseString.length; index++) {
    unichar character = [lowercaseString characterAtIndex:index];
    if (![charactersToKeep characterIsMember:character]) {
      continue;
    }

    if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character]) {
      if (!previousWasSpace) {
        [normalizedString appendString:@" "];
      }
      previousWasSpace = YES;
      continue;
    }

    [normalizedString appendFormat:@"%C", character];
    previousWasSpace = NO;
  }

  return [normalizedString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (void)showOmniboxSuggestions {
  if (omniboxSuggestions_.count == 0) {
    [self hideOmniboxSuggestions];
    return;
  }

  [omniboxSuggestionsPanel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  omniboxSuggestionsPanel_.hidden = NO;
  [self layoutInterfaceForCurrentSplitViewSize];

  CGFloat panelWidth = omniboxSuggestionsPanel_.bounds.size.width;
  CGFloat panelHeight = omniboxSuggestionsPanel_.bounds.size.height;
  for (NSUInteger index = 0; index < omniboxSuggestions_.count; index++) {
    NSDictionary* suggestion = omniboxSuggestions_[index];
    BabelOmniboxSuggestionRowView* row =
        [[BabelOmniboxSuggestionRowView alloc] initWithFrame:
            NSMakeRect(0,
                       panelHeight - (kOmniboxSuggestionRowHeight * (index + 1)),
                       panelWidth,
                       kOmniboxSuggestionRowHeight)];
    row.target = self;
    row.action = @selector(selectOmniboxSuggestionFromRow:);
    row.tag = (NSInteger)index;
    row.suggestionHighlighted = (NSInteger)index == selectedOmniboxSuggestionIndex_;
    NSImage* iconImage = [suggestion[@"icon"] isKindOfClass:NSImage.class] ? suggestion[@"icon"] : nil;
    [row configureWithTitle:suggestion[@"title"]
                   subtitle:[NSString stringWithFormat:@"%@ - %@",
                                                       suggestion[@"group"],
                                                       suggestion[@"url"]]
                  iconImage:iconImage];
    [omniboxSuggestionsPanel_ addSubview:row];
  }
}

- (void)hideOmniboxSuggestions {
  [omniboxSuggestions_ removeAllObjects];
  selectedOmniboxSuggestionIndex_ = -1;
  omniboxSuggestionsPanel_.hidden = YES;
  [omniboxSuggestionsPanel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  [self layoutInterfaceForCurrentSplitViewSize];
}

- (void)selectNextOmniboxSuggestion {
  if (omniboxSuggestions_.count == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if (omniboxSuggestions_.count == 0) {
    return;
  }

  selectedOmniboxSuggestionIndex_ =
      (selectedOmniboxSuggestionIndex_ + 1) % (NSInteger)omniboxSuggestions_.count;
  [self refreshOmniboxSuggestionHighlight];
}

- (void)selectPreviousOmniboxSuggestion {
  if (omniboxSuggestions_.count == 0) {
    [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
  }

  if (omniboxSuggestions_.count == 0) {
    return;
  }

  selectedOmniboxSuggestionIndex_ = selectedOmniboxSuggestionIndex_ <= 0
      ? (NSInteger)omniboxSuggestions_.count - 1
      : selectedOmniboxSuggestionIndex_ - 1;
  [self refreshOmniboxSuggestionHighlight];
}

- (void)refreshOmniboxSuggestionHighlight {
  for (NSView* view in omniboxSuggestionsPanel_.subviews) {
    if (![view isKindOfClass:BabelOmniboxSuggestionRowView.class]) {
      continue;
    }

    BabelOmniboxSuggestionRowView* row = (BabelOmniboxSuggestionRowView*)view;
    row.suggestionHighlighted = row.tag == selectedOmniboxSuggestionIndex_;
  }
}

- (void)selectOmniboxSuggestionFromRow:(BabelOmniboxSuggestionRowView*)row {
  selectedOmniboxSuggestionIndex_ = row.tag;
  [self acceptSelectedOmniboxSuggestion];
}

- (BOOL)acceptSelectedOmniboxSuggestion {
  if (selectedOmniboxSuggestionIndex_ < 0 ||
      selectedOmniboxSuggestionIndex_ >= (NSInteger)omniboxSuggestions_.count) {
    return NO;
  }

  NSDictionary* suggestion = omniboxSuggestions_[(NSUInteger)selectedOmniboxSuggestionIndex_];
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
  NSString* trimmedAddress = [address stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedAddress.length == 0) {
    return BabelChromeConfiguration.defaultURLString;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:trimmedAddress];
  if (components.scheme.length > 0) {
    return trimmedAddress;
  }

  if ([trimmedAddress containsString:@"."] || [trimmedAddress hasPrefix:@"localhost"]) {
    return [@"https://" stringByAppendingString:trimmedAddress];
  }

  NSString* encodedQuery =
      [trimmedAddress stringByAddingPercentEncodingWithAllowedCharacters:
                          NSCharacterSet.URLQueryAllowedCharacterSet];
  return [@"https://www.google.com/search?q=" stringByAppendingString:(encodedQuery ?: @"")];
}

- (NSString*)compactTitleForString:(NSString*)value {
  if (value.length <= 28) {
    return value;
  }
  return [[value substringToIndex:25] stringByAppendingString:@"..."];
}
