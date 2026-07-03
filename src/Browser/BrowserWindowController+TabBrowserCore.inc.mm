// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)showMainWindow {
  [self restoreSessionWindowZoom];
  [self layoutInterfaceForCurrentSplitViewSize];
  [self restoreSessionSidebarAfterInitialLayout];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                        identifier:(NSString*)identifier
                             title:(NSString*)title {
  BabelBrowserTab* tab = [[BabelBrowserTab alloc] init];
  tab.identifier = identifier ?: NSUUID.UUID.UUIDString;
  tab.urlString = urlString;
  tab.requestedURLString = urlString;
  tab.title = title ?: urlString;
  tab.hostView = [[BabelPageContainerView alloc] initWithFrame:pagesPanel_.bounds];
  __weak BabelBrowserWindowController* weakSelf = self;
  tab.hostView.canAcceptLocalDrop = ^BOOL(BabelPageContainerView* container) {
    return [weakSelf pageContainerSupportsLocalDrop:container];
  };
  tab.hostView.localDropHandler = ^(BabelPageContainerView* container) {
    [weakSelf pageContainerDidReceiveLocalDrop:container];
  };
  tab.hostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.hostView.hidden = YES;

  tab.developerToolsPanelView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsPanelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = YES;
  tab.developerToolsPanelView.wantsLayer = YES;
  tab.developerToolsPanelView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsPanelView];

  tab.developerToolsToolbarView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsToolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tab.developerToolsToolbarView.wantsLayer = YES;
  tab.developerToolsToolbarView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.toolbar.background"
                                         view:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView];

  tab.developerToolsResizeHandleView =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsResizeHandleView.resizeTarget = self;
  tab.developerToolsResizeHandleView.resizeAction = @selector(resizeDeveloperToolsFromHandle:);
  tab.developerToolsResizeHandleView.wantsLayer = YES;
  tab.developerToolsResizeHandleView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.handle.background"
                                         view:tab.developerToolsResizeHandleView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView];

  tab.developerToolsHostView = [[BabelBrowserHostView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsHostView.wantsLayer = YES;
  tab.developerToolsHostView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsHostView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView];
  [self addDeveloperToolsControlsToTab:tab];
  tab.developerToolsVisible = NO;

  tab.tabItemView = [[BabelTabItemView alloc] initWithIdentifier:tab.identifier
                                                          title:[self compactTitleForString:tab.title]];
  tab.tabItemView.faviconImage = [self faviconImageForURLString:tab.urlString];
  tab.tabItemView.target = self;
  tab.tabItemView.action = @selector(selectTabFromItem:);
  tab.tabItemView.closeTarget = self;
  tab.tabItemView.closeAction = @selector(closeTabFromItem:);
  tab.tabItemView.dragTarget = self;
  tab.tabItemView.dragAction = @selector(dragTabFromItem:);
  tab.tabItemView.dragEndTarget = self;
  tab.tabItemView.dragEndAction = @selector(finishDraggingTabFromItem:);
  return tab;
}

- (void)addDeveloperToolsControlsToTab:(BabelBrowserTab*)tab {
  NSArray<NSButton*>* buttons = @[
    [self developerToolsButtonWithImageName:@"devtools-close"
                              fallbackTitle:@"x"
                                toolTip:@"Close Developer Tools"
                                    tag:0
                                 action:@selector(closeDeveloperToolsFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-left"
                              fallbackTitle:@"L"
                                toolTip:@"Dock Developer Tools Left"
                                    tag:kDeveloperToolsDockTagLeft
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-right"
                              fallbackTitle:@"R"
                                toolTip:@"Dock Developer Tools Right"
                                    tag:kDeveloperToolsDockTagRight
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-bottom"
                              fallbackTitle:@"B"
                                toolTip:@"Dock Developer Tools Bottom"
                                    tag:kDeveloperToolsDockTagBottom
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-top"
                              fallbackTitle:@"T"
                                toolTip:@"Dock Developer Tools Top"
                                    tag:kDeveloperToolsDockTagTop
                                 action:@selector(changeDeveloperToolsDockFromButton:)]
  ];

  CGFloat x = 8.0;
  for (NSButton* button in buttons) {
    button.frame = NSMakeRect(x, 4.0, 26.0, 22.0);
    [tab.developerToolsToolbarView addSubview:button];
    x += 30.0;
  }
}

- (NSButton*)developerToolsButtonWithImageName:(NSString*)imageName
                                 fallbackTitle:(NSString*)fallbackTitle
                                       toolTip:(NSString*)toolTip
                                           tag:(NSInteger)tag
                                        action:(SEL)action {
  NSButton* button = BabelButton(fallbackTitle, self, action);
  button.bezelStyle = NSBezelStyleTexturedRounded;
  button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  button.toolTip = toolTip;
  button.tag = tag;
  ConfigureIconButton(button, imageName, fallbackTitle);
  return button;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab {
  return [self createTabForURL:urlString
                       inGroup:group
                     parentTab:parentTab
          respectingUserStrategy:YES];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab
   respectingUserStrategy:(BOOL)respectingUserStrategy {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  tab.parentTabIdentifier = parentTab.identifier;
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:respectingUserStrategy];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab {
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:YES];
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
 respectingUserStrategy:(BOOL)respectingUserStrategy {
  if (!parentTab || ![group.tabs containsObject:parentTab] ||
      (respectingUserStrategy &&
       [[self tabOpeningStrategy] isEqualToString:kTabOpeningStrategyAppend])) {
    [group.tabs addObject:tab];
    return;
  }

  NSUInteger insertionIndex = [self insertionIndexForNewChildOfTab:parentTab inGroup:group];
  [group.tabs insertObject:tab atIndex:MIN(insertionIndex, group.tabs.count)];
}

- (NSUInteger)insertionIndexForNewChildOfTab:(BabelBrowserTab*)parentTab
                                     inGroup:(BabelBrowserGroup*)group {
  NSUInteger parentIndex = [group.tabs indexOfObject:parentTab];
  if (parentIndex == NSNotFound) {
    return group.tabs.count;
  }

  if ([[self tabOpeningStrategy] isEqualToString:kTabOpeningStrategyAfterSelected]) {
    return parentIndex + 1;
  }

  NSUInteger insertionIndex = parentIndex + 1;
  for (NSUInteger index = parentIndex + 1; index < group.tabs.count; index++) {
    BabelBrowserTab* candidate = group.tabs[index];
    if (![self tab:candidate descendsFromTabIdentifier:parentTab.identifier inGroup:group]) {
      break;
    }
    insertionIndex = index + 1;
  }
  return insertionIndex;
}

- (BOOL)tab:(BabelBrowserTab*)tab
    descendsFromTabIdentifier:(NSString*)parentTabIdentifier
      inGroup:(BabelBrowserGroup*)group {
  NSString* currentParentIdentifier = tab.parentTabIdentifier;
  NSMutableSet<NSString*>* seenIdentifiers = [NSMutableSet set];
  while (currentParentIdentifier.length > 0) {
    if ([currentParentIdentifier isEqualToString:parentTabIdentifier]) {
      return YES;
    }

    if ([seenIdentifiers containsObject:currentParentIdentifier]) {
      return NO;
    }
    [seenIdentifiers addObject:currentParentIdentifier];

    BabelBrowserTab* parentTab = [self tabWithIdentifier:currentParentIdentifier inGroup:group];
    currentParentIdentifier = parentTab.parentTabIdentifier;
  }
  return NO;
}

- (NSString*)tabOpeningStrategy {
  NSString* strategy = [NSUserDefaults.standardUserDefaults stringForKey:kTabOpeningStrategyDefaultsKey];
  if ([self isSupportedTabOpeningStrategy:strategy]) {
    return strategy;
  }
  return kTabOpeningStrategyChildCluster;
}

- (BOOL)isSupportedTabOpeningStrategy:(NSString*)strategy {
  return [strategy isEqualToString:kTabOpeningStrategyAppend] ||
         [strategy isEqualToString:kTabOpeningStrategyAfterSelected] ||
         [strategy isEqualToString:kTabOpeningStrategyChildCluster];
}

- (NSString*)addressSuggestionsMode {
  NSString* mode = [NSUserDefaults.standardUserDefaults stringForKey:kAddressSuggestionsModeDefaultsKey];
  if ([self isSupportedAddressSuggestionsMode:mode]) {
    return mode;
  }
  return kAddressSuggestionsModeLocal;
}

- (BOOL)isSupportedAddressSuggestionsMode:(NSString*)mode {
  return [mode isEqualToString:kAddressSuggestionsModeLocal] ||
         [mode isEqualToString:kAddressSuggestionsModeGoogle];
}

- (NSString*)markdownTheme {
  NSString* theme = [NSUserDefaults.standardUserDefaults stringForKey:kMarkdownThemeDefaultsKey];
  if ([self isSupportedMarkdownTheme:theme]) {
    return theme;
  }
  return kMarkdownThemeGitHubLight;
}

- (BOOL)isSupportedMarkdownTheme:(NSString*)theme {
  return [theme isEqualToString:kMarkdownThemeGitHubLight] ||
         [theme isEqualToString:kMarkdownThemeGitHubDark] ||
         [theme isEqualToString:kMarkdownThemeReader] ||
         [theme isEqualToString:kMarkdownThemeCompact];
}

- (BOOL)googleSuggestEnabled {
  return [[self addressSuggestionsMode] isEqualToString:kAddressSuggestionsModeGoogle];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  if (!tab || ![tabs_ containsObject:tab] || [tab browser] || [pendingTabs_ containsObject:tab]) {
    return;
  }

  [pendingTabs_ addObject:tab];
  CefWindowInfo windowInfo;
  NSRect bounds = tab.hostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.hostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings browserSettings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(tab.urlString.UTF8String),
                                browserSettings,
                                nullptr,
                                nullptr);
}

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  NSUInteger generation = ++deferredBrowserCreationGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               kKeyboardTabSelectionBrowserCreationDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != deferredBrowserCreationGeneration_ ||
        self->selectedTab_ != tab ||
        self->isTerminating_) {
      return;
    }

    [self createBrowserForTabIfNeeded:tab];
    [self scheduleAdjacentTabPreloadForSelectedTab];
  });
}

- (void)createInitialRestoredBrowserIfNeeded {
  if (!needsInitialRestoredBrowserCreation_ || isTerminating_ || !selectedTab_) {
    return;
  }

  needsInitialRestoredBrowserCreation_ = NO;
  ++deferredBrowserCreationGeneration_;
  [self createBrowserForTabIfNeeded:selectedTab_];
  [self scheduleAdjacentTabPreloadForSelectedTab];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  if (isTerminating_ || !selectedTab_ || tabs_.count < 2) {
    return;
  }

  NSUInteger generation = ++adjacentTabPreloadGeneration_;
  BabelBrowserTab* anchorTab = selectedTab_;
  NSArray<BabelBrowserTab*>* tabsToPreload = [self adjacentTabsToPreloadAroundTab:anchorTab];
  [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                anchorTab:anchorTab
                               generation:generation
                                    index:0];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  NSUInteger selectedIndex = [tabs_ indexOfObject:tab];
  if (selectedIndex == NSNotFound || tabs_.count < 2) {
    return @[];
  }

  NSMutableArray<BabelBrowserTab*>* tabsToPreload = [NSMutableArray array];
  if (selectedIndex > 0) {
    [tabsToPreload addObject:tabs_[selectedIndex - 1]];
  }

  if (selectedIndex + 1 < tabs_.count) {
    BabelBrowserTab* nextTab = tabs_[selectedIndex + 1];
    if (![tabsToPreload containsObject:nextTab]) {
      [tabsToPreload addObject:nextTab];
    }
  }

  return tabsToPreload;
}

- (void)scheduleAdjacentTabPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabsToPreload
                                anchorTab:(BabelBrowserTab*)anchorTab
                               generation:(NSUInteger)generation
                                    index:(NSUInteger)index {
  if (index >= tabsToPreload.count) {
    return;
  }

  int64_t delay = index == 0
      ? kAdjacentTabPreloadInitialDelayNanoseconds
      : kAdjacentTabPreloadStepDelayNanoseconds;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
    if (generation != self->adjacentTabPreloadGeneration_ ||
        self->selectedTab_ != anchorTab ||
        self->isTerminating_) {
      return;
    }

    BabelBrowserTab* tabToPreload = tabsToPreload[index];
    [self createBrowserForTabIfNeeded:tabToPreload];
    [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                  anchorTab:anchorTab
                                 generation:generation
                                      index:index + 1];
  });
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  if (tab.identifier.length == 0) {
    return;
  }

  [recentlyUsedTabIdentifiers_ removeObject:tab.identifier];
  [recentlyUsedTabIdentifiers_ addObject:tab.identifier];
}

- (NSMutableSet<NSString*>*)protectedLiveBrowserTabIdentifiers {
  NSMutableSet<NSString*>* protectedIdentifiers = [NSMutableSet set];
  if (selectedTab_.identifier.length > 0) {
    [protectedIdentifiers addObject:selectedTab_.identifier];
  }

  for (BabelBrowserTab* tab in [self adjacentTabsToPreloadAroundTab:selectedTab_]) {
    if (tab.identifier.length > 0) {
      [protectedIdentifiers addObject:tab.identifier];
    }
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab.developerToolsVisible && tab.identifier.length > 0) {
        [protectedIdentifiers addObject:tab.identifier];
      }
    }
  }

  return protectedIdentifiers;
}

- (NSArray<BabelBrowserTab*>*)livePageBrowserTabsExcludingEvictions {
  NSMutableArray<BabelBrowserTab*>* liveTabs = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] &&
          ![evictingBrowserTabIdentifiers_ containsObject:tab.identifier ?: @""]) {
        [liveTabs addObject:tab];
      }
    }
  }
  return liveTabs;
}

- (BabelBrowserTab*)leastRecentlyUsedEvictableTabFromTabs:(NSArray<BabelBrowserTab*>*)liveTabs
                                     protectedIdentifiers:(NSSet<NSString*>*)protectedIdentifiers {
  for (BabelBrowserTab* tab in liveTabs) {
    if (![recentlyUsedTabIdentifiers_ containsObject:tab.identifier ?: @""] &&
        ![protectedIdentifiers containsObject:tab.identifier ?: @""]) {
      return tab;
    }
  }

  for (NSString* tabIdentifier in recentlyUsedTabIdentifiers_) {
    if ([protectedIdentifiers containsObject:tabIdentifier]) {
      continue;
    }

    for (BabelBrowserTab* tab in liveTabs) {
      if ([tab.identifier isEqualToString:tabIdentifier]) {
        return tab;
      }
    }
  }

  return nil;
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  CefRefPtr<CefBrowser> browser = [tab browser];
  if (!browser || tab.identifier.length == 0) {
    return;
  }

  [evictingBrowserTabIdentifiers_ addObject:tab.identifier];
  browser->GetHost()->CloseDevTools();
  browser->GetHost()->CloseBrowser(true);
}

- (void)enforceLivePageBrowserLimit {
  if (isTerminating_) {
    return;
  }

  NSMutableSet<NSString*>* protectedIdentifiers = [self protectedLiveBrowserTabIdentifiers];
  while (YES) {
    NSArray<BabelBrowserTab*>* liveTabs = [self livePageBrowserTabsExcludingEvictions];
    if (liveTabs.count <= kMaximumLivePageBrowsers) {
      return;
    }

    BabelBrowserTab* tabToEvict =
        [self leastRecentlyUsedEvictableTabFromTabs:liveTabs
                               protectedIdentifiers:protectedIdentifiers];
    if (!tabToEvict) {
      return;
    }

    [self closeBrowserForTabKeepingNativeTab:tabToEvict];
  }
}
